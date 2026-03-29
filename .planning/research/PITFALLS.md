# Pitfalls Research

**Domain:** iOS/SwiftUI — Firmware update process hardening for ValetudiOS v2.0.0
**Researched:** 2026-03-29
**Confidence:** HIGH (based on direct codebase analysis + verified iOS concurrency docs + embedded-OTA post-mortems)

---

## Critical Pitfalls

### Pitfall 1: startUpdate() has no re-entrancy guard — double-tap triggers two concurrent updates

**What goes wrong:**
`startUpdate()` in `RobotDetailViewModel` sets `updateInProgress = true` after reading `updaterState`, but both reads happen before any await suspension point. If the user taps "Update" twice before the first call reaches its first `await`, both calls see `updateInProgress == false`, both proceed, and the robot receives two `downloadUpdate()` requests in rapid succession. Valetudo's updater is not designed for concurrent callers and the resulting state is undefined — typically the download stalls or the apply step fires twice.

**Why it happens:**
`@MainActor` guarantees serial execution between suspension points, but does not prevent two calls from reading the same state before either has mutated it. The current code pattern is:

```swift
func startUpdate() async {
    // No guard here
    let needsDownload = updaterState?.isUpdateAvailable == true  // read
    updateInProgress = true  // write — too late, second call already past this
    ...
    try await api.downloadUpdate()  // suspension point
```

Both calls read `needsDownload` before either sets `updateInProgress = true`. The `@MainActor` re-entrancy window between calls is the initial `Task { await startUpdate() }` dispatch — both tasks are enqueued, both start, both read state, only then does the first set the flag.

**How to avoid:**
Add the guard as the very first statement, before any reads:

```swift
func startUpdate() async {
    guard !updateInProgress else { return }
    updateInProgress = true
    // ... rest of function
```

This is safe because `updateInProgress` is read and written on `@MainActor` — no suspension point between guard and assignment.

**Warning signs:**
- "Update" button not disabled while `updateInProgress == true`.
- `startUpdate()` called from a `Task { }` wrapper in a button's action closure rather than from a `.task` modifier with cancellation.
- No `isEnabled` binding on the update button.

**Phase to address:**
Phase 1 (State Machine foundation) — guard must exist before any other hardening is layered on top.

---

### Pitfall 2: UpdaterState model has no error case — polling loop silently exits on error

**What goes wrong:**
The download polling loop in `startUpdate()` breaks out of the loop when it sees `!state.isDownloading && !state.isReadyToApply`. This correctly detects "download finished, apply pending" but also silently covers every error case: network timeout, Valetudo error state, disk full, checksum failure. The user sees the spinner stop and `updateInProgress` drop to `false` with no explanation. The update has failed but the UI gives no indication.

**Why it happens:**
`UpdaterState` maps the Valetudo API's `__class` string to three boolean properties (`isUpdateAvailable`, `isDownloading`, `isReadyToApply`). The Valetudo updater has additional states (`ValetudoUpdaterErrorState`, `ValetudoUpdaterNoUpdateAvailableState`) that fall through all three booleans as `false`. Any unknown or error class reaches the break condition silently.

**How to avoid:**
- Add an `isError: Bool` computed property to `UpdaterState`:
  ```swift
  var isError: Bool { stateType.contains("Error") || stateType == "unknown" }
  ```
- Add an `errorMessage: String?` property that reads any message field from the raw state.
- In the polling loop, check for error explicitly and surface it to the user before returning.
- Add an `.error(String)` case to a new `UpdatePhase` enum used by the ViewModel rather than relying on raw `UpdaterState` flags.

**Warning signs:**
- `updaterState` is `nil` or shows idle after the user taps Update but nothing happened.
- The polling loop has `break` with no associated error path.
- `updateInProgress = false` in error branch has no accompanying user-visible state.

**Phase to address:**
Phase 1 (State Machine) — the error state must be modeled before the polling loop is relied upon for any phase.

---

### Pitfall 3: checkForUpdates() fires on every view appearance — interferes with active download

**What goes wrong:**
`RobotSettingsSections` uses `.task { await loadInfo() }` which calls `checkForUpdate()` on every view appearance. If the user navigates away and back during a download (which is possible — there is no navigation lock during download phase), a fresh `getUpdaterState()` call fires alongside the polling loop in `RobotDetailViewModel`. Two separate objects now hold their own snapshot of `UpdaterState`. When the view-level state differs from the ViewModel state, the UI can show stale "update available" even while download is completing.

**Why it happens:**
Update state lives in two places simultaneously: `RobotDetailViewModel.updaterState` (drives the download logic) and a local `@State var updaterState` in `RobotSettingsSections` (drives the info section UI). Neither object knows about the other. The `.task` modifier fires on every appearance because there is no condition guard checking whether an update is already in progress.

**How to avoid:**
- Consolidate update state to a single source of truth: `RobotDetailViewModel` (or a dedicated `UpdateViewModel`).
- The settings section should read from the ViewModel's published state, not maintain its own.
- In `.task`, guard against triggering a check when `updateInProgress == true`:
  ```swift
  .task {
      guard !viewModel.updateInProgress else { return }
      await loadInfo()
  }
  ```
- Prefer `.task(id: someStableId)` over plain `.task` to control re-execution.

**Warning signs:**
- Two separate `@State var updaterState: UpdaterState?` declarations in different files.
- `getUpdaterState()` called from both a ViewModel method and a View-local function.
- `.task { await loadInfo() }` with no guard on active update state.

**Phase to address:**
Phase 2 (State consolidation) — after the state machine is defined in Phase 1, this is the first integration pitfall when wiring the new ViewModel to both views.

---

### Pitfall 4: Phone sleeps during apply phase — robot receives corrupted or incomplete apply command

**What goes wrong:**
The apply phase (`api.applyUpdate()`) is a fire-and-forget HTTP request. iOS will not suspend the app mid-request if the app is active. However, the subsequent "robot offline while rebooting" wait is a polling loop with `Task.sleep` calls lasting up to 5 minutes. During this time the phone's idle timer fires (default: 2 minutes), the screen locks, and on devices with aggressive power management the app may be throttled or the TCP connection to the robot closed by NAT/firewall timeout. The robot may reboot successfully but the app never gets the confirmation ping.

**Why it happens:**
There is no `UIApplication.shared.isIdleTimerDisabled = true` anywhere in the codebase. Long-running operations in the app assume the user is watching the screen, but the apply phase is intentionally a "set it and forget it" wait. The polling loop can run for minutes — far beyond the idle timer threshold.

**How to avoid:**
- Disable the idle timer at the start of the apply phase and re-enable it on completion or error:
  ```swift
  UIApplication.shared.isIdleTimerDisabled = true
  defer { UIApplication.shared.isIdleTimerDisabled = false }
  try await api.applyUpdate()
  // ... reboot polling loop
  ```
- Call this on `@MainActor` (required for UIKit access).
- Use `defer` to guarantee re-enabling even on `throw`.
- The download phase does not require this — the polling loop is observational, not transactional.

**Warning signs:**
- No `isIdleTimerDisabled` anywhere in the codebase (confirmed: none exists).
- Apply phase polling loop longer than 120 seconds with no screen-on guarantee.
- Reports from users that "update started but robot never came back" — usually this failure mode.

**Phase to address:**
Phase 3 (Apply phase hardening) — must be added before the apply phase lock UI is built.

---

### Pitfall 5: False-positive "update failed" during robot reboot window

**What goes wrong:**
After `applyUpdate()` is called, the robot reboots. During the reboot (typically 30–90 seconds for Valetudo on Roborock), all HTTP requests to the robot fail with connection refused or timeout. The current code calls `updateInProgress = false` in the `catch` block — meaning a connection-refused error during the normal reboot window is indistinguishable from a genuine apply failure. The user sees "Update failed" when the update actually succeeded.

**Why it happens:**
The apply sequence is: send apply → robot starts rebooting → robot is unreachable for 30–90 seconds → robot comes back online with new firmware. The app has no "expected downtime window" concept. Any error after `applyUpdate()` is treated as a failure.

**How to avoid:**
- After `applyUpdate()` succeeds (HTTP 200), transition to a distinct `ApplyPending` / `Rebooting` state, not back to idle.
- During the reboot window, suppress network errors: catch `URLError.cannotConnectToHost`, `URLError.timedOut`, `URLError.networkConnectionLost` as expected events, not failures.
- Only declare failure if the robot is still unreachable after a reasonable maximum window (e.g., 3 minutes post-apply).
- After the robot comes back, compare `currentVersion` from `getUpdaterState()` to the pre-update version to confirm success.

**Warning signs:**
- `catch` block after `applyUpdate()` sets `updateInProgress = false` unconditionally.
- No state distinction between "applying (robot offline expected)" and "error".
- No post-reboot version verification.

**Phase to address:**
Phase 3 (Apply phase hardening) — the reboot window state must be modeled before the apply path is tested end-to-end.

---

### Pitfall 6: User can navigate away during apply phase — back-navigation kills the polling loop

**What goes wrong:**
The apply phase polling loop is an `async` function running inside a `Task` that is owned by a ViewModel. If the ViewModel is a `@StateObject` owned by a view, and the user navigates away from that view, the view is destroyed, the `@StateObject` is deallocated, and any in-flight `Task` is cancelled. The robot is now applying its update but the app has no visibility into completion.

**Why it happens:**
SwiftUI's `@StateObject` lifetime is tied to the owning view's lifetime. Navigation pop destroys the view and deallocates the ViewModel. `Task.cancel()` is called automatically on the stored task when the actor is deallocated. The robot continues its reboot independently — but the app will never show success.

**How to avoid:**
- The apply phase polling loop must outlive the view. Move it to a long-lived object: `RobotManager` (already a singleton-like object) or a dedicated `UpdateCoordinator` that lives in the app-level environment.
- Show a non-dismissible modal or full-screen cover during the apply phase that prevents navigation away.
- If the user force-quits and reopens the app, `getUpdaterState()` on next launch can detect the `ValetudoUpdaterApplyPendingState` and resume the completion check.

**Warning signs:**
- Update polling loop `Task` stored on a `@StateObject` ViewModel (not on `RobotManager`).
- No `interactiveDismissDisabled(true)` on the apply-phase modal.
- No recovery path for "was updating when app was killed" on next launch.

**Phase to address:**
Phase 3 (Apply phase hardening) and Phase 4 (Navigation lock UI).

---

### Pitfall 7: Duplicate update logic creates state desync between two code paths

**What goes wrong:**
Update checking logic exists in two places:
1. `RobotDetailViewModel.checkForUpdate()` — calls `api.checkForUpdates()` + `api.getUpdaterState()` + GitHub API
2. `RobotSettingsSections.checkForUpdate()` — also calls `api.getUpdaterState()` + GitHub API

Both paths write to separate state variables. The ViewModel drives the download button and `updateInProgress`. The settings section drives the info banner. When the user taps "Download" from the ViewModel path but the settings section fires `loadInfo()` concurrently (view re-appeared), the settings section may overwrite `updaterState` with a stale snapshot from before the download started, causing the button to re-enable mid-download.

**Why it happens:**
Feature was likely added first in the ViewModel for the detail view, then the settings section needed its own version info. Rather than reading from the ViewModel's published state, a second self-contained implementation was written.

**How to avoid:**
- Single source of truth: one `UpdateViewModel` (or consolidated in `RobotDetailViewModel`) with published properties.
- Settings section reads from the ViewModel via `@ObservedObject` or environment, never calls `getUpdaterState()` independently.
- The GitHub API call (one external request) fires once per robot session, result cached in the ViewModel.

**Warning signs:**
- `checkForUpdate()` function defined in two separate files.
- `@State var updaterState: UpdaterState?` in a View (not a ViewModel).
- `URLSession.shared.data(from: githubUrl)` called in multiple places.

**Phase to address:**
Phase 2 (Consolidation) — eliminate the duplicate before adding any new logic to either path.

---

## Moderate Pitfalls

### Pitfall 8: App backgrounding suspends the polling Task mid-loop

**What goes wrong:**
When the app moves to background (`scenePhase == .background`), iOS suspends active `Task` continuations after approximately 30 seconds (the background execution grace period). The download polling loop uses `Task.sleep(for: .seconds(5))` in a loop of up to 60 iterations (5 minutes total). If the user backgrounds the app 2 minutes into a download, the loop is suspended. When the user foregrounds again, the loop resumes — but the robot may have finished downloading (or failed) while the app was suspended. The next `getUpdaterState()` call will show the correct state, but the loop's internal `downloadComplete` flag remains `false`, causing the guard condition to fail and the update to be considered failed.

**How to avoid:**
- Monitor `scenePhase` changes in the ViewModel.
- On foreground return during an active update: call `getUpdaterState()` immediately to re-sync before resuming the loop.
- Alternatively, restructure the polling loop to always check current state at the top of each iteration, not just set a flag that depends on linear execution.

**Warning signs:**
- `downloadComplete` boolean flag set only inside the loop, not re-evaluated after foregrounding.
- No `scenePhase` observation in the update-related code.

**Phase to address:**
Phase 3 (Apply hardening) — the foreground re-sync is a prerequisite for reliable apply detection.

---

### Pitfall 9: Valetudo's checkForUpdates endpoint triggers a background job — repeated calls pile up

**What goes wrong:**
`api.checkForUpdates()` calls `POST /api/v2/updater/check` which tells Valetudo to start an update check. This is not idempotent — calling it while a previous check is in progress results in a second background job on the robot. With `checkForUpdates()` currently called from both `RobotDetailViewModel.checkForUpdate()` and potentially triggered again by the settings section re-appearing, the robot may have multiple pending update-check jobs. Valetudo handles this gracefully in most cases (ignores concurrent checks), but the extra round-trip adds unnecessary latency and the `ValetudoUpdaterBusyState` response can confuse the app's state machine.

**How to avoid:**
- Call `getUpdaterState()` first. Only call `POST /check` if the state is `ValetudoUpdaterIdleState`.
- Do not call `checkForUpdates()` on every view appearance — once per app session (or once per hour) is sufficient.
- Handle `ValetudoUpdaterBusyState` explicitly: poll until busy clears, do not treat it as an error.

**Warning signs:**
- `api.checkForUpdates()` called inside a `.task` modifier that fires on every view appearance.
- No check of `updaterState.busy` before triggering a new check.

**Phase to address:**
Phase 1 (State Machine) — the check trigger condition is the first decision point of the state machine.

---

### Pitfall 10: @MainActor isolation on UIApplication.isIdleTimerDisabled

**What goes wrong:**
`UIApplication.shared` must be accessed on the main thread. `RobotDetailViewModel` is `@MainActor`-isolated, which means `UIApplication.shared.isIdleTimerDisabled = true` can be called directly from ViewModel methods. However, if the idle timer logic is extracted into a helper or called from a non-isolated context (e.g., from a `Task { }` that loses `@MainActor` isolation), a runtime warning or crash may occur.

**How to avoid:**
- Call `UIApplication.shared.isIdleTimerDisabled` only from `@MainActor`-isolated functions.
- Never extract the call to a free function without `@MainActor` annotation.
- Mark the function `@MainActor` explicitly if there is any ambiguity:
  ```swift
  @MainActor private func setIdleTimerDisabled(_ disabled: Bool) {
      UIApplication.shared.isIdleTimerDisabled = disabled
  }
  ```

**Warning signs:**
- `UIApplication.shared` access inside a `Task.detached` or from a `nonisolated` function.
- Purple runtime warning: "UIApplication must be used from main thread only."

**Phase to address:**
Phase 3 (Apply hardening) — add when implementing the idle timer prevention.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| No re-entrancy guard on `startUpdate()` | Simpler code | Double-update on rapid taps; undefined robot state | Never |
| Keeping duplicate `checkForUpdate()` in both ViewModel and View | Avoids refactor | Two separate states, diverge over time, race on concurrent calls | Never — the consolidation is Phase 2 |
| Silencing all errors after `applyUpdate()` | Fewer false positives | Cannot distinguish reboot from genuine failure | Never — model the reboot window explicitly |
| Polling loop with `downloadComplete` flag instead of state-based evaluation | Simple loop structure | Misses foreground-return case; silently exits without error | Never for production — acceptable in prototype only |
| `UIApplication.isIdleTimerDisabled` not set | No UIKit dependency | Phone sleeps mid-update; user never sees completion | Never for apply phase; acceptable for download phase |
| `updaterState` as raw `UpdaterState?` with no error enum | Matches API directly | Error states fall through silently | Acceptable as a transitional model; replace with `UpdatePhase` enum in Phase 1 |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Valetudo `POST /updater/check` | Calling it unconditionally on view appear | Check `getUpdaterState()` first; only call if state is `IdleState` |
| Valetudo `POST /updater/start` (download) | Not polling for `ApplyPendingState` before calling apply | Download is async on robot side; poll until `isReadyToApply` before firing apply |
| Valetudo `POST /updater/apply` | Treating connection-refused post-apply as failure | Robot reboots after apply; expect 30–90s of unreachability |
| GitHub API (latest release check) | Calling on every view appearance | Cache result per session; single call per robot per app launch |
| `UIApplication.isIdleTimerDisabled` | Not resetting in `defer` or error path | Always use `defer { UIApplication.shared.isIdleTimerDisabled = false }` to guarantee reset |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| GitHub API called twice per view appearance (ViewModel + settings section) | Two outbound requests to api.github.com per navigation | Cache in ViewModel; settings reads from ViewModel | Every time settings section appears while ViewModel also initializing |
| Polling loop holds CPU wakeup every 5s during download | Battery drain; logs show continuous wakeups | Polling is fine; ensure Task is cancelled when not needed | During long downloads (>5 minutes) |
| `getUpdaterState()` called concurrently from two contexts | Race on `updaterState` assignment | Single caller; settings reads published state | Every time settings section appears while ViewModel is polling |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Logging download URL with `privacy: .public` | `downloadUrl` from updater state may contain internal robot identifiers | Log presence only: `"Download URL present: \(state.downloadUrl != nil)"` |
| Applying update without confirming current version | Could apply wrong firmware version on version-check mismatch | Read `currentVersion` before and after apply to confirm version change |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No error message when download silently exits loop | User doesn't know update failed; robot remains on old firmware indefinitely | Show specific error: "Download did not complete. Check robot connection." |
| Spinner with no progress indication during download | User cannot tell if download is hanging or in progress | Poll `metaData.progress` (current/total) and show a progress bar |
| Apply button re-enabled after navigation away and back | User can tap Apply twice if they navigate and return during download | Apply button disabled until `isReadyToApply` AND not `updateInProgress`; state persists in ViewModel |
| "Update failed" shown during normal reboot window | User panics, tries to restart robot mid-reboot, risks bricking | Show "Applying update — robot restarting, please wait..." until confirmed online |
| Screen locks mid-apply; user thinks phone is doing nothing | User unlocks, dismisses the screen, navigates away | Full-screen non-dismissible modal during apply phase + idle timer disabled |

---

## "Looks Done But Isn't" Checklist

- [ ] **Re-entrancy guard:** `guard !updateInProgress else { return }` is the first statement in `startUpdate()` — not after any reads.
- [ ] **Error state modeling:** `UpdaterState.isError` returns `true` for `ValetudoUpdaterErrorState` and any unrecognised `__class` value — not just the three known states.
- [ ] **Polling loop error path:** When the polling loop exits without `downloadComplete`, a user-visible error message is set — not just `updateInProgress = false`.
- [ ] **Idle timer:** `UIApplication.shared.isIdleTimerDisabled = true` is set at apply phase start and reset in a `defer` block — confirmed present in the apply code path.
- [ ] **False-positive suppression:** After `applyUpdate()` succeeds, `URLError.cannotConnectToHost` and `URLError.timedOut` are caught separately and treated as "rebooting" — not as errors.
- [ ] **Reboot window timeout:** A maximum wait time (e.g., 180 seconds) exists for the reboot window — the app does not poll forever.
- [ ] **Version verification:** After robot comes back online, `currentVersion` is compared to the pre-update version — success is confirmed, not assumed.
- [ ] **Duplicate logic removed:** Only one `checkForUpdate()` function exists; settings section reads from the ViewModel's `@Published` state.
- [ ] **Navigation lock:** Apply phase shows a non-dismissible modal (`interactiveDismissDisabled(true)`) — back-navigation is blocked while applying.
- [ ] **Foreground re-sync:** When `scenePhase` changes from `.background` to `.active` during an update, `getUpdaterState()` is called immediately to re-sync before the polling loop continues.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Double-tap triggers two downloads | LOW | Robot ignores second request in most cases. Add guard, rebuild. No data loss. |
| Silent download failure with no error shown | LOW | User re-triggers check. Add error state to model and surface it. |
| Phone slept during apply, update success not detected | MEDIUM | On next launch, call `getUpdaterState()` — `currentVersion` will show new version if successful. Show a "Update may have completed" recovery banner. |
| False-positive "update failed" during reboot | MEDIUM | Robot comes back online fine. App shows stale error. Fix: suppress network errors in reboot window. User work-around: force-quit and reopen app. |
| Navigation away during apply kills polling Task | HIGH | Robot may have applied successfully but app has no record. On next launch, compare version. If higher, show "Update applied successfully" retroactively. |
| Duplicate state desync causes button re-enable mid-download | MEDIUM | User sees download button during active download. Consolidate state to single ViewModel. Short-term: disable button based on both `updateInProgress` AND polling state. |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Re-entrancy: no guard on startUpdate() | Phase 1 — State Machine | Unit test: call `startUpdate()` twice in rapid succession; assert second call is no-op |
| No error state in UpdaterState | Phase 1 — State Machine | Unit test: feed unknown `__class` string to `UpdaterState`; assert `isError == true` |
| Polling loop silent exit on error | Phase 1 — State Machine | Unit test: simulate download loop exit without `downloadComplete`; assert error state set |
| checkForUpdates() on every appearance | Phase 2 — Consolidation | Code review: single `.task` guard; confirm `getUpdaterState()` not called from both files |
| Duplicate update logic in two files | Phase 2 — Consolidation | Code review: zero occurrences of `checkForUpdate()` outside ViewModel after phase |
| No idle timer prevention | Phase 3 — Apply hardening | Manual test: lock screen during apply; confirm update completes and success shown on unlock |
| False-positive failure during reboot | Phase 3 — Apply hardening | Manual test: trigger apply, verify "rebooting" state shown for 30–90s, then success |
| User can navigate away during apply | Phase 4 — Navigation lock | Manual test: trigger apply, attempt back-navigation; confirm sheet is non-dismissible |
| App backgrounding suspends polling | Phase 3 — Apply hardening | Manual test: background app during download, foreground after 60s, confirm state syncs |
| Valetudo busy state not handled | Phase 1 — State Machine | Code review: `ValetudoUpdaterBusyState` mapped in `UpdaterState`; polling waits for busy to clear |

---

## Sources

- ValetudiOS codebase: `RobotDetailViewModel.swift` lines 448–490, `RobotSettingsSections.swift` lines 779–973 (direct analysis, 2026-03-29)
- [Actor reentrancy in Swift explained — Donny Wals](https://www.donnywals.com/actor-reentrancy-in-swift-explained/)
- [Reasoning about actor re-entrancy — Swift Forums](https://forums.swift.org/t/reasoning-about-actor-re-entrancy-suspension-for-optional-await-s/62314)
- [isIdleTimerDisabled — Apple Developer Documentation](https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled)
- [Revert UIApplication isIdleTimerDisabled — Hacking with Swift Forums](https://www.hackingwithswift.com/forums/swift/revert-uiapplication-shared-isidletimerdisabled-to-its-initial-state/17686)
- [URLSession: Common pitfalls with background download & upload tasks — Antoine van der Lee](https://www.avanderlee.com/swift/urlsession-common-pitfalls-with-background-download-upload-tasks/)
- [How iOS Suspends and Wakes Apps — Medium](https://mohsinkhan845.medium.com/how-ios-suspends-and-wakes-apps-understanding-the-app-lifecycle-af56bc763f27)
- [OTA Update Checklist for Embedded Devices — Memfault](https://memfault.com/blog/ota-update-checklist-for-embedded-devices/)
- [Building Bulletproof OTA Updates for Embedded Systems — Medium](https://medium.com/@akashsainisaini37/building-bulletproof-ota-updates-for-embedded-systems-beefdd88e882)
- Valetudo API source: `/api/v2/updater` endpoint state classes (ValetudoUpdaterIdleState, ValetudoUpdaterApprovalPendingState, ValetudoUpdaterDownloadingState, ValetudoUpdaterApplyPendingState, ValetudoUpdaterErrorState)

---
*Pitfalls research for: ValetudiOS v2.0.0 — Firmware update process hardening*
*Researched: 2026-03-29*
