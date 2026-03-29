# Project Research Summary

**Project:** ValetudiOS — Firmware Update Process Hardening (v2.0.0)
**Domain:** iOS/SwiftUI — OTA firmware update UX for IoT robot vacuum controller
**Researched:** 2026-03-29
**Confidence:** HIGH

## Executive Summary

ValetudiOS v2.0.0 addresses a focused but safety-critical domain: hardening the firmware update flow for Valetudo-controlled robot vacuums. The existing implementation works in the happy path but has multiple failure modes ranging from confusing (silent download errors with no user feedback) to potentially dangerous (double-invocation sending two concurrent update requests, navigation away killing an in-flight apply sequence). The research is unambiguously clear that the root cause of all these failure modes is a single architectural issue: update state is modeled as multiple boolean flags scattered across three separate code locations rather than as a single authoritative state machine.

The recommended approach is to introduce a dedicated `UpdateService` per robot, owned by the long-lived `RobotManager`, which drives all update logic through an `UpdatePhase` enum. This is not a rewrite — it is a surgical extraction and consolidation. The Valetudo server already exposes a clean 7-state state machine via `GET /api/v2/updater/state`. The iOS app simply needs to mirror it faithfully, add two client-only states (`.checking` and `.applying`), and ensure all UI decisions derive from one published property. All patterns required are Apple-native, iOS 17+-compatible, and zero external dependencies are needed.

The highest-risk pitfall is the apply phase: after `applyUpdate()` is called, the robot reboots and goes offline. The current code cannot distinguish a successful reboot from a genuine failure, navigation away during this window kills the polling Task, and the phone's idle timer can lock the screen mid-operation. These three issues must be addressed together in a single phase — they are interdependent. The lower-risk improvements (progress display, error messages, update-check throttling) are best addressed in a final UI wiring phase once the service layer is stable.

## Key Findings

### Recommended Stack

The existing stack is fully locked: Swift 5.9, SwiftUI, iOS 17+, `@MainActor ObservableObject` ViewModels, URLSession with structured concurrency, `os.Logger`, Keychain. No new dependencies are required for this milestone. All patterns identified in research (enum state machines, `fullScreenCover`, `interactiveDismissDisabled`, `UIApplication.isIdleTimerDisabled`, `UIBackgroundTask`) are Apple-native APIs available since iOS 14-15, well below the iOS 17 deployment target.

**Core additions (all Apple-native):**
- `UpdatePhase` enum with associated values — replaces three redundant boolean `@Published` properties; makes illegal states unrepresentable at the type level
- `UIApplication.isIdleTimerDisabled` — prevents screen sleep during download/apply; must be managed with `defer` on `@MainActor`
- `UIApplication.beginBackgroundTask` — buys ~30s of execution time if user backgrounds during apply; correct API for in-progress operations (not `BGProcessingTask`, which is for scheduled future work)
- `fullScreenCover` + `interactiveDismissDisabled` — blocks UI during apply phase; stronger than `.sheet` (swipeable) and stronger than `.overlay` (does not block navigation hierarchy)
- `ProgressView(value:total:)` — determinate progress display; data already decoded in `UpdaterState.metaData.progress`; only UI wiring needed

### Expected Features

The research identified existing infrastructure that is already in place but not wired to the UI (`metaData.progress.current/total` is decoded but never displayed). Industry comparison against Apple Home, Roborock, eufy, Sonos, and Tesla confirms that the patterns required are standard for IoT firmware apps. Sonos's cautionary example — blocking the entire app for one device's update — is explicitly what to avoid; the UI lock must be scoped to the specific robot's context, not the entire app.

**Must have (table stakes, all P1):**
- `UpdatePhase` state machine with a single `@Published` source of truth — foundational; everything else builds on this
- Double-invocation guard on `startUpdate()` — safety-critical; missing guard causes undefined robot state
- User-visible error state with message — currently all failures silently reset `updateInProgress = false`
- Download progress percentage — data already available; wiring is a UI-only change
- Apply-phase fullscreen lock — prevents navigation away during the most dangerous phase

**Should have (P2, after core is stable):**
- Post-apply reconnect detection with auto-dismiss of the fullscreen cover on success
- Retry button in error state — avoids requiring a full flow restart after a transient error
- Update-check throttling (`lastCheckDate`) — prevents `POST /updater/check` firing on every view appear (this triggers a background job on the robot each time)

**Defer (v2.x):**
- Dual-source consolidation (Valetudo updater API vs. GitHub releases API) — architectural cleanup with no user-facing change; safe to defer if time-constrained

### Architecture Approach

The target architecture introduces one new type (`UpdateService`) and modifies four existing files. `UpdateService` is a `@MainActor final class ObservableObject` owned by `RobotManager` (one instance per robot) and survives view navigation. `RobotDetailViewModel` becomes a thin pass-through that reads `UpdateService.phase` and delegates calls. `ValetudoInfoView` drops its own duplicate `checkForUpdate()` entirely. `ValetudoAPI` is unchanged — all four updater endpoints already exist and are correctly implemented.

The build order is strictly dependency-layered: model types first, then service, then manager wiring, then ViewModel cleanup, then UI. Each layer is testable before the next is started.

**Major components:**
1. `UpdatePhase` enum + `UpdateError` struct (in `Models/RobotState.swift`) — domain model types shared across all layers; `UpdatePhase` init from `UpdaterState` is the single mapping point from server strings to client state
2. `UpdateService` (new `Services/UpdateService.swift`) — owns state machine, re-entrancy guard (`activeTask != nil`), polling loop, error surface, check throttling; scoped per robot
3. `RobotManager` (modified) — creates and owns one `UpdateService` per robot; feeds `robotUpdateAvailable[UUID]` badge from `UpdateService.phase.isUpdateAvailable`
4. `RobotDetailViewModel` (modified, slimmed) — removes 5 `@Published` properties; exposes computed `updatePhase` and delegating `startUpdate()` / `applyDownloadedUpdate()`
5. `RobotDetailView` + optional `UpdateBannerView` (modified) — exhaustive `switch updatePhase`; `fullScreenCover` for `.applying`; `interactiveDismissDisabled`

### Critical Pitfalls

1. **No re-entrancy guard on `startUpdate()`** — `@MainActor` does not prevent two `Task { await startUpdate() }` calls from both reading `updateInProgress == false` before either sets it. Fix: `guard activeTask == nil else { return }` as the very first statement. Must be addressed in Phase 1 before any other hardening is layered on top.

2. **Apply phase is indistinguishable from failure during robot reboot** — `URLError.cannotConnectToHost` after a successful `applyUpdate()` is the normal reboot window (30-90s), not an error. Current code treats it as failure. Fix: model a distinct `.applying` state; suppress connection errors during the reboot window; only declare failure after a 3-minute timeout; confirm success by comparing `currentVersion` pre- and post-update.

3. **Phone sleep kills apply phase visibility** — no `UIApplication.isIdleTimerDisabled` exists anywhere in the codebase (confirmed). Idle timer fires after 2 minutes; screen locks; polling loop may be throttled; user never sees completion. Fix: enable at apply-phase start, reset in `defer` on `@MainActor`.

4. **Navigation away during apply destroys the polling Task** — `@StateObject` ViewModel is deallocated on navigation pop; in-flight Task is cancelled. Fix: `UpdateService` lives in `RobotManager` (app lifetime), not in the ViewModel (view lifetime). Task survives navigation.

5. **Duplicate `checkForUpdate()` in ViewModel and View creates state desync** — both paths write to separate state variables; concurrent calls can re-enable the Update button mid-download. Fix: `ValetudoInfoView` reads from `UpdateService.phase` published state; never calls `getUpdaterState()` independently.

## Implications for Roadmap

Based on research, the dependency structure dictates a strict 4-phase build order. Phases are not arbitrary slices — each phase's output is a direct prerequisite for the next. Skipping or reordering will produce integration conflicts.

### Phase 1: State Machine Foundation

**Rationale:** All other improvements depend on a single source of truth existing. The re-entrancy guard (Pitfall 1), error state modeling (Pitfall 2), and check-trigger logic (Pitfall 9) must exist before any UI or service layer is built on top. This is the riskiest phase to skip — everything else stacks on it.
**Delivers:** `UpdatePhase` enum, `UpdateError` struct, `UpdateService` skeleton with re-entrancy guard and error state. Update state is now represented by one type consumed everywhere.
**Addresses:** State machine (table stakes P1), double-invocation guard, error state with user message
**Avoids:** Pitfall 1 (re-entrancy), Pitfall 2 (silent error exit), Pitfall 9 (check trigger piling up on robot)

### Phase 2: State Consolidation

**Rationale:** With the state machine defined, duplicate code paths must be eliminated before the service is wired into the UI. If both old paths and new service coexist, the desync problem (Pitfall 7) becomes worse, not better. Consolidation before UI wiring is the correct order.
**Delivers:** `RobotManager` wired to `UpdateService`; `RobotDetailViewModel` slimmed to pass-through; `ValetudoInfoView` duplicate check logic removed. Single state owner confirmed throughout the codebase.
**Addresses:** Dual-source problem, state desync pitfall, per-view `@State var updaterState` elimination
**Avoids:** Pitfall 3 (view-level state divergence during active download), Pitfall 7 (duplicate logic race condition)

### Phase 3: Apply Phase Hardening

**Rationale:** The apply phase is the highest-risk operation. The three apply-phase pitfalls (idle timer, false-positive failure, background suspension) are interdependent — fixing one without the others leaves the sequence unreliable end-to-end. All three must ship together in one phase.
**Delivers:** `UIApplication.isIdleTimerDisabled` management with `defer`; reboot window state modeling (suppress `URLError.cannotConnectToHost` for 180s post-apply); `UIBackgroundTask` for the apply HTTP call; foreground re-sync on `scenePhase` change from background to active.
**Addresses:** Apply-phase hardening features, reconnect detection foundation, post-apply version verification
**Avoids:** Pitfall 4 (phone sleep), Pitfall 5 (false-positive failure during reboot window), Pitfall 6 (navigation away kills Task — prevented by UpdateService in RobotManager), Pitfall 8 (background suspension suspends polling loop), Pitfall 10 (`@MainActor` isolation on UIKit)

### Phase 4: UI Wiring and Navigation Lock

**Rationale:** With a reliable service and state machine in place, the UI changes are low-risk and straightforward. UI phase comes last because all `viewModel.updatePhase` cases must be stable before views switch on them exhaustively. The `fullScreenCover` depends on Phase 3's apply-phase state being correctly modeled.
**Delivers:** `RobotDetailView` updated with exhaustive `switch viewModel.updatePhase`; `fullScreenCover` with `interactiveDismissDisabled` for `.applying`; download `ProgressView(value:total:)` wired to `UpdateService`; error banner with Retry and Dismiss actions; update-check throttling (`lastCheckDate` guard in `checkForUpdate()`).
**Addresses:** All P1 table-stakes features completed in UI, P2 differentiators (apply-phase lock, retry, throttling)
**Avoids:** Pitfall 6 (navigation away during apply — fullscreen cover blocks it), UX pitfalls (no progress, no error message, screen locks mid-apply)

### Phase Ordering Rationale

- Model types must precede service, service must precede manager wiring, manager must precede ViewModel cleanup, ViewModel must precede View changes — strict bottom-up dependency chain with no valid shortcuts.
- The three apply-phase pitfalls (4, 5, 8) are clustered in Phase 3 because they share a root cause (no durable apply-phase state that survives backgrounding and navigation) and their fixes interact: idle timer + background task + reboot window suppression all defend the same operation window.
- UI changes are deliberately last — this is a hardening milestone, not a feature milestone. Correctness before cosmetics.
- The dual-source GitHub/Valetudo consolidation is intentionally deferred to v2.x: it is architectural cleanup with no user-facing impact and significant refactor surface area relative to its benefit.

### Research Flags

Phases with well-documented patterns (skip `/gsd:research-phase`):
- **Phase 1:** Swift enum state machines are a standard, thoroughly documented Swift pattern. No additional research needed.
- **Phase 2:** Consolidation is mechanical wiring of existing components. No research needed.
- **Phase 4:** All UI components (`fullScreenCover`, `ProgressView`, `interactiveDismissDisabled`) have HIGH-confidence Apple documentation. No research needed.

Phases that may benefit from targeted implementation-time checks:
- **Phase 3:** `UIBackgroundTask` expiry handler behavior and exact background execution time limits vary by iOS version (nominally ~30s). Worth confirming current iOS 17+ behavior before implementation. Also: the exact Valetudo server state sequence after robot comes back online (does it return `ValetudoUpdaterIdleState` or `ValetudoUpdaterNoUpdateRequiredState` first?) should be confirmed against Valetudo `Updater.js` before coding the reconnect detection termination condition.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All patterns are Apple-native, verified against official Apple Developer Documentation. Zero ambiguity on API availability for iOS 17+. |
| Features | HIGH | Issues confirmed by direct source inspection of `RobotDetailViewModel.swift` and `RobotSettingsSections.swift`. Industry patterns verified against multiple real apps (Apple Home, Roborock, eufy, Sonos). |
| Architecture | HIGH | Server state machine confirmed from Valetudo `Updater.js` source. Component responsibilities derived from direct codebase analysis. Build order validated against dependency graph. |
| Pitfalls | HIGH | Each pitfall confirmed by direct source inspection. iOS concurrency pitfalls cross-referenced against Swift Forum, Donny Wals, and Apple documentation. `@MainActor` re-entrancy window analyzed precisely. |

**Overall confidence:** HIGH

### Gaps to Address

- **Post-apply server state sequence:** It is confirmed that the robot reboots after `applyUpdate()` succeeds. It is not confirmed whether the server returns `ValetudoUpdaterIdleState` or `ValetudoUpdaterNoUpdateRequiredState` as the first state after reboot. The `UpdateService` reconnect detection termination condition depends on this. Validate against Valetudo `Updater.js` during Phase 3 implementation before coding the polling exit condition.

- **`ValetudoUpdaterBusyState` exact class name:** Pitfall 9 identifies that `POST /updater/check` can return a busy state if a check is already in progress. The exact `__class` string for this state and its API behavior are not confirmed from the existing `UpdaterState` model in the codebase. Confirm the exact class name and add a mapping in `UpdatePhase.init(from:)` during Phase 1.

- **Background execution time limit on iOS 17+:** `UIApplication.beginBackgroundTask` nominally provides ~30 seconds. For the apply HTTP request this is sufficient (request should complete in under 5 seconds). The gap is minor but the exact expiry handler behavior on time-out warrants a brief check during Phase 3 to ensure the `defer` cleanup runs correctly.

## Sources

### Primary (HIGH confidence)
- Valetudo `Updater.js` — server-side state machine and transition triggers: `https://github.com/Hypfer/Valetudo/blob/master/backend/lib/updater/Updater.js`
- ValetudiOS codebase: `RobotDetailViewModel.swift` (lines 448-490), `RobotSettingsSections.swift` (lines 779-973), `RobotManager.swift`, `RobotState.swift` — direct analysis, 2026-03-29
- Apple Developer Documentation: `fullScreenCover(isPresented:onDismiss:content:)`, `interactiveDismissDisabled()`, `UIApplication.isIdleTimerDisabled`, `UIApplication.beginBackgroundTask(withName:expirationHandler:)`, `BGProcessingTask`

### Secondary (MEDIUM confidence)
- Swift Forums: Actor reentrancy analysis — `https://forums.swift.org/t/reasoning-about-actor-re-entrancy-suspension-for-optional-await-s/62314`
- Donny Wals: Actor reentrancy in Swift explained — `https://www.donnywals.com/actor-reentrancy-in-swift-explained/`
- Hacking with Swift: `isIdleTimerDisabled` + `defer` pattern — confirmed consistent across hackingwithswift.com and developermemos.com
- App UX comparison: Apple Home, eufy Security, Roborock, Sonos, Tesla app update flows — editorial descriptions

### Tertiary (LOW confidence)
- Memfault OTA update checklist for embedded devices — general principles for reboot window and version-verification recommendations (not iOS-specific)
- Medium: Building Bulletproof OTA Updates for Embedded Systems — post-apply verification pattern reference only

---
*Research completed: 2026-03-29*
*Ready for roadmap: yes*
