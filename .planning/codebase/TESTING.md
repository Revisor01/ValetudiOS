# Testing Patterns

**Analysis Date:** 2026-03-28

## Test Framework

**Runner:** XCTest (built-in Apple framework)

**Configuration:**
- Test target: `ValetudoAppTests`
- Framework: XCTest
- No external test dependencies
- 29 unit tests across 4 test files (281 lines total)

**Run Commands:**
```bash
# Run all tests
xcodebuild test -project ValetudoApp/ValetudoApp.xcodeproj -scheme ValetudoApp

# Run specific test class
xcodebuild test -project ValetudoApp/ValetudoApp.xcodeproj -scheme ValetudoApp -only-testing ValetudoAppTests/TimerTests

# Run in Xcode (Cmd+U)
```

## Test File Organization

**Location:** `ValetudoApp/ValetudoAppTests/`

**Files:**
- `TimerTests.swift` — 19 tests for time zone conversion and UTC/local transformation
- `ConsumableTests.swift` — 7 tests for consumable state calculation and display
- `KeychainStoreTests.swift` — 6 tests for secure storage operations
- `MapLayerTests.swift` — 5 tests for map pixel decompression algorithm

**Naming Pattern:** `{SourceFileName}Tests.swift`
- `TimerTests.swift` tests `Timer.swift` model
- `ConsumableTests.swift` tests `Consumable.swift` model
- `KeychainStoreTests.swift` tests `KeychainStore` service
- `MapLayerTests.swift` tests `MapLayer` in `RobotMap.swift`

## Test Structure

**Class Pattern:**
```swift
final class TimerTests: XCTestCase { ... }
```

**Test Method Naming:** `test{Behavior}` or `test{Behavior}{Condition}`
- `testLocalToUtcRoundTrip()` — tests bidirectional conversion
- `testRemainingPercentWithPercentUnit()` — tests calculation with specific unit
- `testIconColorGreen()` — tests color output for specific value
- `testDeleteRemovesPassword()` — tests side effect of delete operation

**Setup Pattern:**
```swift
override func tearDown() {
    super.tearDown()
    // Cleanup code
}
```

**Example from `KeychainStoreTests.swift`:**
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

## Test Structure Examples

**Unit Test Suite Organization:**

From `TimerTests.swift`:
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
                XCTAssertEqual(backToUtc.hour, h)
                XCTAssertEqual(backToUtc.minute, m)
            }
        }
    }
}
```

**Test Data Helpers:**

From `ConsumableTests.swift`:
```swift
// MARK: - Helpers

private func makeConsumable(type: String, subType: String? = nil, value: Int, unit: String) -> Consumable {
    let remaining = ConsumableRemaining(value: value, unit: unit)
    return Consumable(__class: nil, type: type, subType: subType, remaining: remaining)
}
```

From `MapLayerTests.swift`:
```swift
// MARK: - Helpers

private func makeLayer(json: String) throws -> MapLayer {
    let data = json.data(using: .utf8)!
    return try JSONDecoder().decode(MapLayer.self, from: data)
}
```

**Cleanup Pattern:**

From `KeychainStoreTests.swift`:
```swift
private func makeUUID() -> UUID {
    let uuid = UUID()
    testUUIDs.append(uuid)
    return uuid
}

// Usage:
func testSaveAndRetrieve() {
    let robotId = makeUUID()
    let saved = KeychainStore.save(password: "testPass123", for: robotId)
    XCTAssertTrue(saved)
    let retrieved = KeychainStore.password(for: robotId)
    XCTAssertEqual(retrieved, "testPass123")
}
```

## Assertion Patterns

**XCTest Assertions Used:**
- `XCTAssertEqual(_:_:accuracy:)` — equality with floating-point tolerance
- `XCTAssertEqual(_:_:)` — strict equality
- `XCTAssertTrue(_:_:)` — boolean true with message
- `XCTAssertNil(_:)` — nil assertion
- `XCTAssertGreaterThanOrEqual(_:_:)` — range validation
- `XCTAssertLessThanOrEqual(_:_:)` — range validation
- `XCTAssertLessThan(_:_:)` — range validation

**Assertion with Messages:**
```swift
XCTAssertEqual(backToUtc.hour, h, "Round-trip hour mismatch for \(h):\(m)")
XCTAssertNil(retrieved, "password should be nil after delete")
```

## Test Coverage

**Current Coverage:** 29 unit tests covering 4 key areas

**Tested Modules:**

1. **Timer Logic** (`TimerTests.swift` — 19 tests)
   - UTC to local time conversion
   - Local to UTC time conversion
   - Round-trip conversions (both directions)
   - Output range validation (0-23 hours, 0-59 minutes)
   - Timezone offset application
   - File: `ValetudoApp/ValetudoApp/Models/Timer.swift`

2. **Consumable State** (`ConsumableTests.swift` — 7 tests)
   - Remaining percent calculation from percent units
   - Remaining percent calculation from minutes (with type-specific max values)
   - Percent capping at 100%
   - Icon color selection (green > 50%, orange 21-50%, red ≤ 20%)
   - File: `ValetudoApp/ValetudoApp/Models/Consumable.swift`

3. **Keychain Storage** (`KeychainStoreTests.swift` — 6 tests)
   - Save and retrieve passwords
   - Password deletion
   - Password overwrite
   - Unknown UUID returns nil
   - Multiple robots stored independently
   - Delete nonexistent UUID doesn't crash
   - File: `ValetudoApp/ValetudoApp/Keychain/KeychainStore.swift` (inferred)

4. **Map Decompression** (`MapLayerTests.swift` — 5 tests)
   - Decompress empty compressed pixels
   - Decompress single run (run-length encoding)
   - Decompress multiple runs
   - Plain pixels take priority over compressed
   - Nil compressed pixels returns empty array
   - Single pixel decompression
   - File: `ValetudoApp/ValetudoApp/Models/RobotMap.swift`

**Untested Areas (still significant):**
- `ValetudoAPI.swift` (585+ lines) — all network communication
- `RobotManager.swift` (279+ lines) — robot state management
- `RobotState.swift` (818+ lines) — API model types and decoders
- `NotificationService.swift` — notification scheduling
- `NetworkScanner.swift` — network discovery
- All View files (14+ files)
- `RobotIntents.swift` — Siri intent handling
- Helper functions in `PresetHelpers.swift`, etc.

## Mocking

**Framework:** XCTest (no external mocking library)

**Mocking Patterns Observed:**
- No mocking currently used
- Tests focus on pure functions and data models
- Tests that need side effects (KeychainStore) use real implementation with teardown cleanup

**Opportunities for Mocking:**
- `ValetudoAPI` could be mocked for `RobotManager` tests (currently `actor` type)
- `KeychainStore` could be mocked with protocol for testing persistence-dependent code
- Network operations could use URL mocking (URLSession mock)

## Test Data Patterns

**Inline JSON for Decoding Tests:**

From `MapLayerTests.swift`:
```swift
let layer = try makeLayer(json: #"{"compressedPixels": [5, 10, 3]}"#)
```

**Factory Functions for Model Creation:**

From `ConsumableTests.swift`:
```swift
private func makeConsumable(type: String, subType: String? = nil, value: Int, unit: String) -> Consumable {
    let remaining = ConsumableRemaining(value: value, unit: unit)
    return Consumable(__class: nil, type: type, subType: subType, remaining: remaining)
}
```

## Coverage Metrics

**Current Status:**
- 29 unit tests
- 4 test files
- 281 lines of test code
- Code under test: Models, utilities (not controllers/views)

**Target Modules:**
- Primarily mathematical/algorithmic code (time conversion, decompression)
- Data model properties (icon colors, consumable percentages)
- Persistence operations (keychain)

**Recommended Next Tests (by priority):**

1. **High Priority:**
   - API response decoding (custom decoders in `RobotState.swift`)
   - RobotManager state management lifecycle
   - NotificationService scheduling logic

2. **Medium Priority:**
   - PresetHelpers display name/color mapping
   - Request building (SegmentCleanRequest, GoToRequest)
   - RobotStatus computed properties

3. **Low Priority:**
   - UI layer testing (snapshot tests or UI tests)
   - Network discovery (NetworkScanner)
   - Integration tests

## Running Tests Locally

**In Xcode:**
- Open project: `ValetudoApp.xcodeproj`
- Test navigator: Cmd+6
- Run all tests: Cmd+U
- Run single test: Click diamond icon next to test method

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

## Test Maintenance

**Test File Locations:**
- Source: `ValetudoApp/ValetudoApp/Models/{Name}.swift`
- Tests: `ValetudoApp/ValetudoAppTests/{Name}Tests.swift`

**Adding New Tests:**
1. Create file: `ValetudoApp/ValetudoAppTests/NewFeatureTests.swift`
2. Import: `import XCTest` and `@testable import ValetudoApp`
3. Class: `final class NewFeatureTests: XCTestCase`
4. Setup: Add `MARK: - Helpers` section for test data builders
5. Tests: Add `func test{Behavior}()` methods
6. Cleanup: Override `tearDown()` if needed for state cleanup

---

*Testing analysis: 2026-03-28*
