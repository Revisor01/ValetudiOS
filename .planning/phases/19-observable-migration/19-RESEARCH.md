# Phase 19: Observable Migration - Research

**Researched:** 2026-04-01
**Domain:** Swift Observation framework — @Observable macro migration
**Confidence:** HIGH

## Summary

Phase 19 migrates all ObservableObject classes to the @Observable macro (iOS 17+, Swift 5.9+). The codebase has 11 ObservableObject classes. The migration is mechanical: remove `ObservableObject` conformance, remove `@Published` annotations, replace `@StateObject`/`@ObservedObject`/`@EnvironmentObject` call sites. There are zero Combine publishers or sinks in the codebase — the highest-risk migration pattern does not apply.

The critical technical finding: all existing classes already carry `@MainActor`. With Xcode 16+ (installed: Xcode 26.4), the SwiftUI `View` protocol itself is `@MainActor`, eliminating the initialization error that previously blocked `@State var vm = MyMainActorVM()` in Swift 5.9. This means the migration can use clean `@State` declarations without workarounds.

`NotificationService.robotManagerRef` is a `static weak var RobotManager?`. Weak references to `@Observable` classes work identically — no change needed beyond removing `ObservableObject` conformance.

**Primary recommendation:** Migrate in dependency order (leaf classes first, then composites). Keep `@MainActor` on all classes. Remove `@Published`. Replace `@StateObject`/`@ObservedObject` with `@State`/plain `var`. Replace `@EnvironmentObject` with `@Environment`. For `@Bindable` where binding is needed in environment consumers.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
All implementation choices are at Claude's discretion — pure infrastructure phase. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

### Claude's Discretion
All implementation choices.

### Deferred Ideas (OUT OF SCOPE)
None — infrastructure phase.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OBS-01 | Alle ViewModels migrieren von ObservableObject/@Published zu @Observable Macro | RobotDetailViewModel, RobotSettingsViewModel, MapViewModel — all @MainActor, zero Combine, clean migration |
| OBS-02 | RobotManager migriert zu @Observable | Already @MainActor, no Combine, weak ref pattern unaffected |
| OBS-03 | UpdateService migriert zu @Observable | Already @MainActor, private(set) properties become plain vars with same access pattern |
| OBS-04 | Alle @StateObject/@ObservedObject Referenzen werden durch @State/@Environment ersetzt | 8 @StateObject, 4 @ObservedObject, 15 @EnvironmentObject sites inventoried below |
</phase_requirements>

---

## Codebase Inventory

### ObservableObject Classes (11 total)

| Class | File | @MainActor | In scope (OBS) | Notes |
|-------|------|------------|----------------|-------|
| `RobotDetailViewModel` | ViewModels/ | Yes | OBS-01 | 17 @Published properties |
| `RobotSettingsViewModel` | ViewModels/ | Yes (implicit via @Published on main) | OBS-01 | ~45 @Published properties |
| `MapViewModel` | ViewModels/ | Yes | OBS-01 | ~35 @Published; owns GoToPresetStore |
| `RobotManager` | Services/ | Yes | OBS-02 | weak ref from NotificationService |
| `UpdateService` | Services/ | Yes | OBS-03 | private(set) @Published |
| `ErrorRouter` | Helpers/ | Yes | Adjacent | Small (1 property); used via .environmentObject |
| `GoToPresetStore` | Models/RobotState.swift | Yes | Adjacent | Nested in MapViewModel + passed as @ObservedObject |
| `NotificationService` | Services/ | Yes | Adjacent | Singleton; isAuthorized @Published |
| `SupportManager` | Services/ | Yes | Adjacent | Singleton; @ObservedObject in SupportView |
| `NetworkScanner` | Services/ | Yes | Adjacent | Short-lived; @StateObject in AddRobotView |
| `NWBrowserService` | Services/ | Yes | Adjacent | Owned by NetworkScanner; not observed directly by views |

**In-scope for this phase:** RobotDetailViewModel, RobotSettingsViewModel, MapViewModel, RobotManager, UpdateService.  
**Adjacent classes** share the same migration pattern; migrating them avoids mixed-style warnings and is low-risk.

### @StateObject Sites (8)

| File | Property | Migration |
|------|----------|-----------|
| `ValetudoApp.swift:44` | `@StateObject private var robotManager = RobotManager()` | `@State private var robotManager = RobotManager()` |
| `ValetudoApp.swift:45` | `@StateObject private var errorRouter = ErrorRouter()` | `@State private var errorRouter = ErrorRouter()` |
| `RobotDetailView.swift:4` | `@StateObject private var viewModel: RobotDetailViewModel` | `@State private var viewModel: RobotDetailViewModel` |
| `MapView.swift:185` | `@StateObject var viewModel: MapViewModel` | `@State var viewModel: MapViewModel` |
| `RobotSettingsView.swift:10` | `@StateObject private var viewModel: RobotSettingsViewModel` | `@State private var viewModel: RobotSettingsViewModel` |
| `AddRobotView.swift:6` | `@StateObject private var scanner = NetworkScanner()` | `@State private var scanner = NetworkScanner()` |
| `MapView.swift:205` (init) | `_viewModel = StateObject(wrappedValue: ...)` | `_viewModel = State(initialValue: ...)` |
| `RobotDetailView.swift:20` (init) | `_viewModel = StateObject(wrappedValue: ...)` | `_viewModel = State(initialValue: ...)` |

Note: `RobotSettingsView` and `MapContentView` both initialize viewModels via `init()`; those inits pass `wrappedValue` — same `State(initialValue:)` pattern applies.

### @ObservedObject Sites (4)

| File | Property | Migration |
|------|----------|-----------|
| `RobotDetailSections.swift:105` | `@ObservedObject var viewModel: RobotDetailViewModel` | Plain `var viewModel: RobotDetailViewModel` |
| `SettingsView.swift:5` | `@ObservedObject var notificationService = NotificationService.shared` | Plain `var notificationService = NotificationService.shared` (auto-tracked) |
| `SupportView.swift:5` | `@ObservedObject private var supportManager = SupportManager.shared` | Plain `var supportManager = SupportManager.shared` |
| `MapSheetsView.swift:97` | `@ObservedObject var presetStore: GoToPresetStore` | Plain `var presetStore: GoToPresetStore` |

Note: `GoToPresetsSheet` uses `presetStore.presets(for:)` and `presetStore.deletePreset()` — needs write access via `@Bindable var presetStore = presetStore` if bindings are used on presets. Check actual usage: `presetStore.deletePreset(robotPresets[index])` is a method call, not a binding, so plain `var` suffices.

### @EnvironmentObject Sites (15 references across 12 files)

All `@EnvironmentObject var robotManager: RobotManager` → `@Environment(RobotManager.self) var robotManager`  
All `@EnvironmentObject var errorRouter: ErrorRouter` → `@Environment(ErrorRouter.self) var errorRouter`  
All `.environmentObject(robotManager)` → `.environment(robotManager)`  
All `.environmentObject(errorRouter)` → `.environment(errorRouter)`

Files affected: ContentView, SettingsView, RobotListView, RobotSettingsSections (×5), MapView (×3), ManualControlView, DoNotDisturbView, AddRobotView, IntensityControlView, RobotSettingsView, TimersView (×2), StatisticsView, RoomsManagementView (×2), ConsumablesView, ValetudoApp.swift.

---

## Standard Stack

### Core (no new packages needed)

| Framework | Version | Purpose |
|-----------|---------|---------|
| Swift Observation | Built into Swift 5.9 / iOS 17+ | @Observable macro |
| SwiftUI | Built-in | @State, @Environment, @Bindable |

**No new dependencies.** The Observation framework ships with iOS 17 SDK. Project already targets iOS 17.0.

**Installation:** none — frameworks are already available.

---

## Architecture Patterns

### Pattern 1: Class-level migration

**Before:**
```swift
// ObservableObject pattern
@MainActor
class RobotManager: ObservableObject {
    @Published var robots: [RobotConfig] = []
    @Published var robotStates: [UUID: RobotStatus] = [:]
}
```

**After:**
```swift
// Observable pattern
@MainActor
@Observable
class RobotManager {
    var robots: [RobotConfig] = []
    var robotStates: [UUID: RobotStatus] = [:]
}
```

Rules:
- Remove `ObservableObject` conformance
- Remove all `@Published` annotations
- Add `@Observable` macro above `@MainActor`
- Keep `@MainActor` — it remains correct and important
- `private(set)` access modifiers on previously-`@Published private(set)` properties are preserved as-is

### Pattern 2: @StateObject → @State

**Before:**
```swift
struct RobotDetailView: View {
    @StateObject private var viewModel: RobotDetailViewModel

    init(robot: RobotConfig, robotManager: RobotManager) {
        _viewModel = StateObject(wrappedValue: RobotDetailViewModel(robot: robot, robotManager: robotManager))
    }
}
```

**After:**
```swift
struct RobotDetailView: View {
    @State private var viewModel: RobotDetailViewModel

    init(robot: RobotConfig, robotManager: RobotManager) {
        _viewModel = State(initialValue: RobotDetailViewModel(robot: robot, robotManager: robotManager))
    }
}
```

Note: With Xcode 16+, SwiftUI's `View` protocol is `@MainActor`, so `@State var vm = MyMainActorVM()` no longer produces "Call to main actor-isolated initializer in nonisolated context". This project uses Xcode 26.4 — the issue does not apply.

### Pattern 3: @ObservedObject → plain var

**Before:**
```swift
struct SomeSection: View {
    @ObservedObject var viewModel: RobotDetailViewModel
}
```

**After:**
```swift
struct SomeSection: View {
    var viewModel: RobotDetailViewModel
}
```

SwiftUI automatically tracks accessed properties of `@Observable` objects — no wrapper needed.

### Pattern 4: @EnvironmentObject → @Environment

**Before (injection site):**
```swift
ContentView()
    .environmentObject(robotManager)
    .environmentObject(errorRouter)
```

**After:**
```swift
ContentView()
    .environment(robotManager)
    .environment(errorRouter)
```

**Before (consumption site):**
```swift
struct ContentView: View {
    @EnvironmentObject var robotManager: RobotManager
    @EnvironmentObject var errorRouter: ErrorRouter
}
```

**After:**
```swift
struct ContentView: View {
    @Environment(RobotManager.self) var robotManager
    @Environment(ErrorRouter.self) var errorRouter
}
```

### Pattern 5: @Bindable for mutation through @Environment

When a view needs to create `Binding` values from an environment-passed observable (e.g., `$robotManager.someProperty`):

```swift
struct SomeView: View {
    @Environment(RobotManager.self) var robotManager

    var body: some View {
        @Bindable var robotManager = robotManager
        Toggle("...", isOn: $robotManager.someFlag)
    }
}
```

Scan shows no current bindings directly on `robotManager` or `errorRouter` in environment consumers — this pattern is noted for completeness but likely not needed in this codebase.

### Pattern 6: @ObservationIgnored for properties that must not trigger observation

```swift
@Observable
class MapViewModel {
    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?
}
```

Use for: `Task` properties, loggers, private API clients, and other non-UI state. All `private var` properties that don't drive view updates should be marked `@ObservationIgnored` to prevent unnecessary observation tracking overhead.

### Pattern 7: Nested @Observable (GoToPresetStore)

`GoToPresetStore` is both owned by `MapViewModel` as a plain property and passed to `GoToPresetsSheet` as `@ObservedObject`. After migration:

- `MapViewModel.presetStore` stays as plain `var presetStore = GoToPresetStore()` (auto-tracked)
- `GoToPresetsSheet` receives it as plain `var presetStore: GoToPresetStore` (auto-tracked)
- No `@Published` on `MapViewModel.presetStore` — just remove the annotation

### Anti-Patterns to Avoid

- **Keep `@Published` on only some properties:** All or nothing — `@Observable` tracks all stored properties unless `@ObservationIgnored` is used.
- **Using `.environmentObject()` with `@Observable` class:** This compiles but breaks — `.environment()` is required.
- **Mixing styles in the same class:** Don't half-migrate. If a class has `@Observable`, zero `@Published` annotations remain.
- **Removing `@MainActor`:** Keep `@MainActor` on all classes. It provides Swift Concurrency safety guarantees independent of the Observation framework.
- **Using `@Bindable` at declaration site for environment objects:** Declare with `@Environment`, then create `@Bindable` inside `body` if needed.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Fine-grained view updates | Custom didSet + objectWillChange.send() | @Observable macro tracks per-property access automatically |
| Thread-safe observation | Custom locks or DispatchQueue | @Observable uses internal mutex; @MainActor ensures main-thread mutations |
| Opt-out of tracking | Computed property tricks | `@ObservationIgnored` attribute |

**Key insight:** `@Observable` provides view-level granularity automatically — a view only re-renders when properties it actually *reads* change, vs `ObservableObject` which re-renders on any `@Published` change. This is a free performance improvement with no additional code.

---

## Common Pitfalls

### Pitfall 1: Forgetting @ObservationIgnored on private infrastructure properties

**What goes wrong:** `Task` properties, logger instances, API clients inside `@Observable` classes become observable. While harmless for correctness, it adds unnecessary tracking overhead and can cause subtle issues if an `@Observable` subtype is used as a property.

**How to avoid:** Mark `private var refreshTask`, `private let logger`, `private let api`, `private var apis: [UUID: ValetudoAPI]` with `@ObservationIgnored`.

**Warning signs:** Xcode compiler warnings about non-Sendable types in observation context.

### Pitfall 2: Missing .environment() injection after removing .environmentObject()

**What goes wrong:** Views using `@Environment(RobotManager.self)` crash at runtime with "No Observable of type RobotManager found" if the injection site still uses `.environmentObject()`.

**How to avoid:** Update injection sites (ValetudoApp.swift) and consumption sites atomically in the same plan.

### Pitfall 3: Forgetting to update init() wrappedValue syntax

**What goes wrong:** `_viewModel = StateObject(wrappedValue: ...)` does not compile after removing `@StateObject`.

**How to avoid:** Each `@StateObject` replaced by `@State` requires the init to change from `StateObject(wrappedValue:)` to `State(initialValue:)`.

### Pitfall 4: RobotDetailSections @ObservedObject

**What goes wrong:** `RobotDetailSections.swift` passes `viewModel: RobotDetailViewModel` as `@ObservedObject`. After `RobotDetailViewModel` becomes `@Observable`, the `@ObservedObject` annotation compiles but may generate deprecation warnings. Must be converted to plain `var`.

### Pitfall 5: SupportView and SettingsView initialize their observables at declaration site

**What goes wrong:** `@ObservedObject var notificationService = NotificationService.shared` and `@ObservedObject private var supportManager = SupportManager.shared` — when converted to plain `var`, SwiftUI still observes them because the class is `@Observable`. This is correct behavior, not a bug.

**Why it works:** With `@Observable`, SwiftUI tracks access automatically regardless of property wrapper.

### Pitfall 6: UpdateService private(set) @Published

**Before:** `@Published private(set) var phase: UpdatePhase = .idle`  
**After:** `private(set) var phase: UpdatePhase = .idle`

The `private(set)` access modifier is orthogonal to `@Published` — keep it, just remove `@Published`.

---

## Migration Order (Dependency Graph)

Migrate leaf classes first to avoid cascading changes:

```
Wave 1 (no ObservableObject dependencies):
  GoToPresetStore       (used by MapViewModel)
  ErrorRouter           (used by ValetudoApp + views)
  NotificationService   (singleton, used by RobotManager)
  SupportManager        (singleton, standalone)
  NWBrowserService      (owned by NetworkScanner)

Wave 2 (depend on Wave 1 or each other but not on ViewModels):
  NetworkScanner        (owns NWBrowserService)
  UpdateService         (standalone service)
  RobotManager          (uses NotificationService)

Wave 3 (depend on RobotManager + services):
  RobotDetailViewModel
  RobotSettingsViewModel
  MapViewModel

Wave 4 (view call sites):
  All @StateObject → @State
  All @ObservedObject → plain var
  All @EnvironmentObject → @Environment
  All .environmentObject() → .environment()
```

Wave 4 must happen atomically per-class — don't update injection without consumption or vice versa.

---

## Code Examples

### Minimal @Observable class (verified pattern — Apple docs + useyourloaf.com)

```swift
import Observation

@MainActor
@Observable
final class RobotDetailViewModel {
    var segments: [Segment] = []
    var isLoading = false

    @ObservationIgnored
    private let logger = Logger(...)

    @ObservationIgnored
    private var statsPollingTask: Task<Void, Never>?
}
```

### @State with custom init (verified pattern — useyourloaf.com + fatbobman.com)

```swift
struct RobotDetailView: View {
    @State private var viewModel: RobotDetailViewModel

    init(robot: RobotConfig, robotManager: RobotManager) {
        _viewModel = State(initialValue: RobotDetailViewModel(robot: robot, robotManager: robotManager))
    }
}
```

### Environment injection (verified — Apple docs)

```swift
// App.swift
ContentView()
    .environment(robotManager)
    .environment(errorRouter)

// ContentView.swift
@Environment(RobotManager.self) var robotManager
@Environment(ErrorRouter.self) var errorRouter
```

### withErrorAlert modifier update

`ErrorRouter` is passed to `.withErrorAlert(router: errorRouter)`. This extension takes `ErrorRouter` directly as a parameter (not via property wrapper) — no change needed to the extension itself. The view's property declaration changes from `@StateObject private var errorRouter` to `@State private var errorRouter`.

---

## State of the Art

| Old Approach | Current Approach | When Changed |
|--------------|------------------|--------------|
| `ObservableObject` + `@Published` | `@Observable` macro | iOS 17 / Swift 5.9 (WWDC 2023) |
| `@StateObject` for reference types | `@State` for reference types | iOS 17 |
| `@EnvironmentObject` | `@Environment(Type.self)` | iOS 17 |
| `@ObservedObject` in views | Plain `var` for `@Observable` types | iOS 17 |
| View protocol NOT @MainActor | View protocol IS @MainActor | Xcode 16 / iOS 18 (WWDC 2024) |

**Deprecated/outdated in this project's context:**
- `ObservableObject`: Replaced by `@Observable`. Still compiles, but new style is preferred.
- `@Published`: No-op with `@Observable`. Remove to avoid confusion.
- `Combine` imports used solely for `ObservableObject`: Not present in this codebase.

---

## Environment Availability

Step 2.6: SKIPPED — this is a pure code migration with no external tool dependencies.

---

## Open Questions

1. **`@ObservationIgnored` scope decision**
   - What we know: Private infrastructure properties (tasks, loggers, APIs) should be `@ObservationIgnored`
   - What's unclear: Whether `private let` constants (e.g., `let robot: RobotConfig`, `let api: ValetudoAPI`) also need it — `let` constants are never mutated so they won't trigger observation regardless
   - Recommendation: Only apply `@ObservationIgnored` to `var` properties that are infrastructure (Tasks, loggers, caches). `let` constants do not need it.

2. **`withErrorAlert` modifier and `@Observable` ErrorRouter**
   - What we know: The modifier takes `ErrorRouter` as a plain parameter and reads `router.currentError` and `router.retryAction`
   - What's unclear: Does the `Binding(get:set:)` inside the modifier observe correctly after migration?
   - Recommendation: The `Binding(get:set:)` closure pattern reads from the ErrorRouter directly — SwiftUI tracks these reads automatically with `@Observable`. No change to the modifier body needed.

---

## Sources

### Primary (HIGH confidence)
- [Apple Developer Docs — Migrating from ObservableObject to @Observable](https://developer.apple.com/documentation/SwiftUI/Migrating-from-the-observable-object-protocol-to-the-observable-macro) — migration steps, property wrapper replacements
- [Use Your Loaf — Migrating to Observable](https://useyourloaf.com/blog/migrating-to-observable/) — syntax changes, @Environment pattern, @Bindable
- [fatbobman.com — SwiftUI Views and @MainActor](https://fatbobman.com/en/posts/swiftui-views-and-mainactor/) — @StateObject vs @State with @MainActor, Xcode 16 View protocol change

### Secondary (MEDIUM confidence)
- [Jesse Squires — @Observable is not a drop-in replacement](https://www.jessesquires.com/blog/2024/09/09/swift-observable-macro/) — initialization behavior differences, memory pitfalls
- [Swift Forums — @Observable conflicting with @MainActor](https://forums.swift.org/t/observable-macro-conflicting-with-mainactor/67309) — root cause of init error, solutions
- [Jano.dev — The Observation Framework](https://jano.dev/apple/swiftui/2024/12/13/Observation-Framework.html) — @ObservationIgnored, thread-safety model
- [avanderlee.com — @Observable performance](https://www.avanderlee.com/swiftui/observable-macro-performance-increase-observableobject/) — per-property tracking behavior

### Codebase analysis (HIGH confidence — direct inspection)
- 11 ObservableObject classes identified via grep
- 8 @StateObject sites, 4 @ObservedObject sites, 15+ @EnvironmentObject sites
- Zero Combine publisher/sink usage confirmed
- All classes already carry @MainActor
- Xcode 26.4 confirmed installed (View protocol is @MainActor)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — iOS 17 SDK built-in, no new packages
- Architecture: HIGH — verified against official docs + codebase inspection
- Pitfalls: HIGH — identified via direct codebase grep + verified forum sources
- Migration order: HIGH — derived from actual class dependencies in codebase

**Research date:** 2026-04-01
**Valid until:** 2027-01-01 (stable framework, no expected breaking changes)
