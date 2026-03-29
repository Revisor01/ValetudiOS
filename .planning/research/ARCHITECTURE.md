# Architecture Research

**Domain:** iOS SwiftUI App — Update Process Hardening (ValetudiOS v2.0.0)
**Researched:** 2026-03-29
**Confidence:** HIGH

## Context: What Exists Today

Before describing the target architecture, the current state must be understood precisely, because this milestone is surgical — not a rewrite.

### Current Update Logic Distribution (Problem)

```
RobotDetailViewModel            ValetudoInfoView (View)
────────────────────────        ────────────────────────
checkForUpdate()                checkForUpdate()          ← DUPLICATE
  - getValetudoVersion()          - getUpdaterState()
  - checkForUpdates()             - github API fetch
  - getUpdaterState()
  - github API fetch
  - sets: currentVersion,
    latestVersion, updateUrl,
    updaterState

startUpdate()                   (no start, display only)
  - downloadUpdate()
  - polls getUpdaterState() x60
  - applyUpdate()
  - sets: updateInProgress

RobotManager
────────────────────────
checkUpdateForRobot(id)         ← THIRD instance
  - getUpdaterState()
  - sets: robotUpdateAvailable[id]
```

Three separate code paths query the updater. `RobotDetailViewModel.startUpdate()` has no re-entrancy guard. `updateInProgress = true` is set but never guarded against concurrent calls. The apply phase sets `updateInProgress` and stays there — no error path resets it reliably.

### Valetudo Server-Side State Machine (Confirmed from Source)

The Valetudo updater exposes these `__class` values from `GET /api/v2/updater/state`:

```
ValetudoUpdaterIdleState
ValetudoUpdaterDisabledState
ValetudoUpdaterErrorState            ← has .type and .message fields
ValetudoUpdaterNoUpdateRequiredState
ValetudoUpdaterApprovalPendingState  ← isUpdateAvailable: true
ValetudoUpdaterDownloadingState      ← isDownloading: true
ValetudoUpdaterApplyPendingState     ← isReadyToApply: true
```

Transitions triggered by POST to `/api/v2/updater`:
- `{"action": "check"}` → Idle/Error/NoUpdateRequired → ApprovalPending (if update found)
- `{"action": "download"}` → ApprovalPending → Downloading → ApplyPending
- `{"action": "apply"}` → ApplyPending → robot reboots, goes offline

The server state machine is authoritative. The client state machine mirrors it and adds client-side phases (Checking, Error) that are not yet modeled in the app.

## Standard Architecture

### System Overview (Target State after v2.0.0)

```
┌──────────────────────────────────────────────────────────────────────┐
│                        View Layer                                     │
│                                                                       │
│  ┌──────────────────────────┐  ┌──────────────────────────────────┐  │
│  │ RobotDetailView          │  │ ValetudoInfoView (display only)  │  │
│  │ - shows UpdateBannerView │  │ - reads from RobotManager        │  │
│  │ - no update logic        │  │ - no update logic, no github     │  │
│  └────────────┬─────────────┘  └──────────────────────────────────┘  │
│               │ @StateObject                                          │
├───────────────┴───────────────────────────────────────────────────────┤
│                        ViewModel Layer                                 │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────────┐ │
│  │ RobotDetailViewModel                                             │ │
│  │ - @Published updatePhase: UpdatePhase                            │ │
│  │ - delegates startUpdate() → RobotManager.updateService          │ │
│  │ - reads updateService.phase for banner display                   │ │
│  └────────────────────────────┬─────────────────────────────────────┘ │
├────────────────────────────────┼──────────────────────────────────────┤
│                        Service Layer                                   │
│                                                                        │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │ UpdateService (NEW — @MainActor class, ObservableObject)       │   │
│  │                                                                │   │
│  │  @Published phase: UpdatePhase                                 │   │
│  │  @Published error: UpdateError?                                │   │
│  │                                                                │   │
│  │  func startUpdate()   — guarded, single active task           │   │
│  │  func checkForUpdate() — throttled, single entry point        │   │
│  │  func dismissError()                                           │   │
│  └───────────────────────────┬────────────────────────────────────┘   │
│                               │                                        │
│  ┌────────────────────────────┴───────────────────────────────────┐   │
│  │ RobotManager (@MainActor ObservableObject)                     │   │
│  │                                                                │   │
│  │  updateServices: [UUID: UpdateService]  (per-robot)           │   │
│  │  robotUpdateAvailable[UUID] — fed from UpdateService.phase    │   │
│  │                                                                │   │
│  │  checkUpdateForRobot(id) → delegates to UpdateService         │   │
│  └────────────────────────────┬───────────────────────────────────┘   │
│                               │                                        │
│  ┌────────────────────────────┴───────────────────────────────────┐   │
│  │ ValetudoAPI (actor)                                            │   │
│  │  getUpdaterState(), checkForUpdates(),                         │   │
│  │  downloadUpdate(), applyUpdate()  (unchanged)                  │   │
│  └────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Status | Responsibility | Integration Point |
|-----------|--------|---------------|------------------|
| `UpdateService` | NEW | Single source of truth for update lifecycle per robot. Owns state machine, re-entrancy guard, polling loop during download, error state. | Created by `RobotManager`, exposed to `RobotDetailViewModel` |
| `UpdatePhase` (enum) | NEW | Client-side state machine mirroring server states plus client phases. | Used by `UpdateService`, observed by `RobotDetailViewModel` and `UpdateBannerView` |
| `UpdateError` (struct) | NEW | Typed error with phase context and user-facing message. | Published by `UpdateService`, displayed by UI |
| `RobotDetailViewModel` | MODIFIED | Removes update logic. Reads `UpdateService.phase` for display. Delegates `startUpdate()` to service. | Holds reference to `UpdateService` via `RobotManager` |
| `RobotManager` | MODIFIED | Creates one `UpdateService` per robot. Removes `checkUpdateForRobot()` direct logic. Keeps `robotUpdateAvailable[UUID]` fed by observing `UpdateService`. | Owns `updateServices[UUID: UpdateService]` |
| `ValetudoInfoView` | MODIFIED | Removes `checkForUpdate()` duplicate. Removes GitHub API call. Reads updater state from `RobotManager` / `UpdateService`. | View-only, reads shared state |
| `UpdateBannerView` | NEW (optional) | Extracted UI component for update banners. Receives `UpdatePhase` and callbacks. | Used by `RobotDetailView` |
| `ValetudoAPI` | UNCHANGED | HTTP endpoints for updater. | Called only by `UpdateService` |

## Recommended Project Structure

```
ValetudoApp/ValetudoApp/
├── Models/
│   └── RobotState.swift          MODIFIED — add UpdatePhase enum, UpdateError struct
├── Services/
│   ├── ValetudoAPI.swift         UNCHANGED — updater endpoints already exist
│   ├── RobotManager.swift        MODIFIED — add updateServices dict, remove direct check logic
│   └── UpdateService.swift       NEW — the core addition of this milestone
├── ViewModels/
│   └── RobotDetailViewModel.swift  MODIFIED — remove update logic, read UpdateService
├── Views/
│   ├── RobotDetailView.swift       MODIFIED — reads UpdateService via ViewModel
│   ├── RobotSettingsSections.swift MODIFIED — ValetudoInfoView simplified
│   └── UpdateBannerView.swift      NEW (optional) — extracted banner component
└── Helpers/
    └── (no changes needed)
```

### Structure Rationale

- **UpdateService in Services/:** It is a stateful service with its own lifecycle (polling task, re-entrancy guard). Not a ViewModel concern. Follows the existing pattern of `RobotManager`, `SSEConnectionManager`.
- **UpdatePhase and UpdateError in Models/RobotState.swift:** They are domain model types used across layers. Keeping them in the existing `RobotState.swift` avoids a new file for a small addition. If the file grows, extract to `UpdaterState.swift`.
- **UpdateBannerView is optional:** The banner can stay inline in `RobotDetailView` if extraction adds complexity without benefit. Extract only if the banner logic exceeds ~80 lines.

## Architectural Patterns

### Pattern 1: Dedicated UpdateService per Robot

**What:** A `@MainActor final class UpdateService: ObservableObject` is created once per robot by `RobotManager`. It owns all update logic: state machine, re-entrancy guard, polling loop, error state. ViewModels read its `@Published` properties.

**When to use:** When a domain concern (here: update lifecycle) needs its own state, its own async task, and must be observed by multiple UI consumers.

**Trade-offs:** Adds one class. Eliminates three duplicate code paths. Enables independent testability. The service is scoped per-robot (not a singleton) because update state is per-robot.

**Why not extend RobotDetailViewModel:** The ViewModel is destroyed when the view disappears. A download in progress must survive navigation away. `RobotManager` persists for the app lifetime — its children do too. If the user navigates away during download, the `UpdateService` keeps polling and the next time `RobotDetailView` appears, it reads the current phase.

**Why not extend RobotManager directly:** Update logic would bloat `RobotManager` further. Extracting it keeps concerns separated and follows the same pattern as `SSEConnectionManager` (complex per-robot lifecycle → own type).

**Example:**
```swift
// Services/UpdateService.swift
@MainActor
final class UpdateService: ObservableObject {
    @Published private(set) var phase: UpdatePhase = .idle
    @Published private(set) var error: UpdateError?

    private let api: ValetudoAPI
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "UpdateService")
    private var activeTask: Task<Void, Never>?
    private var lastCheckDate: Date?

    init(api: ValetudoAPI) {
        self.api = api
    }

    func checkForUpdate(force: Bool = false) async {
        // Throttle: skip if checked within last 30 minutes (unless forced)
        if !force, let last = lastCheckDate, Date().timeIntervalSince(last) < 1800 { return }
        // Skip if already in a non-idle phase that still has meaning
        guard phase == .idle || phase == .noUpdateAvailable || phase == .error(nil) else { return }
        phase = .checking
        lastCheckDate = Date()
        do {
            try await api.checkForUpdates()
            let state = try await api.getUpdaterState()
            phase = UpdatePhase(from: state)
        } catch {
            phase = .error(UpdateError(phase: .checking, underlying: error))
        }
    }

    func startUpdate() async {
        // Re-entrancy guard: only one active task
        guard activeTask == nil else { return }
        guard case .approvalPending = phase else { return }

        activeTask = Task {
            defer { activeTask = nil }
            do {
                phase = .downloading(progress: nil)
                try await api.downloadUpdate()
                // Poll for completion
                for _ in 0..<60 {
                    try? await Task.sleep(for: .seconds(5))
                    if Task.isCancelled { return }
                    let state = try await api.getUpdaterState()
                    phase = UpdatePhase(from: state)
                    if state.isReadyToApply { break }
                    if !state.isDownloading { return } // unexpected state, abort
                }
                guard case .applyPending = phase else { return }
                try await api.applyUpdate()
                phase = .applying
                // Robot goes offline. Phase stays at .applying until next checkForUpdate
            } catch {
                phase = .error(UpdateError(phase: phase, underlying: error))
            }
        }
        await activeTask?.value
    }

    func applyDownloaded() async {
        guard case .applyPending = phase else { return }
        guard activeTask == nil else { return }
        activeTask = Task {
            defer { activeTask = nil }
            do {
                try await api.applyUpdate()
                phase = .applying
            } catch {
                phase = .error(UpdateError(phase: .applyPending, underlying: error))
            }
        }
        await activeTask?.value
    }

    func dismissError() {
        guard case .error = phase else { return }
        phase = .idle
        error = nil
    }
}
```

### Pattern 2: UpdatePhase Enum as Client State Machine

**What:** A Swift enum with associated values that maps server `__class` strings to a richer client model. Adds client-only phases (`checking`, `applying`, `error`) not present in the server state machine.

**When to use:** Whenever the UI needs to distinguish multiple states with different display requirements. Enum exhaustiveness guarantees all states are handled.

**Trade-offs:** Associated values add switch complexity. The benefit is compile-time completeness: adding a new server state requires handling it in every switch.

**Example:**
```swift
// Models/RobotState.swift — addition
enum UpdatePhase: Equatable {
    case idle                          // ValetudoUpdaterIdleState or disabled
    case noUpdateAvailable             // ValetudoUpdaterNoUpdateRequiredState
    case checking                      // client-only: checkForUpdates() in flight
    case approvalPending(version: String)  // ValetudoUpdaterApprovalPendingState
    case downloading(progress: Double?)    // ValetudoUpdaterDownloadingState
    case applyPending                  // ValetudoUpdaterApplyPendingState
    case applying                      // client-only: after applyUpdate() called
    case error(UpdateError?)           // ValetudoUpdaterErrorState or network error

    init(from state: UpdaterState) {
        switch state.stateType {
        case "ValetudoUpdaterIdleState":          self = .idle
        case "ValetudoUpdaterDisabledState":      self = .idle
        case "ValetudoUpdaterNoUpdateRequiredState": self = .noUpdateAvailable
        case "ValetudoUpdaterApprovalPendingState":
            self = .approvalPending(version: state.version ?? "")
        case "ValetudoUpdaterDownloadingState":
            let progress: Double? = {
                guard let c = state.metaData?.progress?.current,
                      let t = state.metaData?.progress?.total, t > 0
                else { return nil }
                return Double(c) / Double(t)
            }()
            self = .downloading(progress: progress)
        case "ValetudoUpdaterApplyPendingState":  self = .applyPending
        case "ValetudoUpdaterErrorState":
            self = .error(UpdateError(phase: .idle, serverMessage: state.currentVersion))
        default:                                  self = .idle
        }
    }

    var isUpdateAvailable: Bool {
        if case .approvalPending = self { return true }
        return false
    }
}

struct UpdateError: Equatable {
    let phase: UpdatePhase
    let underlying: Error?
    let serverMessage: String?

    init(phase: UpdatePhase, underlying: Error? = nil, serverMessage: String? = nil) {
        self.phase = phase
        self.underlying = underlying
        self.serverMessage = serverMessage
    }

    var userMessage: String {
        if let msg = serverMessage, !msg.isEmpty { return msg }
        return underlying?.localizedDescription ?? String(localized: "update.error.unknown")
    }

    static func == (lhs: UpdateError, rhs: UpdateError) -> Bool {
        lhs.serverMessage == rhs.serverMessage
    }
}
```

### Pattern 3: UI Lock for Apply Phase via View Modifier

**What:** A `fullScreenCover` or `interactiveDismissDisabled` modifier applied to `RobotDetailView` when `updatePhase == .applying`. This prevents navigation away during the apply phase. The cover is non-dismissable.

**When to use:** Specifically for the `applying` phase after `applyUpdate()` is called. The robot will reboot and go offline — navigating away is misleading.

**Trade-offs:** `fullScreenCover` is the strongest lock. Alternatively, disable the back button and tab bar. The `fullScreenCover` approach is simpler and more obvious to the user.

**Example:**
```swift
// In RobotDetailView.body
.fullScreenCover(isPresented: .constant(viewModel.updatePhase == .applying)) {
    UpdateApplyingScreen() // non-dismissable progress view
}

// UpdateApplyingScreen — no dismiss button, explains robot will reboot
struct UpdateApplyingScreen: View {
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            Text(String(localized: "update.applying.title"))
                .font(.title2).fontWeight(.semibold)
            Text(String(localized: "update.applying.hint"))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .interactiveDismissDisabled(true)
    }
}
```

### Pattern 4: RobotDetailViewModel Delegates to UpdateService

**What:** `RobotDetailViewModel` holds a reference to `UpdateService` (retrieved from `RobotManager`). It exposes the phase as a computed property and calls through to the service. No update logic lives in the ViewModel.

**When to use:** This pattern is the consolidation step. The ViewModel is thin — it aggregates multiple services and coordinates UI-layer concerns only.

**Example:**
```swift
// ViewModels/RobotDetailViewModel.swift
var updatePhase: UpdatePhase {
    robotManager.updateService(for: robot.id)?.phase ?? .idle
}

func startUpdate() async {
    await robotManager.updateService(for: robot.id)?.startUpdate()
}

func applyDownloadedUpdate() async {
    await robotManager.updateService(for: robot.id)?.applyDownloaded()
}
```

### Pattern 5: Intelligent Check Throttling

**What:** `UpdateService.checkForUpdate()` records `lastCheckDate` and skips the check if called within 30 minutes. Called on view appear only if in `.idle` or `.noUpdateAvailable` phase. `RobotManager.checkUpdateForRobot()` routes through `UpdateService`.

**When to use:** Replaces the current pattern where `checkForUpdate()` fires on every `loadData()` call (which fires every `task {}` — i.e., every view appear). On multi-robot setups, this creates unnecessary network traffic.

**Trade-offs:** 30 minutes means update availability shows up to 30 minutes late. Acceptable given the use case (manual firmware updates). Add `force: true` parameter for pull-to-refresh.

## Data Flow

### Update Lifecycle Flow (new)

```
User taps "Install Update" in RobotDetailView
    ↓
RobotDetailView → viewModel.startUpdate()
    ↓
RobotDetailViewModel → updateService.startUpdate()
    ↓
UpdateService (re-entrancy guard — aborts if activeTask != nil)
    ↓
UpdateService.phase = .downloading(progress: nil)
    ↓  POST /api/v2/updater {"action": "download"}
    ↓  polling loop: GET /api/v2/updater/state every 5s
    ↓  UpdateService.phase = .downloading(progress: 0.42) etc.
    ↓
UpdateService.phase = .applyPending  (server: ValetudoUpdaterApplyPendingState)
    ↓  POST /api/v2/updater {"action": "apply"}
    ↓
UpdateService.phase = .applying
    ↓
RobotDetailView shows fullScreenCover (non-dismissable)
    ↓
Robot reboots, goes offline
    ↓
RobotManager detects offline → UpdateService.phase stays .applying
    ↓
Robot comes back online
    ↓
Next checkForUpdate() (on view appear or manual refresh)
    ↓
Server returns ValetudoUpdaterIdleState (or NoUpdateRequired)
    ↓
UpdateService.phase = .idle / .noUpdateAvailable
    ↓
fullScreenCover dismissed automatically
```

### State Observation Flow

```
UpdateService.@Published phase
    ↓ observed by
RobotManager (feeds robotUpdateAvailable[UUID])
    ↓
RobotListView (badge display)

UpdateService.@Published phase
    ↓ observed by
RobotDetailViewModel (computed var updatePhase)
    ↓
RobotDetailView (banner, fullScreenCover trigger)
```

### Check Throttling Flow

```
RobotDetailView.task {} appears
    ↓
viewModel.loadData()
    ↓ calls
updateService.checkForUpdate(force: false)
    ↓
if lastCheckDate within 30 min AND phase not .idle → SKIP
    ↓ otherwise
phase = .checking
    ↓ POST /updater {"action": "check"}, GET /updater/state
    ↓
phase = UpdatePhase(from: serverState)
```

## Build Order and Dependencies

This milestone has clear dependency layers. Build sequentially — each step is testable before the next.

### Step 1 — Model Types (no dependencies)

Add `UpdatePhase` enum and `UpdateError` struct to `Models/RobotState.swift`.

- Depends on: nothing
- Enables: all subsequent steps
- Risk: LOW — pure Swift types, no async

### Step 2 — UpdateService (depends on Step 1 + existing ValetudoAPI)

Create `Services/UpdateService.swift` with full state machine, re-entrancy guard, throttling, polling loop.

- Depends on: `UpdatePhase`, `UpdateError`, `ValetudoAPI` (unchanged)
- Enables: Steps 3 and 4
- Risk: MEDIUM — async polling logic, test carefully

### Step 3 — RobotManager integration (depends on Step 2)

- Add `updateServices: [UUID: UpdateService]` dictionary
- Create `UpdateService` in `addRobot()`, remove in `removeRobot()`
- Replace `checkUpdateForRobot()` body with delegation to `UpdateService`
- Feed `robotUpdateAvailable[id]` from `UpdateService.phase.isUpdateAvailable`

- Depends on: `UpdateService`
- Risk: LOW — mostly mechanical wiring

### Step 4 — RobotDetailViewModel cleanup (depends on Step 3)

- Remove `checkForUpdate()`, `startUpdate()` methods
- Remove `currentVersion`, `latestVersion`, `updateUrl`, `isUpdating`, `updateInProgress` `@Published` properties
- Remove `updaterState: UpdaterState?` (phase is now the source of truth)
- Add computed `updatePhase: UpdatePhase` reading from service
- Add delegating `startUpdate()` and `applyDownloadedUpdate()`

- Depends on: RobotManager having `UpdateService`
- Risk: LOW — deletion + thin wrappers

### Step 5 — RobotDetailView UI (depends on Step 4)

- Replace banner logic with switch on `viewModel.updatePhase`
- Add `fullScreenCover` for `.applying` phase
- Remove `@State var showUpdateWarning` (fold into phase-driven logic if possible, or keep alert but drive from phase)
- Remove `@State var updateInProgress` (now comes from ViewModel)

- Depends on: Updated ViewModel
- Risk: LOW-MEDIUM — UI refactor, visually testable

### Step 6 — ValetudoInfoView deduplication (depends on Step 3)

- Remove `checkForUpdate()` method and `@State private var updaterState` / `latestRelease`
- Read update availability from `RobotManager.updateService(for:)?.phase`
- Keep version/host info display (unchanged)

- Depends on: RobotManager having UpdateService
- Risk: LOW — mostly deletion

### Dependency Graph

```
UpdatePhase + UpdateError (Step 1)
        ↓
UpdateService (Step 2)
        ↓
RobotManager integration (Step 3)
        ↓                    ↓
RobotDetailViewModel (Step 4)    ValetudoInfoView (Step 6)
        ↓
RobotDetailView UI (Step 5)
```

## Integration Points

### New vs. Modified Components

| Component | Change | Key Integration |
|-----------|--------|----------------|
| `UpdateService` | NEW | Created by `RobotManager.addRobot()`, accessed via `RobotManager.updateService(for:)` |
| `UpdatePhase` | NEW | Used by `UpdateService`, `RobotDetailViewModel`, `RobotDetailView`, `ValetudoInfoView` |
| `UpdateError` | NEW | Published by `UpdateService`, displayed in UI |
| `RobotManager` | MODIFIED | Add `updateServices[UUID: UpdateService]`, delegate check logic |
| `RobotDetailViewModel` | MODIFIED | Remove update logic, add delegating methods, remove 5 `@Published` properties |
| `RobotDetailView` | MODIFIED | Add `fullScreenCover` for `.applying`, simplify banner switch |
| `ValetudoInfoView` | MODIFIED | Remove duplicate check logic, read from shared service |
| `ValetudoAPI` | UNCHANGED | All 4 updater endpoints already exist and are correctly implemented |

### What Does NOT Change

- `ValetudoAPI` — no changes needed. All 4 updater endpoints exist.
- `RobotManager.robotUpdateAvailable[UUID]` — kept for backward compat with `RobotListView`. Fed by `UpdateService` instead of `checkUpdateForRobot()`.
- `UpdaterState` Codable model — kept as the raw API decode type. `UpdatePhase` is derived from it.
- `GitHubRelease` model — can be removed from `RobotDetailViewModel`. If `ValetudoInfoView` still shows GitHub link, keep the model but fetch only in the view (display-only concern).
- All other ViewModels and Views — no changes.

### Navigation Lock Mechanism

The apply phase requires preventing navigation. Two options:

**Option A — fullScreenCover (recommended):** Covers the entire screen including tab bar and navigation bar. Non-dismissable via `interactiveDismissDisabled(true)`. Clear UX: user sees a dedicated screen explaining the reboot.

**Option B — Disable back button + tab bar:** More surgical but harder to implement reliably in SwiftUI (no direct API for disabling NavigationStack back button). Requires toolbar item override. Fragile.

Recommendation: Option A. The fullScreenCover communicates clearly that something significant is happening. It disappears automatically when `updatePhase` leaves `.applying`.

### Error State Recovery Path

```
Error occurs during download/apply
    ↓
UpdateService.phase = .error(UpdateError(...))
    ↓
RobotDetailView shows error banner with:
  - error message
  - "Retry" button → calls checkForUpdate(force: true)
  - "Dismiss" button → calls dismissError()
    ↓
dismissError() → phase = .idle
User can then re-trigger check manually
```

## Anti-Patterns

### Anti-Pattern 1: Keeping Update Logic in RobotDetailViewModel

**What people do:** Add guards and re-entrancy checks directly to `startUpdate()` in the ViewModel.

**Why it's wrong:** The ViewModel is tied to the view's lifetime. If the user navigates away during a 5-minute firmware download, the ViewModel is destroyed, the Task is cancelled, and the download stops. The next time the user opens the detail view, there is no feedback that a download was in progress.

**Do this instead:** `UpdateService` is owned by `RobotManager` which lives for the app lifetime. Download survives navigation.

### Anti-Pattern 2: Modeling Update State as Multiple Boolean @Published Properties

**What people do:** `isUpdating`, `updateInProgress`, `isDownloading`, `isApplying` as separate flags.

**Why it's wrong:** Multiple booleans can be in invalid combinations (e.g., `isUpdating=true` AND `isDownloading=false`). Handling every combination in the UI leads to bugs. Already present in current code: `isUpdating` and `updateInProgress` coexist.

**Do this instead:** Single `UpdatePhase` enum. One source of truth, compiler-enforced exhaustiveness in switch statements.

### Anti-Pattern 3: Fetching GitHub Releases in Multiple Places

**What people do:** Both `RobotDetailViewModel.checkForUpdate()` and `ValetudoInfoView.checkForUpdate()` call the GitHub API independently.

**Why it's wrong:** Two network requests to the same endpoint, potential rate limiting (GitHub API: 60 unauthenticated requests/hour per IP), and inconsistent results if one call succeeds and the other fails.

**Do this instead:** If the GitHub fallback is needed (robots without Valetudo updater), move it into `UpdateService`. One call, one result, shared. Alternatively, deprecate the GitHub fallback entirely — if the robot doesn't have a Valetudo updater, it's an old version and the user should update via SSH anyway.

### Anti-Pattern 4: Dismissable Apply-Phase UI

**What people do:** Show a dismissable alert or banner during the apply phase.

**Why it's wrong:** The user dismisses it, starts interacting with other robot features, and the app sends commands to a robot that is mid-reboot. This causes confusing error feedback.

**Do this instead:** `fullScreenCover` with `interactiveDismissDisabled(true)`. No way to dismiss until the robot comes back online.

### Anti-Pattern 5: Re-checking Update on Every View Appear

**What people do:** Call `checkForUpdate()` inside `loadData()` which is called from `.task {}` — firing on every view appear.

**Why it's wrong:** `POST /updater {"action": "check"}` triggers the Valetudo updater to actually check for updates (network call from robot to update server). Calling this on every view appear means the robot checks for updates multiple times per minute when the user is actively using the app.

**Do this instead:** Throttle to 30 minutes (with `force: true` for manual pull-to-refresh). Check only when `UpdateService` is in `.idle` or `.noUpdateAvailable` state.

## Sources

- Valetudo updater source (Updater.js): `https://github.com/Hypfer/Valetudo/blob/master/backend/lib/updater/Updater.js` — HIGH confidence (primary source for server state machine)
- Valetudo upgrading docs: `https://valetudo.cloud/pages/usage/upgrading.html` — MEDIUM confidence (confirms integrated updater concept)
- Existing codebase: `ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift` — HIGH confidence (direct analysis)
- Existing codebase: `ValetudoApp/ValetudoApp/Views/RobotSettingsSections.swift` (ValetudoInfoView) — HIGH confidence
- Existing codebase: `ValetudoApp/ValetudoApp/Services/RobotManager.swift` — HIGH confidence
- Existing codebase: `ValetudoApp/ValetudoApp/Models/RobotState.swift` (UpdaterState) — HIGH confidence
- SwiftUI fullScreenCover + interactiveDismissDisabled: Apple Developer Documentation — HIGH confidence

---
*Architecture research for: ValetudiOS v2.0.0 — Update Process Hardening*
*Researched: 2026-03-29*
