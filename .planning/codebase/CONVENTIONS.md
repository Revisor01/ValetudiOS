# Coding Conventions

**Analysis Date:** 2026-04-04

## Naming Patterns

**Files:**
- PascalCase for all Swift files: `RobotDetailViewModel.swift`, `MapInteractiveView.swift`, `ValetudoAPI.swift`
- Test files suffix with `Tests`: `TimerTests.swift`, `KeychainStoreTests.swift`, `MapLayerTests.swift`
- Views named by feature + suffix: `RobotDetailView.swift`, `MapControlBarsView.swift`, `MapSheetsView.swift`
- Section extraction files use `Sections` suffix: `RobotDetailSections.swift`, `RobotSettingsSections.swift`

**Functions:**
- camelCase for all functions: `loadSegments()`, `refreshData()`, `cleanSelectedRooms()`
- Async functions explicitly marked `async`: `func loadData() async`, `func refreshRobot(_ id: UUID) async`
- Private helpers use `private func`: `private func loadSegments() async`
- Test functions: `test{Behavior}` pattern: `testLocalToUtcRoundTrip()`, `testCancelEditModeResetsState()`
- Factory functions: `make{Type}()` pattern in tests: `makeRobotConfig()`, `makeConsumable(type:subType:value:unit:)`

**Variables:**
- camelCase for all variables: `segments`, `consumables`, `isLoading`, `fanSpeedPresets`
- Boolean properties use `is`, `has` prefixes: `isLoading`, `isCleaning`, `hasZoneCleaning`, `hasConsumableWarning`
- Private backing fields with underscore: `_sseSession`
- `@ObservationIgnored` for non-reactive private state: `@ObservationIgnored private var refreshTask: Task<Void, Never>?`
- Collections default to empty: `var segments: [Segment] = []`, `var selectedSegmentIds: [String] = []`

**Types:**
- PascalCase for all types: `RobotDetailViewModel`, `MapEditMode`, `CleaningZone`
- Enums: PascalCase type name, camelCase cases: `enum MapEditMode { case none, zone, noGoArea }`
- Error enums: PascalCase with `Error` suffix: `enum APIError: LocalizedError`
- Request/response types named by purpose: `SegmentCleanRequest`, `EnabledResponse`, `PresetControlRequest`
- Helper enums as namespaces (caseless): `enum Constants { }`, `enum DebugConfig { }`, `enum PresetHelpers { }`

## Code Style

**Formatting:**
- 4-space indentation (Xcode default)
- Blank line between `// MARK: -` sections
- Trailing closures for SwiftUI modifiers and single-expression blocks
- No external linter (SwiftLint/SwiftFormat not used)

**Type Preferences:**
- Structs for data models: `RobotConfig`, `Consumable`, `MapLayer`, `Segment`
- Classes only when reference semantics needed: `MapLayerCache` (caching), `AppDelegate`
- `final class` for ViewModels: `final class RobotDetailViewModel`
- `actor` for thread-safe services: `actor ValetudoAPI`, `actor SSEConnectionManager`
- `enum` as namespace for static helpers: `enum PresetHelpers`, `enum Constants`

**MARK Sections:**
Use `// MARK: - SectionName` to organize code within files:
```swift
// MARK: - Configuration
// MARK: - Map Data State
// MARK: - Capabilities
// MARK: - Edit Mode State
// MARK: - Data Loading
// MARK: - Cleaning Actions
// MARK: - Persistence
```

## SwiftUI Patterns

**Observation Framework (Swift 5.9+):**
- Use `@Observable` macro (NOT `ObservableObject` / `@Published`):
```swift
@MainActor
@Observable
final class MapViewModel {
    var map: RobotMap?       // Automatically observed
    var segments: [Segment] = []
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
}
```
- Pass via `@Environment`: `.environment(robotManager)` in parent, `@Environment(RobotManager.self) var robotManager` in child
- Use `@State private var viewModel` in Views to own ViewModel lifecycle:
```swift
struct RobotDetailView: View {
    @State private var viewModel: RobotDetailViewModel
    init(robot: RobotConfig, robotManager: RobotManager) {
        _viewModel = State(initialValue: RobotDetailViewModel(robot: robot, robotManager: robotManager))
    }
}
```

**View Composition:**
- Extract sections into separate files when views exceed ~300 lines: `RobotDetailSections.swift`, `RobotSettingsSections.swift`
- Sheet views in dedicated file: `MapSheetsView.swift` contains `MapRenameSheet`, `SaveGoToPresetSheet`
- Control bars extracted: `MapControlBarsView.swift`
- Use `@ViewBuilder` for conditional subviews:
```swift
@ViewBuilder
private var tapTargetsOverlay: some View {
    GeometryReader { geometry in
        // ...
    }
}
```

**Canvas Rendering (Map):**
- Use SwiftUI `Canvas` for high-performance pixel-based map rendering (not SwiftUI shapes)
- `SpatialTapGesture` for hit-testing room selection on canvas
- `GeometryReader` for overlay positioning that needs size context
- `.overlay { }` blocks for SwiftUI elements layered on Canvas

**Localization:**
- Use `String(localized:)` for all user-facing strings: `String(localized: "tab.robots")`
- Interpolation: `String(localized: "rooms.rename_message \(segmentName)")`
- String catalog: `ValetudoApp/Resources/Localizable.xcstrings`
- Never use raw strings in UI; all labels must be localized

**Navigation:**
- `TabView` with `NavigationStack` per tab in `ContentView.swift`
- `NavigationStack` for drill-down navigation within features
- `.sheet()` for modal presentations (rename, presets, settings)
- `.presentationDetents([.medium])` for half-sheet modals

## Import Organization

**Order:**
1. `import Foundation` or `import SwiftUI` (primary framework first)
2. Other Apple frameworks: `import os`, `import Security`, `import BackgroundTasks`, `import UserNotifications`
3. No third-party dependencies (zero external packages)

**Test Imports:**
```swift
import XCTest
@testable import ValetudoApp
```

## Error Handling

**API Errors:**
```swift
enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .networkError(let error): return error.localizedDescription
        case .invalidResponse: return "Invalid response"
        case .httpError(let code): return "HTTP Error: \(code)"
        case .decodingError(let error): return "Decoding error: \(error.localizedDescription)"
        }
    }
}
```

**Error Routing (centralized alert):**
- `ErrorRouter` (`ValetudoApp/Helpers/ErrorRouter.swift`) uses `@Observable` and optional retry action
- Applied globally: `.withErrorAlert(router: errorRouter)` on root view
- ViewModels can call `errorRouter.show(error, retry: { ... })`

**ViewModel Error Handling:**
- `do/catch` blocks with logger output: `logger.error("Failed to load segments: \(error, privacy: .public)")`
- Non-critical failures silently logged (consumables, stats): `// Silently fail - not all robots support this`
- Guard early: `guard let api = api else { return }`
- Use `defer` for loading state cleanup: `defer { isLoading = false }`

**Graceful Degradation:**
- Offline fallback with map cache: load from `MapCacheService` when API fails
- Capability-gated features: check `capabilities.contains("...")` before showing UI
- `DebugConfig.showAllCapabilities` flag to force-show all features during development

## Logging

**Framework:** `os.Logger` (Apple Unified Logging)

**Logger Creation Pattern:**
```swift
private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "MapViewModel")
```

**Log Levels:**
- `logger.error()` - failures that affect functionality
- `logger.warning()` - recoverable issues, offline fallback
- `logger.debug()` - detailed operational info (API calls, state changes)
- `logger.info()` - significant events (SSE connect/disconnect)

**Privacy:**
- Always use `privacy: .public` for error messages: `\(error, privacy: .public)`
- Use `privacy: .private` for request bodies: `\(bodyString, privacy: .private)`
- IDs and coordinates use `privacy: .public` for debugging

## Comments

**MARK Sections:** Required for organizing code within files (see MARK Sections above)

**Documentation Comments:**
- `///` triple-slash for public API and complex logic
- Document "why" not "what": `/// Cache class for MapLayer pixel decompression. Using a class (reference type) allows caching on structs passed as let in SwiftUI Canvas closures`
- Inline comments for non-obvious logic: `// API returns 1/0 as Int, handle both Bool and Int`
- German comments acceptable for developer notes: `// Kein erfolgreicher Load - Cache laden falls vorhanden`

## Function Design

**Size:** Keep functions focused; extract helpers when logic exceeds ~30 lines

**Parameters:**
- Guard early with `guard let`: `guard let api = api else { return }`
- Use default parameters: `func cleanSegments(ids: [String], iterations: Int = 1, customOrder: Bool = false)`
- Tuples for grouped returns: `(hour: Int, minute: Int)`

**Async Patterns:**
- `async let` for parallel loading:
```swift
async let segmentsTask: () = loadSegments()
async let consumablesTask: () = loadConsumables()
_ = await (segmentsTask, consumablesTask)
```
- `Task { }` for fire-and-forget side effects
- `Task.sleep(for: .seconds(N))` for polling intervals
- Cancel management: store `Task` reference, call `.cancel()` in cleanup

**Ordered Collections:**
- Use `[String]` arrays (not `Set`) when order matters (room cleaning order)
- `selectedSegmentIds: [String]` preserves selection order
- Append-based selection: `selectedSegmentIds.append(id)` to track order

## Module Design

**Access Control:**
- Default internal visibility (no explicit `internal` keyword)
- `private` for implementation details
- `fileprivate` for file-scoped helpers: `fileprivate func computeDecompressedPixels()`
- `private(set)` for read-only published state: `private(set) var updateService: UpdateService?`
- `final` on all ViewModels to prevent subclassing

**Dependency Injection:**
- ViewModels accept dependencies via `init`: `init(robot: RobotConfig, robotManager: RobotManager)`
- Services use singleton pattern: `NotificationService.shared`, `MapCacheService.shared`, `BackgroundMonitorService.shared`
- `RobotManager` is the central state holder, passed via `@Environment`

**No Barrel Files:** Each type is imported directly via `@testable import ValetudoApp`

---

*Convention analysis: 2026-04-04*
