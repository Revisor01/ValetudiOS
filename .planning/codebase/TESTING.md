# Testing Patterns

**Analysis Date:** 2026-03-28

## Test Framework

**Runner:** XCTest (built-in Apple framework)

**Configuration:**
- Test target: `ValetudoAppTests`
- Framework: XCTest (no external dependencies)
- Total: 57 unit tests across 8 test files

**Run Commands:**
```bash
# Run all tests
xcodebuild test -project ValetudoApp/ValetudoApp.xcodeproj -scheme ValetudoApp

# Run specific test class
xcodebuild test -project ValetudoApp/ValetudoApp.xcodeproj -scheme ValetudoApp \
  -only-testing ValetudoAppTests/TimerTests

# Run in Xcode (Cmd+U)
```

## Test File Organization

**Location:** `ValetudoApp/ValetudoAppTests/`

**Files (8 total):**

1. `TimerTests.swift` - Time conversion logic for UTC/local timezone handling
2. `ConsumableTests.swift` - Consumable state calculations (remaining percent, colors)
3. `KeychainStoreTests.swift` - Secure password storage and retrieval
4. `MapLayerTests.swift` - Map pixel decompression algorithm
5. `MapViewModelTests.swift` - MapViewModel initialization and state management
6. `RobotDetailViewModelTests.swift` - RobotDetailViewModel state and computed properties
7. `RobotSettingsViewModelTests.swift` - RobotSettingsViewModel initialization and capability flags
8. `ValetudoAPITests.swift` - API error handling and JSON decoding

**Naming Pattern:** `{SourceFileName}Tests.swift`
- `TimerTests.swift` → `ValetudoApp/Models/Timer.swift`
- `ConsumableTests.swift` → `ValetudoApp/Models/Consumable.swift`
- `MapViewModelTests.swift` → `ValetudoApp/ViewModels/MapViewModel.swift`
- `RobotDetailViewModelTests.swift` → `ValetudoApp/ViewModels/RobotDetailViewModel.swift`
- `RobotSettingsViewModelTests.swift` → `ValetudoApp/ViewModels/RobotSettingsViewModel.swift`

## Test Structure

**Class Pattern:**
```swift
import XCTest
@testable import ValetudoApp

final class TimerTests: XCTestCase {
    // MARK: - Helpers
    // Helper methods and setup

    // MARK: - Tests
    // Test methods
}
```

**Test Method Naming:** `test{Behavior}` or `test{Behavior}{Condition}`
- `testLocalToUtcRoundTrip()` - tests bidirectional conversion
- `testRemainingPercentWithPercentUnit()` - tests calculation with specific unit
- `testIconColorGreen()` - tests color output for specific value
- `testDeleteRemovesPassword()` - tests side effect of delete operation
- `testInitializationDefaults()` - tests initial state after construction
- `testCapabilityFlagsDefaultFalse()` - tests capability flags when unset

**Setup and Teardown Pattern:**

```swift
final class KeychainStoreTests: XCTestCase {
    private var testUUIDs: [UUID] = []

    override func tearDown() {
        super.tearDown()
        for uuid in testUUIDs {
            KeychainStore.delete(for: uuid)
        }
        testUUIDs.removeAll()
    }

    private func makeUUID() -> UUID {
        let uuid = UUID()
        testUUIDs.append(uuid)
        return uuid
    }
}
```

## Test Structure Examples

**Model Test Suite (TimerTests.swift):**
```swift
final class TimerTests: XCTestCase {

    /// Round-trip property: utcToLocal then localToUTC must return the original values.
    func testLocalToUtcRoundTrip() {
        let hours = [0, 1, 10, 12, 22, 23]
        let minutes = [0, 15, 30, 45, 59]
        for h in hours {
            for m in minutes {
                let local = ValetudoTimer.utcToLocal(hour: h, minute: m)
                let backToUtc = ValetudoTimer.localToUTC(hour: local.hour, minute: local.minute)
                XCTAssertEqual(backToUtc.hour, h, "Round-trip hour mismatch for \(h):\(m)")
                XCTAssertEqual(backToUtc.minute, m, "Round-trip minute mismatch for \(h):\(m)")
            }
        }
    }

    /// Output hour must always be in range [0, 23].
    func testUtcToLocalOutputRange() {
        for h in 0...23 {
            for m in [0, 30] {
                let result = ValetudoTimer.utcToLocal(hour: h, minute: m)
                XCTAssertGreaterThanOrEqual(result.hour, 0)
                XCTAssertLessThanOrEqual(result.hour, 23)
                XCTAssertGreaterThanOrEqual(result.minute, 0)
                XCTAssertLessThan(result.minute, 60)
            }
        }
    }
}
```

**ViewModel Test Suite (MapViewModelTests.swift):**
```swift
final class MapViewModelTests: XCTestCase {

    // MARK: - Helpers
    private func makeRobotConfig() -> RobotConfig {
        RobotConfig(
            id: UUID(),
            name: "Test Robot",
            host: UUID().uuidString,
            useSSL: false
        )
    }

    // MARK: - Test 1: Initialization default values
    @MainActor
    func testInitializationDefaultValues() {
        let config = makeRobotConfig()
        let manager = RobotManager()
        let viewModel = MapViewModel(robot: config, robotManager: manager, isFullscreen: false)

        XCTAssertTrue(viewModel.isLoading)
        XCTAssertNil(viewModel.map)
        XCTAssertTrue(viewModel.segments.isEmpty)
        XCTAssertEqual(viewModel.editMode, .none)
    }

    // MARK: - Test 3: cancelEditMode resets editMode and drawnZones
    @MainActor
    func testCancelEditModeResetsState() {
        let config = makeRobotConfig()
        let manager = RobotManager()
        let viewModel = MapViewModel(robot: config, robotManager: manager, isFullscreen: false)

        viewModel.editMode = .zone
        viewModel.drawnZones = [zone]
        viewModel.cancelEditMode()

        XCTAssertEqual(viewModel.editMode, .none)
        XCTAssertTrue(viewModel.drawnZones.isEmpty)
    }
}
```

**API Test Suite (ValetudoAPITests.swift):**
```swift
final class ValetudoAPITests: XCTestCase {

    // MARK: - APIError Tests
    func testAPIErrorInvalidURLDescription() {
        XCTAssertEqual(APIError.invalidURL.errorDescription, "Invalid URL")
    }

    func testAPIErrorHTTPErrorDescription() {
        XCTAssertEqual(APIError.httpError(401).errorDescription, "HTTP Error: 401")
    }

    // MARK: - JSON Decoding Tests
    func testDecodeCapabilities() throws {
        let json = #"["FanSpeedControlCapability","WaterUsageControlCapability"]"#
        let data = Data(json.utf8)
        let capabilities = try JSONDecoder().decode(Capabilities.self, from: data)
        XCTAssertEqual(capabilities.count, 2)
        XCTAssertTrue(capabilities.contains("FanSpeedControlCapability"))
    }

    func testDecodeConsumable() throws {
        let json = #"{"type":"filter","subType":null,"remaining":{"value":85,"unit":"percent"}}"#
        let data = Data(json.utf8)
        let consumable = try JSONDecoder().decode(Consumable.self, from: data)
        XCTAssertEqual(consumable.type, "filter")
        XCTAssertEqual(consumable.remaining.value, 85)
    }
}
```

## Test Data Patterns

**Factory Functions for Model Creation:**

From `ConsumableTests.swift`:
```swift
// MARK: - Helpers

private func makeConsumable(type: String, subType: String? = nil, value: Int, unit: String) -> Consumable {
    let remaining = ConsumableRemaining(value: value, unit: unit)
    return Consumable(__class: nil, type: type, subType: subType, remaining: remaining)
}
```

From `RobotDetailViewModelTests.swift`:
```swift
private func makeRobotConfig() -> RobotConfig {
    RobotConfig(
        id: UUID(),
        name: "Test Robot",
        host: UUID().uuidString,
        useSSL: false
    )
}

private func makeConsumable(json: String) throws -> Consumable {
    let data = json.data(using: .utf8)!
    return try JSONDecoder().decode(Consumable.self, from: data)
}
```

**Inline JSON for Decoding Tests:**

From `MapLayerTests.swift`:
```swift
func testDecompressSingleRun() throws {
    // [5, 10, 3] means: starting at (5, 10), draw 3 horizontal pixels
    let layer = try makeLayer(json: #"{"compressedPixels": [5, 10, 3]}"#)
    XCTAssertEqual(layer.decompressedPixels, [5, 10, 6, 10, 7, 10])
}

private func makeLayer(json: String) throws -> MapLayer {
    let data = json.data(using: .utf8)!
    return try JSONDecoder().decode(MapLayer.self, from: data)
}
```

**Cleanup and State Tracking:**

From `KeychainStoreTests.swift`:
```swift
private var testUUIDs: [UUID] = []

override func tearDown() {
    super.tearDown()
    for uuid in testUUIDs {
        KeychainStore.delete(for: uuid)
    }
    testUUIDs.removeAll()
}

func testSaveAndRetrieve() {
    let robotId = makeUUID()
    let saved = KeychainStore.save(password: "testPass123", for: robotId)
    XCTAssertTrue(saved, "save should return true on success")

    let retrieved = KeychainStore.password(for: robotId)
    XCTAssertEqual(retrieved, "testPass123")
}
```

## Assertion Patterns

**XCTest Assertions Used:**
- `XCTAssertEqual(_:_:accuracy:)` — equality with floating-point tolerance: `XCTAssertEqual(consumable.remainingPercent, 50.0, accuracy: 0.001)`
- `XCTAssertEqual(_:_:)` — strict equality: `XCTAssertEqual(backToUtc.hour, h)`
- `XCTAssertTrue(_:_:)` — boolean true with message: `XCTAssertTrue(saved, "save should return true")`
- `XCTAssertFalse(_:)` — boolean false: `XCTAssertFalse(viewModel.isLoading)`
- `XCTAssertNil(_:)` — nil assertion: `XCTAssertNil(retrieved)`
- `XCTAssertGreaterThanOrEqual(_:_:)` — range validation: `XCTAssertGreaterThanOrEqual(result.hour, 0)`
- `XCTAssertLessThanOrEqual(_:_:)` — range validation: `XCTAssertLessThanOrEqual(result.hour, 23)`
- `XCTAssertLessThan(_:_:)` — range validation: `XCTAssertLessThan(result.minute, 60)`

**Assertion with Messages:**
```swift
XCTAssertEqual(backToUtc.hour, h, "Round-trip hour mismatch for \(h):\(m)")
XCTAssertNil(retrieved, "password should be nil after delete")
```

## Test Coverage Details

**Total Tests:** 57 tests across 8 files

**1. TimerTests.swift (4 tests)**
- File: `ValetudoApp/ValetudoApp/Models/Timer.swift`
- Coverage: UTC/local time conversion, round-trip conversions, output range validation
- Key tests:
  - `testLocalToUtcRoundTrip()` - bidirectional conversion
  - `testUtcToLocalOutputRange()` - validates hour [0-23] and minute [0-59]
  - `testUtcToLocalAppliesOffset()` - timezone offset application

**2. ConsumableTests.swift (8 tests)**
- File: `ValetudoApp/ValetudoApp/Models/Consumable.swift`
- Coverage: Remaining percent calculation, icon color selection
- Key tests:
  - `testRemainingPercentWithPercentUnit()` - direct percent values
  - `testRemainingPercentWithMinutesSideBrush()` - type-specific max conversions
  - `testRemainingPercentCapsAt100()` - overflow handling
  - `testIconColorGreen()`, `testIconColorOrange()`, `testIconColorRed()` - color thresholds

**3. KeychainStoreTests.swift (6 tests)**
- File: `ValetudoApp/ValetudoApp/Keychain/KeychainStore.swift` (inferred)
- Coverage: Secure password storage, retrieval, deletion
- Key tests:
  - `testSaveAndRetrieve()` - basic save/get
  - `testDeleteRemovesPassword()` - deletion cleanup
  - `testOverwritePassword()` - update semantics
  - `testMultipleRobotsStoredIndependently()` - isolation

**4. MapLayerTests.swift (6 tests)**
- File: `ValetudoApp/ValetudoApp/Models/RobotMap.swift` (MapLayer struct)
- Coverage: Run-length decompression algorithm
- Key tests:
  - `testDecompressSingleRun()` - basic RLE decoding
  - `testDecompressMultipleRuns()` - sequential runs
  - `testPlainPixelsUsedWhenAvailable()` - priority logic
  - `testDecompressNilCompressedPixels()` - edge case

**5. MapViewModelTests.swift (5 tests)**
- File: `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift`
- Coverage: Initialization, capability flags, state management
- Key tests:
  - `testInitializationDefaultValues()` - @MainActor, default state
  - `testCapabilityFlagsDefaultFalse()` - guards DebugConfig
  - `testCancelEditModeResetsState()` - state reset behavior
  - All methods marked `@MainActor` (UI thread safety)

**6. RobotDetailViewModelTests.swift (15 tests)**
- File: `ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift`
- Coverage: ViewModel initialization, capability flags, consumable warnings, status state
- Key tests:
  - `testInitializationDefaults()` - @MainActor, empty state
  - `testHasConsumableWarningTrueWhenLowRemaining()` - state-dependent computed property
  - `testStatusCleaningState()` - status attribute parsing
  - `testStatusReturningIsRunning()` - multiple status value mappings
  - All methods marked `@MainActor`

**7. RobotSettingsViewModelTests.swift (4 tests)**
- File: `ValetudoApp/ValetudoApp/ViewModels/RobotSettingsViewModel.swift`
- Coverage: Initialization, capability flags, collection state
- Key tests:
  - `testInitializationDefaultValues()` - @MainActor, volume=80
  - `testCapabilityFlagsDefaultFalse()` - guards DebugConfig.showAllCapabilities
  - `testVoicePackListEmptyAfterInit()` - no premature API calls
  - All methods marked `@MainActor`

**8. ValetudoAPITests.swift (9 tests)**
- File: `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift`
- Coverage: Error handling, URL construction, JSON decoding
- Key tests:
  - `testAPIErrorHTTPErrorDescription()` - error enum conformance
  - `testBaseURLHTTP()` / `testBaseURLHTTPS()` - URL scheme handling
  - `testDecodeCapabilities()`, `testDecodeConsumable()`, `testDecodeRobotAttribute()` - JSON decoding
  - `testDecodeConsumableRemainingUnit()` - complex nested types

## ViewModel Testing Patterns

**@MainActor Decorator:**
All ViewModel tests use `@MainActor` annotation:
```swift
@MainActor
func testInitializationDefaults() {
    let config = makeRobotConfig()
    let manager = RobotManager()
    let viewModel = RobotDetailViewModel(robot: config, robotManager: manager)
    // ...
}
```

**Capability Flag Testing:**
Tests conditionally skip when in debug mode:
```swift
@MainActor
func testCapabilityFlagsDefaultFalse() {
    guard !DebugConfig.showAllCapabilities else {
        return
    }
    // assertions only run in release/test config
}
```

**State Mutation in Tests:**
Tests set ViewModel properties directly to verify computed properties:
```swift
viewModel.consumables = [lowConsumable]
XCTAssertTrue(viewModel.hasConsumableWarning)
```

## Mocking

**Framework:** XCTest (no external mocking library)

**Mocking Patterns Observed:**
- No mocking currently used
- Tests focus on pure functions and data models
- Tests that need side effects (KeychainStore) use real implementation with teardown cleanup
- ViewModel tests create `RobotManager()` with default state (no mocks)

**Opportunities for Mocking:**
- `ValetudoAPI` could be mocked for `RobotManager` tests (currently `actor` type)
- `KeychainStore` could be mocked with protocol for testing persistence-dependent code
- Network operations could use URLSession mock (nsurlprotocol subclass)

## Test Coverage Summary

**Current Coverage (57 tests):**
- Models: Strong coverage (Timer, Consumable, MapLayer all well-tested)
- ViewModels: Good coverage (initialization, capability flags, computed properties)
- API: Good coverage (error types, decoding)
- Services: Minimal (KeychainStore only, ValetudoAPI partial)

**Untested Areas (significant gaps):**
- `RobotManager.swift` (279+ lines) — state management lifecycle
- `RobotState.swift` (818+ lines) — complex nested types (tested indirectly via ValetudoAPITests)
- `NotificationService.swift` — scheduling logic
- `NetworkScanner.swift` — network discovery
- All View files (14+ files)
- `RobotIntents.swift` — Siri intent handling

## Running Tests

**In Xcode:**
- Open project: `ValetudoApp.xcodeproj`
- Test navigator: Cmd+6
- Run all tests: Cmd+U
- Run single test: Click diamond icon next to test method
- Run single class: Click diamond next to class name

**From Command Line:**
```bash
# All tests
xcodebuild test -project ValetudoApp/ValetudoApp.xcodeproj -scheme ValetudoApp

# Specific test class
xcodebuild test -project ValetudoApp/ValetudoApp.xcodeproj \
  -scheme ValetudoApp \
  -only-testing ValetudoAppTests/TimerTests

# Specific test method
xcodebuild test -project ValetudoApp/ValetudoApp.xcodeproj \
  -scheme ValetudoApp \
  -only-testing ValetudoAppTests/TimerTests/testLocalToUtcRoundTrip
```

## Adding New Tests

**File Structure:**
1. Create file: `ValetudoApp/ValetudoAppTests/{FeatureName}Tests.swift`
2. Import: `import XCTest` and `@testable import ValetudoApp`
3. Class: `final class {FeatureName}Tests: XCTestCase`
4. MARK sections: `// MARK: - Helpers` and `// MARK: - Tests`
5. Helpers: Factory functions and setup utilities
6. Tests: `func test{Behavior}()` methods
7. Cleanup: Override `tearDown()` if needed for state cleanup

**For ViewModel Tests:**
- Mark all test methods `@MainActor`
- Create helper `makeRobotConfig()` to build test robots
- Create `RobotManager()` for dependency injection
- Check `DebugConfig.showAllCapabilities` for capability flag tests

**For Model Tests:**
- Use inline JSON with raw string literals: `#"{ ... }"#`
- Create factory functions for complex objects: `makeConsumable(type:subType:value:unit:)`
- Test edge cases (zero, boundary values, overflow)

---

*Testing analysis: 2026-03-28*
