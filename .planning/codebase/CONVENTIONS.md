# Coding Conventions

**Analysis Date:** 2026-03-28

## Naming Patterns

**Files:**
- Views: PascalCase matching the primary struct name, suffixed with `View` (e.g., `RobotDetailView.swift`, `MapView.swift`, `ConsumablesView.swift`)
- Models: PascalCase matching the primary struct/enum (e.g., `RobotState.swift`, `RobotConfig.swift`, `RobotMap.swift`, `Timer.swift`, `Consumable.swift`)
- ViewModels: PascalCase with `ViewModel` suffix (e.g., `RobotDetailViewModel.swift`, `MapViewModel.swift`, `RobotSettingsViewModel.swift`)
- Services: PascalCase with descriptive suffix (e.g., `ValetudoAPI.swift`, `RobotManager.swift`, `NotificationService.swift`, `NetworkScanner.swift`)
- Helpers: PascalCase with `Helpers` suffix for enum-based utility namespaces (e.g., `PresetHelpers.swift`, `DebugConfig.swift`)
- Intents: PascalCase grouped by domain (e.g., `RobotIntents.swift` contains all Siri intents)
- Tests: `{SourceFileName}Tests.swift` pattern (e.g., `TimerTests.swift`, `ConsumableTests.swift`, `KeychainStoreTests.swift`)

**Types (structs, classes, enums):**
- PascalCase throughout: `RobotConfig`, `ValetudoAPI`, `MapEditMode`, `BasicAction`
- Request/Response DTOs append `Request`/`Response`: `BasicControlRequest`, `SpeakerVolumeResponse`, `EnabledResponse`
- Enums for caseless namespaces (utility containers): `enum DebugConfig`, `enum PresetHelpers`, `enum OperationModeHelpers`
- ViewModel classes: `RobotDetailViewModel`, `MapViewModel`, `RobotSettingsViewModel`
- Test classes: `final class TimerTests`, `final class ConsumableTests`, `final class KeychainStoreTests`

**Functions:**
- camelCase: `getRobotInfo()`, `cleanSegments(ids:iterations:)`, `checkConnection()`
- Getter methods prefixed with `get`: `getAPI(for:)`, `getCapabilities()`, `getConsumables()`
- Action methods use verb: `addRobot(_:)`, `removeRobot(_:)`, `startScan()`, `locate()`
- Boolean getters use `is`/`has` prefix in properties: `isOnline`, `hasManualControl`, `hasMissingAttachments`
- Test methods: `func test{Behavior}()` pattern (e.g., `testLocalToUtcRoundTrip()`, `testRemainingPercentWithPercentUnit()`)

**Variables/Properties:**
- camelCase: `robotStates`, `selectedSegments`, `isLoading`
- Private properties: `private var apis`, `private let storageKey`
- `@State` properties: camelCase with descriptive names: `@State private var showFullMap = false`
- `@Published` properties in ViewModels: `@Published var segments: [Segment] = []`
- UserDefaults keys: snake_case strings: `"valetudo_robots"`, `"goToPresets"`, `"notify_cleaning_complete"`
- AppStorage keys: snake_case strings: `@AppStorage("hasCompletedOnboarding")`

## Code Style

**Formatting:**
- No external formatter (no SwiftFormat, no SwiftLint config detected)
- 4-space indentation (Xcode default)
- Opening braces on same line as declaration
- Trailing closures used consistently

**Linting:**
- No SwiftLint or other linting tool configured
- Code style is maintained manually via Xcode defaults

**Type Annotations:**
- Use type inference where possible: `@State private var isLoading = false`
- Explicit types for complex declarations: `@Published var robotStates: [UUID: RobotStatus] = [:]`
- Always annotate function return types explicitly

**Access Control:**
- Explicit access modifiers used throughout
- Classes marked `final` when not intended for subclassing: `final class RobotDetailViewModel`, `final class ConsumableTests`
- `@MainActor` annotation on classes managing UI state and observable objects

## Import Organization

**Order:**
1. Apple frameworks: `Foundation`, `SwiftUI`, `UserNotifications`, `Network`
2. No third-party dependencies (zero external packages)

**Pattern:** Single import per line, no grouping comments. Most files import only `SwiftUI` or `Foundation`.

**Test Imports:**
```swift
import XCTest
@testable import ValetudoApp
```

## Architecture Patterns

**MVVM-lite with EnvironmentObject:**
- `RobotManager` is the primary ViewModel, injected via `.environmentObject(robotManager)` from `ValetudoApp.swift`
- Views access it via `@EnvironmentObject var robotManager: RobotManager`
- Lightweight ViewModels for specific views: `RobotDetailViewModel`, `MapViewModel`, `RobotSettingsViewModel`
- ViewModels use `@MainActor` annotation for thread-safe UI updates

**Actor for Thread-Safe API:**
- `ValetudoAPI` is declared as `actor` for thread-safe network operations
- All API methods are `async throws`

**Singleton for Services:**
- `NotificationService.shared` uses singleton pattern with `@MainActor` annotation
- `GoToPresetStore` uses `@MainActor class` with `@Published` properties

**Property Wrappers Used:**
- `@MainActor` on classes that publish to UI: `RobotManager`, `NetworkScanner`, `NotificationService`, ViewModels
- `@StateObject` for owned observable objects (only in app entry point)
- `@EnvironmentObject` for dependency injection across the view hierarchy
- `@AppStorage` for UserDefaults-backed preferences
- `@State` / `@Binding` for view-local state
- `@Published` for observable properties in managers/services/ViewModels

**ViewModel Pattern:**
- ViewModels use `@MainActor final class` annotation
- Organize state with MARK sections: `// MARK: - Identity`, `// MARK: - Data state`, `// MARK: - Computed properties`
- Heavy use of `@Published` properties for reactive state
- Contain async loading methods: `loadSegments() async`, `loadConsumables() async`
- Example: `RobotDetailViewModel` (80+ lines) coordinates robot state, segments, consumables, capabilities

## Error Handling

**API Error Pattern:**
- Custom `APIError` enum conforming to `LocalizedError` in `ValetudoAPI.swift`
- Cases: `.invalidURL`, `.networkError(Error)`, `.invalidResponse`, `.httpError(Int)`, `.decodingError(Error)`
- Each case provides `errorDescription` for user-facing messages

**Error Handling in Views:**
- `do/catch` blocks with silent failure for non-critical operations:
```swift
do {
    let updaterState = try await api.getUpdaterState()
    // update state
} catch {
    // Silently ignore - not all robots support this
}
```
- Critical failures update UI state (e.g., set `isOnline = false`)
- ErrorRouter pattern: `ErrorRouter` class manages current error and optional retry action

**Error Handling in Services:**
- `try?` for non-critical persistence operations: `try? JSONEncoder().encode(robots)`
- Silent catch blocks with comments explaining why silence is acceptable
- `print()` for debug-only error logging (no crash analytics)

## Logging

**Framework:** `print()` statements only (no structured logging framework)

**Patterns:**
- API debug logging with prefix: `print("[API DEBUG] \(method) \(url.absoluteString)")`
- Error logging: `print("Notification authorization failed: \(error)")`
- Network scanning: `print("Scanning subnet: \(subnet).x")`
- German comments acceptable for context-specific notes (e.g., `// completionHandler sofort aufrufen — Task laeuft im Hintergrund`)
- No log levels, no conditional logging, no production log suppression

## Localization

**Framework:** Swift `String(localized:)` macro with `Localizable.xcstrings`

**Pattern:**
- All user-visible strings use localization: `String(localized: "tab.robots")`
- Localization keys use dot-notation namespacing: `"status.idle"`, `"notification.cleaning_complete.title"`, `"settings.add_robot"`
- String interpolation in localized strings: `String(localized: "notification.cleaning_complete.body_with_area \(robotName) \(area)")`
- Section headers use bare keys: `Text("settings.robots")` (implicit localization)
- Siri intents use `LocalizedStringResource` directly with German strings: `"Roboter starten"`
- AppIntents table: `LocalizedStringResource("Roboter", table: "AppIntents")`

**Key Naming Convention:**
- `{feature}.{element}`: `"tab.robots"`, `"settings.version"`, `"map.title"`
- `{feature}.{sub}.{detail}`: `"notification.cleaning_complete.title"`
- Preset display names: `"fanspeed.off"`, `"water.medium"`, `"preset.high"`
- Time/day abbreviations: `"day.sun"`, `"day.mon"` (used in TimerTests via localized timer strings)

## Comments

**MARK Comments:**
- Extensively used to organize code sections: `// MARK: - Robot Management`, `// MARK: - State`, `// MARK: - Controls`
- Every major section in `ValetudoAPI.swift` has a MARK comment for each capability group
- Test files use MARK comments: `// MARK: - Helpers`, `// MARK: - Tests` or specific test category names
- Used in Views for section delineation: `// MARK: - Robots Section`, `// MARK: - About Section`

**Inline Comments:**
- Explain non-obvious logic: `// Area in cm² from CurrentStatisticsAttribute`
- Explain workarounds: `// API returns 1/0 as Int, handle both Bool and Int`
- Explain silent failures: `// Silently ignore - not all robots support this`
- Explain algorithm behavior in tests: `// Round-trip property: utcToLocal then localToUTC must return the original values.`

**Documentation Comments:**
- Triple-slash (`///`) for public APIs and complex functions
- Used on test helper methods: `/// Returns decompressed pixels - cached via MapLayerCache to avoid recomputation per frame.`
- Explain purpose and behavior, not implementation

## Function Design

**Size:** Functions are generally short (5-20 lines). API methods are typically 2-4 lines each.

**Parameters:**
- Use Swift labeled parameters: `func cleanSegments(ids: [String], iterations: Int = 1)`
- Default parameter values where sensible: `method: String = "GET"`, `iterations: Int = 1`
- Use `for` external parameter label: `func getAPI(for id: UUID)`
- Test helper parameters with defaults: `makeConsumable(type: String, subType: String? = nil, value: Int, unit: String)`

**Return Values:**
- API methods return decoded types directly: `func getRobotInfo() async throws -> RobotInfo`
- Void API methods use `requestVoid` helper
- Boolean check methods return `Bool`: `func checkConnection() async -> Bool`
- Tuple returns for related values: `(hour: Int, minute: Int)` from time conversion functions
- Test assertions return Void

**Async/Await:**
- `async` methods standard in APIs and async loading in ViewModels
- `async throws` for API operations
- No completion handlers used (pure async/await)

## Module Design

**Exports:** No barrel files or module re-exports. Each file contains one primary type with related types.

**File Organization:**
- One primary struct/class per file with extensions and related types in same file
- `RobotState.swift` contains all API model types (818 lines) -- this is the largest model file
- `SettingsView.swift` contains `SettingsView`, `EditRobotView`, `ConnectionTestResult`, and `NotificationSettingsView`
- Request/response types co-located with their domain models
- Test files contain single test class with helpers

**Computed Properties:**
- Heavily used for derived state: `var batteryLevel: Int?`, `var statusValue: String?`
- Display helpers as computed properties: `var displayName: String`, `var formattedTime: String`
- View-local computed properties for status: `private var isCleaning: Bool`, `private var api: ValetudoAPI?`
- Model display properties: `var remainingPercent: Double`, `var iconColor: Color` in `Consumable`

**Extensions:**
- Extensions used heavily for organizing functionality by concern
- Display helpers grouped in extensions: `extension Consumable` for UI properties
- Localization helpers in separate extensions: `extension String` for consumable localization
- Each extension marked with MARK comment
- Location: extensions placed at end of file after main struct/class

## SwiftUI Conventions

**View Composition:**
- Views accept model objects as parameters: `let robot: RobotConfig`
- Use `@EnvironmentObject` for shared state, `@State` for local state
- Sheets presented via `.sheet(isPresented:)` or `.sheet(item:)`
- Navigation via `NavigationStack` with `NavigationLink`

**Preview Pattern:**
```swift
#Preview {
    ContentView()
        .environmentObject(RobotManager())
}
```

**Binding Pattern:**
- Custom bindings for complex state: `Binding(get: { ... }, set: { ... })`

**ViewModel Usage in Views:**
```swift
@EnvironmentObject var robotManager: RobotManager
@StateObject private var viewModel: RobotDetailViewModel

// Initialize with robot from parent
.onAppear {
    viewModel = RobotDetailViewModel(robot: robot, robotManager: robotManager)
}
```

---

*Convention analysis: 2026-03-28*
