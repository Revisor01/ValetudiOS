# Stack Research

**Domain:** iOS Firmware Update UX — v2.0.0 Update Process Hardening
**Researched:** 2026-03-29
**Confidence:** HIGH (all patterns are Apple-native, iOS 17+ only, verified against Apple Developer Documentation)

---

## Context: What is NOT Changing

The existing stack is locked and validated:

- Swift 5.9, SwiftUI, iOS 17+
- `@MainActor ObservableObject` ViewModels (RobotDetailViewModel, RobotSettingsViewModel)
- URLSession + structured concurrency (`async/await`, `Task`, `actor`)
- `os.Logger` logging, Keychain storage
- Zero external dependencies — this constraint applies to all additions below

**Existing update code state (as found):**

`RobotDetailViewModel` has two redundant `@Published` properties for the same concept:
- `isUpdating: Bool` and `updateInProgress: Bool` — both describe "update is in flight"
- `updaterState: UpdaterState?` — polled server state, not the app's own lifecycle state

`RobotSettingsSections.swift` has a *third* `@State private var updaterState: UpdaterState?` — a local copy that duplicates ViewModel state.

The `startUpdate()` function encodes state machine transitions implicitly via `let needsDownload` / `let needsApply` booleans computed at call site, with no guard against double-invocation.

All patterns below replace this implicit state with explicit, compiler-enforced state.

---

## Recommended Patterns for v2.0.0

### 1. Enum-Based State Machine — Single Source of Truth

**Why:** The existing `isUpdating + updateInProgress + updaterState?` combination cannot express all states unambiguously. An enum makes illegal states unrepresentable at the type level. The Swift compiler then enforces exhaustive handling everywhere the state is consumed.

**Pattern:**

```swift
enum UpdatePhase: Equatable {
    case idle
    case checking
    case downloading(progress: Double)   // 0.0–1.0
    case readyToApply
    case applying
    case done
    case failed(UpdateError)
}

enum UpdateError: Error, Equatable {
    case checkFailed(String)
    case downloadFailed(String)
    case applyFailed(String)
    case timeout
}
```

**Placement:** Add `UpdatePhase` as a nested type or top-level type in the same file as `RobotDetailViewModel`. Replace `isUpdating`, `updateInProgress`, and `showUpdateWarning` with a single `@Published var updatePhase: UpdatePhase = .idle`.

**Transition guards — prevent double-invocation:**

```swift
@MainActor
func beginUpdate() async {
    guard case .idle = updatePhase else { return }  // guard at call site
    updatePhase = .checking
    // ...
    guard case .readyToApply = updatePhase else { return }
    updatePhase = .applying
}
```

The `guard case` pattern extracts associated values and short-circuits cleanly. No boolean flags needed.

**SwiftUI exhaustive switch — forces all states to be handled in UI:**

```swift
switch viewModel.updatePhase {
case .idle:             UpdateIdleView(...)
case .checking:         ProgressView("Checking...")
case .downloading(let p): DownloadProgressView(progress: p)
case .readyToApply:     ApplyButtonView(...)
case .applying:         ApplyingView()
case .done:             UpdateDoneView()
case .failed(let err):  UpdateErrorView(error: err)
}
```

**Confidence:** HIGH — enum state machines are a standard Swift pattern, documented in Swift Evolution proposals and endorsed in WWDC content on Swift concurrency.

---

### 2. Button Disable Pattern — `.disabled()` Modifier Tied to State

**Why:** SwiftUI's `.disabled()` modifier is the correct, declarative way to prevent button interaction. It is driven by the state machine — no separate `isEnabled` boolean needed.

**Pattern:**

```swift
// A computed property on the ViewModel (or inline in the View)
var canStartUpdate: Bool {
    if case .idle = updatePhase { return true }
    if case .readyToApply = updatePhase { return true }
    return false
}

// In the View
Button("Update") {
    Task { await viewModel.beginUpdate() }
}
.disabled(!viewModel.canStartUpdate)
```

**Why not a separate boolean:** A separate `isEnabled` boolean can drift out of sync with the state machine. Deriving it from `updatePhase` makes it impossible for the button to be enabled while an update is running.

**`@MainActor` requirement:** All `@Published` mutations must happen on the main actor. The ViewModel is already `@MainActor ObservableObject` — this is satisfied. The `Task { await viewModel.beginUpdate() }` in the button action creates a detached task on the main actor context.

**Confidence:** HIGH — documented in SwiftUI `disabled(_:)` modifier reference. The `@MainActor` interaction is documented in SE-0316 (Global Actors).

---

### 3. Blocking UI During Apply Phase — `fullScreenCover` + `interactiveDismissDisabled`

**Why:** The apply phase is destructive and non-cancellable. The robot will reboot. The user must not be able to navigate away, dismiss a sheet, or trigger any robot command while this is in progress.

**Mechanism:**

`fullScreenCover` already blocks all interaction with the content behind it. Adding `.interactiveDismissDisabled()` removes the swipe-down gesture. Controlling `isPresented` from the state machine (not from user action) means only the app — never the user — can dismiss it.

**Pattern:**

```swift
// In the parent View (e.g. RobotSettingsView)
.fullScreenCover(isPresented: $viewModel.isApplyPhaseActive) {
    UpdateApplyingView()
        .interactiveDismissDisabled()   // belt-and-suspenders for fullScreenCover
}

// Computed property on ViewModel
var isApplyPhaseActive: Bool {
    switch updatePhase {
    case .applying, .done: return true
    default: return false
    }
}
```

**Why `fullScreenCover` and not `.overlay` or `.sheet`:**
- `.sheet` can be dismissed with a swipe on iOS (`.interactiveDismissDisabled()` prevents this, but it is a second line of defence, not primary)
- `.overlay` does not prevent interaction with the content behind it unless combined with `allowsHitTesting(false)` on the underlying view — more fragile
- `fullScreenCover` blocks the entire screen by design; no underlying content is hittable

**Why keep it presented for `.done` as well:** The robot reboots after `.applying`. The "done" state should show a success message and a "Close" button the user taps intentionally. Dismissing automatically risks the user missing the success state.

**Confidence:** HIGH — `fullScreenCover` and `interactiveDismissDisabled` documented on developer.apple.com. The pattern of state-driven `isPresented` is SwiftUI standard practice.

---

### 4. Progress Tracking — Determinate `ProgressView` With Polled State

**Why:** The Valetudo updater API exposes download progress via `GET /api/v2/updater` which returns a `progress` field (0–100 integer) when `status == "downloading"`. This is a polling approach — not streaming — which matches the existing app architecture.

**Pattern:**

```swift
// State machine carries progress as associated value
case downloading(progress: Double)   // derived from updaterState.progress / 100

// In View
if case .downloading(let p) = viewModel.updatePhase {
    VStack {
        ProgressView(value: p, total: 1.0)
            .progressViewStyle(.linear)
        Text("\(Int(p * 100))%")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
```

**Polling loop with progress update:**

```swift
@MainActor
private func pollDownloadProgress() async throws {
    for attempt in 0..<60 {   // 5-min max (60 * 5s)
        try await Task.sleep(for: .seconds(5))
        let state = try await api.getUpdaterState()
        if let progress = state.progress {
            updatePhase = .downloading(progress: Double(progress) / 100.0)
        }
        if state.isReadyToApply {
            updatePhase = .readyToApply
            return
        }
        if !state.isDownloading {
            throw UpdateError.downloadFailed("Unexpected state: \(state.status ?? "unknown")")
        }
    }
    throw UpdateError.timeout
}
```

**Why polling and not URLSession download delegate:** The app does not download the firmware binary itself — it tells the robot to download it via `POST /api/v2/updater/downloadLatestUpdate`. The progress lives on the robot, not in the iOS app's URLSession. The only way to track it is to poll the robot's `/api/v2/updater` endpoint.

**Confidence:** HIGH — Valetudo OpenAPI spec confirms the `progress` field exists on the updater state response. Polling approach matches existing `startUpdate()` implementation in `RobotDetailViewModel`.

---

### 5. Preventing Screen Sleep — `UIApplication.shared.isIdleTimerDisabled`

**Why:** The download + apply sequence can take several minutes. iOS will lock the screen after the system idle timeout (typically 30 seconds to 2 minutes). If the app is backgrounded or the screen locks during apply, the polling task is suspended, and the user loses progress visibility.

**Pattern:**

```swift
@MainActor
private func withIdleTimerDisabled(_ work: () async throws -> Void) async rethrows {
    UIApplication.shared.isIdleTimerDisabled = true
    defer { UIApplication.shared.isIdleTimerDisabled = false }
    try await work()
}

// Usage in beginUpdate():
await withIdleTimerDisabled {
    try await pollDownloadProgress()
    try await api.applyUpdate()
}
```

**Scope:** Enable only during `.downloading` and `.applying` phases. Disable immediately when entering `.done`, `.failed`, or `.idle`. The `defer` block ensures it is always re-enabled even if an error is thrown.

**iOS Scene lifecycle:** The app targets iOS 17+ with SwiftUI lifecycle (`@main App`). In pure SwiftUI lifecycle apps, UIKit scene delegate methods are not used. Setting `isIdleTimerDisabled` from a `@MainActor` context (i.e., from the ViewModel) is correct — no AppDelegate or SceneDelegate interaction required. Apple's own documentation confirms setting this from any UIKit-accessible main-thread context works.

**Why not `ProcessInfo.performActivity`:** `ProcessInfo.performActivity(options:reason:)` is for preventing *process* sleep (App Nap on macOS) and automatic termination, not screen sleep. It does not affect `isIdleTimerDisabled`. For screen-on during a foreground operation, `isIdleTimerDisabled` is the correct API.

**Confidence:** HIGH — `UIApplication.isIdleTimerDisabled` documented on developer.apple.com. Pattern of `defer { isIdleTimerDisabled = false }` is established practice in the iOS community (multiple Stack Overflow answers, Hacking with Swift).

---

### 6. Background Task Completion — UIKit `beginBackgroundTask`

**Why:** If the user presses the Home button during download/apply, iOS suspends the app. A `UIBackgroundTask` buys ~30 additional seconds of execution time — enough for a polling cycle to complete and the state to be persisted.

**When to use:** Only during `.applying`. Downloading can be safely interrupted because the download lives on the robot, not the phone. Applying triggers the robot's reboot sequence — the app only needs to receive the HTTP 200 response before being suspended.

**Pattern:**

```swift
@MainActor
private func applyUpdateWithBackgroundTask() async throws {
    var bgTask = UIBackgroundTaskIdentifier.invalid
    bgTask = UIApplication.shared.beginBackgroundTask(withName: "valetudo.apply") {
        // Expiry handler — called if we run out of time
        UIApplication.shared.endBackgroundTask(bgTask)
        bgTask = .invalid
    }
    defer {
        UIApplication.shared.endBackgroundTask(bgTask)
        bgTask = .invalid
    }
    try await api.applyUpdate()
}
```

**Why not BGProcessingTask / BGAppRefreshTask:** Background Tasks framework (`BackgroundTasks`) is for work scheduled for the future (when the app is not in the foreground). It cannot be started on-demand mid-operation. `UIBackgroundTask` is the correct API for "I am currently doing important work, please don't suspend me yet."

**Confidence:** HIGH — `UIApplication.beginBackgroundTask` documented on developer.apple.com. Distinguished from `BGProcessingTask` which is for scheduled background work.

---

## Integration with Existing MVVM Architecture

| Existing Code | What Changes | Why |
|---------------|--------------|-----|
| `RobotDetailViewModel.isUpdating: Bool` | Remove — replaced by `updatePhase` | Redundant with `updateInProgress` |
| `RobotDetailViewModel.updateInProgress: Bool` | Remove — replaced by `updatePhase` | Single source of truth |
| `RobotDetailViewModel.showUpdateWarning: Bool` | Remove — derive from `updatePhase == .failed(...)` | No separate boolean needed |
| `RobotDetailViewModel.updaterState: UpdaterState?` | Keep — this is *server* state | It tracks what the robot thinks its state is; `updatePhase` tracks what the *app* thinks it should do next |
| `RobotSettingsSections.updaterState: @State` | Remove — read from ViewModel only | Eliminates duplicate state |
| `startUpdate()` — no guard | Add `guard case .idle = updatePhase else { return }` | Prevents double-invocation |
| `startUpdate()` — no progress update | Emit `updatePhase = .downloading(progress:)` in poll loop | Enables UI progress display |

**ViewModel stays `@MainActor ObservableObject`** — all mutations to `updatePhase` happen on the main actor. This is already the existing architecture; no changes to threading model.

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Multiple `Bool` flags for update state | Can express `2^n` combinations, most of which are invalid (e.g., `isUpdating = true` AND `updateInProgress = false`) | Single `UpdatePhase` enum |
| `Combine.PassthroughSubject` for state transitions | Adds Combine complexity; app already uses structured concurrency throughout | Enum + `@Published` |
| Any third-party state machine library (ReactKit/SwiftState etc.) | Breaks zero-deps constraint; overkill for a 7-case enum | Native Swift enum with `guard case` pattern |
| `BGProcessingTask` or `BGAppRefreshTask` | Wrong API — these are for *scheduled* future background work, not in-progress operations | `UIBackgroundTask` (`beginBackgroundTask`) |
| `ProcessInfo.performActivity` | Prevents App Nap / automatic termination (macOS concept); does not affect screen sleep on iOS | `UIApplication.isIdleTimerDisabled` |
| `DispatchQueue.main.async` for state mutations | Already migrated to structured concurrency in v1.4.0; reverting creates mixed concurrency models | `@MainActor` + `await MainActor.run {}` if needed off-actor |

---

## Alternatives Considered

| Recommended | Alternative | When Alternative is Better |
|-------------|-------------|---------------------------|
| `fullScreenCover` + `interactiveDismissDisabled` | `.overlay` with `allowsHitTesting(false)` | Never for this case — overlay does not prevent navigation or tab switching at higher levels of the hierarchy |
| `UIApplication.isIdleTimerDisabled` | `UIScreen.main.brightness = 1.0` (keep screen max-bright) | Never — does not prevent sleep, only keeps brightness up |
| Polling `GET /api/v2/updater` for progress | URLSession `downloadTask` delegate for byte-level progress | Only if the app itself downloaded the firmware binary (it does not — the robot does) |
| Enum `UpdatePhase` with `Equatable` | SwiftUI `@State` navigation enum | `@State` is for view-local state; update lifecycle belongs in the ViewModel |

---

## Version Compatibility

All patterns target iOS 17.0+ (existing deployment target). All APIs are available on iOS 17:

| API / Pattern | Available Since | Notes |
|---------------|-----------------|-------|
| Swift enum with associated values | Swift 1.0 | — |
| `guard case` pattern matching | Swift 2.0 | — |
| `@Published` + `@MainActor ObservableObject` | iOS 13.0 | Already used throughout app |
| `ProgressView(value:total:)` | iOS 14.0 | Linear progress bar built-in |
| `fullScreenCover(isPresented:)` | iOS 14.0 | — |
| `.interactiveDismissDisabled()` | iOS 15.0 | — |
| `UIApplication.isIdleTimerDisabled` | iOS 2.0 | — |
| `UIApplication.beginBackgroundTask` | iOS 4.0 | — |

No minimum version bumps required. All additions are below the existing iOS 17 deployment target.

---

## Sources

- Apple Developer Documentation: `fullScreenCover(isPresented:onDismiss:content:)` — [https://developer.apple.com/documentation/swiftui/view/fullscreencover(ispresented:ondismiss:content:)](https://developer.apple.com/documentation/swiftui/view/fullscreencover(ispresented:ondismiss:content:)) (HIGH confidence)
- Apple Developer Documentation: `interactiveDismissDisabled()` — confirmed available iOS 15+ (HIGH confidence, via SwiftUI modifier reference)
- Apple Developer Documentation: `UIApplication.isIdleTimerDisabled` — [https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled](https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled) (HIGH confidence)
- Apple Developer Documentation: `UIApplication.beginBackgroundTask(withName:expirationHandler:)` — [https://developer.apple.com/documentation/uikit/uiapplication/beginbackgroundtask(withname:expirationhandler:)](https://developer.apple.com/documentation/uikit/uiapplication/beginbackgroundtask(withname:expirationhandler:)) (HIGH confidence)
- Apple Developer Documentation: `BGProcessingTask` — [https://developer.apple.com/documentation/backgroundtasks/bgprocessingtask](https://developer.apple.com/documentation/backgroundtasks/bgprocessingtask) — confirmed: scheduled background work only, NOT for in-progress operations (HIGH confidence)
- WebSearch: "Swift enum state machine guard invalid state" — splinter.com.au article and betterprogramming.pub article confirm `guard case` pattern as community standard (MEDIUM confidence, multiple sources agree)
- WebSearch: "UIApplication isIdleTimerDisabled Swift iOS prevent screen sleep" — hackingwithswift.com, developermemos.com confirm `defer` pattern (MEDIUM confidence, consistent across sources)
- Existing codebase: `RobotDetailViewModel.startUpdate()` lines 450–490 — duplicate boolean analysis based on direct code read (HIGH confidence)

---

*Stack research for: ValetudiOS v2.0.0 — Firmware Update Process Hardening*
*Researched: 2026-03-29*
