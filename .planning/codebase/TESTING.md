# Testing Patterns

**Analysis Date:** 2026-04-04

## Test Framework

**Runner:**
- XCTest (Apple built-in, no external test dependencies)
- Config: Xcode test target `ValetudoAppTests`

**Assertion Library:**
- XCTest built-in assertions

**Run Commands:**
```bash
# Run all tests
xcodebuild test -project ValetudoApp/ValetudoApp.xcodeproj -scheme ValetudoApp -destination 'platform=iOS Simulator,name=iPhone 16'

# Run specific test class
xcodebuild test -project ValetudoApp/ValetudoApp.xcodeproj -scheme ValetudoApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing ValetudoAppTests/TimerTests

# Run specific test method
xcodebuild test -project ValetudoApp/ValetudoApp.xcodeproj -scheme ValetudoApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing ValetudoAppTests/TimerTests/testLocalToUtcRoundTrip

# In Xcode: Cmd+U (all tests) or click diamond icon per test
```

## Test File Organization

**Location:** `ValetudoApp/ValetudoAppTests/` (separate from source)

**Naming:** `{SourceComponent}Tests.swift`

**Structure:**
```
ValetudoApp/ValetudoAppTests/
    ConsumableTests.swift          # 12 tests - Model: Consumable
    KeychainStoreTests.swift       #  6 tests - Service: KeychainStore
    MapLayerTests.swift            #  6 tests - Model: MapLayer decompression
    MapViewModelTests.swift        #  5 tests - ViewModel: MapViewModel
    RobotDetailViewModelTests.swift#  7 tests - ViewModel: RobotDetailViewModel
    RobotSettingsViewModelTests.swift# 4 tests - ViewModel: RobotSettingsViewModel
    TimerTests.swift               #  5 tests - Model: ValetudoTimer time conversion
    ValetudoAPITests.swift         # 12 tests - Service: API errors + JSON decoding
```

**Total: 57 tests across 8 files**

## Test Structure

**Suite Organization:**
```swift
import XCTest
@testable import ValetudoApp

final class ConsumableTests: XCTestCase {

    // MARK: - Helpers

    private func makeConsumable(type: String, subType: String? = nil, value: Int, unit: String) -> Consumable {
        let remaining = ConsumableRemaining(value: value, unit: unit)
        return Consumable(__class: nil, type: type, subType: subType, remaining: remaining)
    }

    // MARK: - remainingPercent

    func testRemainingPercentWithPercentUnit() {
        let consumable = makeConsumable(type: "brush", subType: "main", value: 75, unit: "percent")
        XCTAssertEqual(consumable.remainingPercent, 75.0, accuracy: 0.001)
    }

    // MARK: - iconColor

    func testIconColorGreen() {
        let consumable = makeConsumable(type: "brush", subType: "main", value: 75, unit: "percent")
        XCTAssertEqual(consumable.iconColor, .green)
    }
}
```

**Patterns:**
- `final class` for all test classes (no subclassing)
- `// MARK: - Helpers` section for factory functions
- `// MARK: - {Topic}` sections to group related tests
- Numbered test comments in ViewModel tests: `// MARK: - Test 1: Initialization default values`

## Mocking

**Framework:** None (no external mocking library)

**Current Approach:**
- Tests focus on pure functions, data models, and computed properties
- No network mocking - API tests verify JSON decoding only, not HTTP calls
- Real `KeychainStore` used with cleanup in `tearDown()`
- ViewModels tested with real `RobotManager()` instances (no API calls triggered)

**What to Mock (not yet implemented):**
- `ValetudoAPI` is an `actor` - could be abstracted behind a protocol for ViewModel tests
- `URLSession` for network-level testing (URLProtocol approach)
- `KeychainStore` via protocol for unit isolation

**What NOT to Mock:**
- Pure data model calculations (test directly)
- JSON decoding (test with inline JSON strings)
- Computed properties on ViewModels (set properties directly, check computed output)

## Fixtures and Factories

**Factory Functions (per test class):**

Model factories create objects directly:
```swift
// ConsumableTests.swift
private func makeConsumable(type: String, subType: String? = nil, value: Int, unit: String) -> Consumable {
    let remaining = ConsumableRemaining(value: value, unit: unit)
    return Consumable(__class: nil, type: type, subType: subType, remaining: remaining)
}
```

JSON-based factories for complex types:
```swift
// RobotDetailViewModelTests.swift
private func makeAttribute(json: String) throws -> RobotAttribute {
    let data = json.data(using: .utf8)!
    return try JSONDecoder().decode(RobotAttribute.self, from: data)
}

// MapLayerTests.swift
private func makeLayer(json: String) throws -> MapLayer {
    let data = json.data(using: .utf8)!
    return try JSONDecoder().decode(MapLayer.self, from: data)
}
```

ViewModel factory (shared across ViewModel tests):
```swift
// Used in MapViewModelTests, RobotDetailViewModelTests, RobotSettingsViewModelTests
private func makeRobotConfig() -> RobotConfig {
    RobotConfig(
        id: UUID(),
        name: "Test Robot",
        host: UUID().uuidString,  // Random host prevents state collision
        useSSL: false
    )
}
```

**Inline JSON for Decoding Tests:**
```swift
let json = #"{"type":"filter","subType":null,"remaining":{"value":85,"unit":"percent"}}"#
let data = Data(json.utf8)
let consumable = try JSONDecoder().decode(Consumable.self, from: data)
```

**Location:** All factory functions are `private` within each test class. No shared test utilities file.

## Coverage

**Requirements:** None enforced (no coverage thresholds configured)

**View Coverage:**
```bash
# Xcode: Product > Test (Cmd+U) then navigate to Report Navigator (Cmd+9)
```

## Test Types

**Unit Tests (all 57 tests):**
- Pure model logic: `ConsumableTests`, `TimerTests`, `MapLayerTests`
- JSON decoding: `ValetudoAPITests` (decoding subset)
- ViewModel state: `MapViewModelTests`, `RobotDetailViewModelTests`, `RobotSettingsViewModelTests`
- Secure storage: `KeychainStoreTests`

**Integration Tests:** Not present

**E2E Tests:** Not present

**UI Tests:** Not present (no XCUITest target)

## Common Patterns

**@MainActor Testing (ViewModels):**
All ViewModel tests require `@MainActor` because ViewModels are `@MainActor`:
```swift
@MainActor
func testInitializationDefaultValues() {
    let config = makeRobotConfig()
    let manager = RobotManager()
    let viewModel = MapViewModel(robot: config, robotManager: manager, isFullscreen: false)

    XCTAssertTrue(viewModel.isLoading)
    XCTAssertNil(viewModel.map)
    XCTAssertTrue(viewModel.segments.isEmpty)
}
```

**Conditional Skip for Debug Mode:**
Tests that depend on `DebugConfig.showAllCapabilities` being `false`:
```swift
@MainActor
func testCapabilityFlagsDefaultFalse() {
    guard !DebugConfig.showAllCapabilities else {
        return  // Skip in debug mode
    }
    let viewModel = RobotDetailViewModel(robot: makeRobotConfig(), robotManager: RobotManager())
    XCTAssertFalse(viewModel.hasCleanRoute)
}
```

**State-Dependent Computed Property Testing:**
Set ViewModel state directly, then assert computed properties:
```swift
@MainActor
func testStatusCleaningState() throws {
    let viewModel = RobotDetailViewModel(robot: makeRobotConfig(), robotManager: manager)
    let cleaningAttr = try makeAttribute(json: """
    {"__class":"StatusStateAttribute","value":"cleaning","flag":"none"}
    """)
    manager.robotStates[config.id] = RobotStatus(isOnline: true, attributes: [cleaningAttr])

    XCTAssertTrue(viewModel.isCleaning)
    XCTAssertTrue(viewModel.isRunning)
    XCTAssertFalse(viewModel.isPaused)
}
```

**Teardown Cleanup (Side Effects):**
```swift
private var testUUIDs: [UUID] = []

override func tearDown() {
    super.tearDown()
    for uuid in testUUIDs {
        KeychainStore.delete(for: uuid)
    }
    testUUIDs.removeAll()
}
```

**Round-Trip / Property-Based Testing:**
```swift
func testLocalToUtcRoundTrip() {
    let hours = [0, 1, 10, 12, 22, 23]
    let minutes = [0, 15, 30, 45, 59]
    for h in hours {
        for m in minutes {
            let local = ValetudoTimer.utcToLocal(hour: h, minute: m)
            let backToUtc = ValetudoTimer.localToUTC(hour: local.hour, minute: local.minute)
            XCTAssertEqual(backToUtc.hour, h, "Round-trip hour mismatch for \(h):\(m)")
        }
    }
}
```

**Error Testing:**
```swift
func testAPIErrorHTTPErrorDescription() {
    XCTAssertEqual(APIError.httpError(401).errorDescription, "HTTP Error: 401")
    XCTAssertEqual(APIError.httpError(500).errorDescription, "HTTP Error: 500")
}
```

**Floating-Point Assertions:**
```swift
XCTAssertEqual(consumable.remainingPercent, 50.0, accuracy: 0.001)
```

## Assertion Patterns

Use the following XCTest assertions:
- `XCTAssertEqual(_:_:)` - strict equality
- `XCTAssertEqual(_:_:accuracy:)` - floating-point tolerance
- `XCTAssertTrue(_:_:)` / `XCTAssertFalse(_:)` - boolean
- `XCTAssertNil(_:_:)` - nil check
- `XCTAssertGreaterThanOrEqual` / `XCTAssertLessThanOrEqual` / `XCTAssertLessThan` - range validation
- Always add descriptive messages for loop-based assertions: `"Round-trip hour mismatch for \(h):\(m)"`

## Test Coverage by Source File

| Source File | Test File | Tests | Coverage |
|---|---|---|---|
| `Models/Consumable.swift` | `ConsumableTests.swift` | 12 | remainingPercent, iconColor |
| `Models/Timer.swift` | `TimerTests.swift` | 5 | UTC/local conversion, round-trip, range |
| `Models/RobotMap.swift` | `MapLayerTests.swift` | 6 | Pixel decompression (RLE) |
| `Models/RobotState.swift` | `ValetudoAPITests.swift` | 3 | JSON decoding (partial) |
| `Services/ValetudoAPI.swift` | `ValetudoAPITests.swift` | 9 | Error types, URL construction, decoding |
| `Services/KeychainStore.swift` | `KeychainStoreTests.swift` | 6 | Save/retrieve/delete/overwrite |
| `ViewModels/MapViewModel.swift` | `MapViewModelTests.swift` | 5 | Init defaults, capabilities, edit mode |
| `ViewModels/RobotDetailViewModel.swift` | `RobotDetailViewModelTests.swift` | 7 | Init, capabilities, status, warnings |
| `ViewModels/RobotSettingsViewModel.swift` | `RobotSettingsViewModelTests.swift` | 4 | Init, capabilities, empty state |

## Test Coverage Gaps

**Untested Source Files (significant):**

| File | Lines | Risk | Priority |
|---|---|---|---|
| `Services/RobotManager.swift` | 360 | State lifecycle, SSE fallback, notifications | High |
| `Services/SSEConnectionManager.swift` | ~150 | Reconnect logic, stream parsing | Medium |
| `Services/NotificationService.swift` | ~200 | Notification scheduling, categories | Medium |
| `Services/BackgroundMonitorService.swift` | ~100 | Background refresh scheduling | Low |
| `Services/MapCacheService.swift` | ~80 | File I/O cache persistence | Medium |
| `Services/UpdateService.swift` | ~150 | Multi-phase update state machine | Medium |
| `Services/NetworkScanner.swift` | ~100 | Network discovery | Low |
| `Services/NWBrowserService.swift` | ~80 | Bonjour discovery | Low |
| `Intents/RobotIntents.swift` | ~100 | Siri/Shortcuts integration | Low |
| `Views/*` (24 files) | ~9100 | No UI tests | Low |
| `Models/RobotConfig.swift` | 44 | baseURL construction (partially tested via API tests) | Low |

**Untested Logic in Tested Files:**
- `ValetudoAPI`: No tests for actual HTTP requests (only decoding + error types)
- `MapViewModel`: No tests for `loadMap()`, `cleanSelectedRooms()`, `goToPoint()` (require API mock)
- `RobotDetailViewModel`: No tests for `loadData()`, `performAction()`, async data loading
- Room selection order (`selectedSegmentIds` as ordered array) not tested

## Adding New Tests

**New Test File:**
1. Create: `ValetudoApp/ValetudoAppTests/{Feature}Tests.swift`
2. Add to Xcode project target `ValetudoAppTests`
3. Follow this template:

```swift
import XCTest
@testable import ValetudoApp

final class {Feature}Tests: XCTestCase {

    // MARK: - Helpers

    private func makeRobotConfig() -> RobotConfig {
        RobotConfig(
            id: UUID(),
            name: "Test Robot",
            host: UUID().uuidString,
            useSSL: false
        )
    }

    // MARK: - Tests

    func testSomeBehavior() {
        // Arrange
        // Act
        // Assert
    }
}
```

**For ViewModel Tests:**
- Mark ALL test methods `@MainActor`
- Create `RobotManager()` for dependency
- Guard on `DebugConfig.showAllCapabilities` for capability-dependent tests
- Set state directly on ViewModel/Manager, then assert computed properties

**For Model Tests:**
- Use inline JSON with raw string literals: `#"{ ... }"#`
- Create `make{Type}()` factory functions
- Test edge cases: zero, boundary, overflow, nil
- Use `accuracy:` parameter for floating-point comparisons

**For Service Tests (if adding API mocking):**
- Extract protocol from `ValetudoAPI` actor
- Create `MockValetudoAPI` conforming to protocol
- Inject mock into ViewModel via init

---

*Testing analysis: 2026-04-04*
