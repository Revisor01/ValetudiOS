# Testing Patterns

**Analysis Date:** 2026-04-04

## Test Framework

**Runner:**
- XCTest (Apple's native testing framework)
- Config: `project.yml` defines test target `ValetudoAppTests`
- iOS unit tests (bundle.unit-test type)

**Assertion Library:**
- Native XCTest assertions (XCTAssert, XCTAssertEqual, XCTAssertTrue, XCTAssertNil, etc.)
- Custom accuracy parameter for floating-point assertions
  - Example: `XCTAssertEqual(result.scale, expectedScale, accuracy: 0.001)`

**Run Commands:**
```bash
xcodebuild test -scheme ValetudoApp -destination 'platform=iOS Simulator,name=iPhone 16'  # Run all tests
xcodebuild test -scheme ValetudoApp -only-testing ValetudoAppTests/MapGeometryTests  # Run specific suite
xcodebuild test -scheme ValetudoApp 2>&1 | grep -E "Test Suite|passed|failed"  # View results
```

## Test File Organization

**Location:**
- Co-located in separate test target: `ValetudoApp/ValetudoAppTests/`
- Parallel structure to source: `RobotState.swift` → no test file (data structure), `MapGeometry.swift` → `MapGeometryTests.swift`
- Test files mirror source organization by concern, not by layer

**Naming:**
- Test file: `{SourceFileName}Tests.swift`
- Test class: `final class {SourceFileName}Tests: XCTestCase`
- Test methods: `func test{Feature}_{Condition}_{ExpectedResult}()`
  - Example: `testCalculateMapParamsReturnsNilForEmptyLayers()`
  - Example: `testCheckForUpdates_withApprovalPendingState_transitionsToUpdateAvailable()`

**Structure:**
```
ValetudoAppTests/
├── ConsumableTests.swift
├── KeychainStoreTests.swift
├── MapCacheServiceTests.swift
├── MapGeometryTests.swift
├── MapLayerTests.swift
├── MapViewModelTests.swift
├── RobotDetailViewModelTests.swift
├── RobotSettingsViewModelTests.swift
├── SSEConnectionManagerTests.swift
├── TimerTests.swift
├── UpdateServiceTests.swift
└── ValetudoAPITests.swift
```

## Test Structure

**Suite Organization:**

All test files follow this pattern:

```swift
import XCTest
@testable import ValetudoApp

final class {Feature}Tests: XCTestCase {

    // MARK: - Helpers
    
    private func make{Type}(...) -> {Type} {
        // Factory function for test fixtures
    }
    
    // MARK: - {Feature Group 1}
    
    func test{Feature1}() { ... }
    func test{Feature1Variant}() { ... }
    
    // MARK: - {Feature Group 2}
    
    func test{Feature2}() { ... }
}
```

**Patterns:**

*Setup:* No explicit setup; tests use factory functions
- Example: `makeConsumable(type:subType:value:unit:)` in `ConsumableTests.swift`
- Example: `makeRobotConfig()` in `MapViewModelTests.swift`
- Factory functions are private and named `make{Type}`

*Teardown:* Not used; XCTest handles cleanup automatically

*Assertion Pattern:* Direct assertions on computed properties
```swift
func testRemainingPercentWithPercentUnit() {
    let consumable = makeConsumable(type: "brush", subType: "main", value: 75, unit: "percent")
    XCTAssertEqual(consumable.remainingPercent, 75.0, accuracy: 0.001)
}
```

*Async Testing:* Tests marked `@MainActor` for ViewModel tests, async functions with `await`
```swift
@MainActor
func testInitializationDefaultValues() {
    let config = makeRobotConfig()
    let manager = RobotManager()
    let viewModel = MapViewModel(robot: config, robotManager: manager, isFullscreen: false)
    
    XCTAssertTrue(viewModel.isLoading)
}
```

## Mocking

**Framework:** Manual mocking with protocol conformance

**Patterns:**

MockValetudoAPI protocol conformance:
```swift
final class MockValetudoAPI: ValetudoAPIProtocol, @unchecked Sendable {
    var updaterStateToReturn: UpdaterState = ...
    var versionToReturn: ValetudoVersion = ...
    var shouldThrowOnCheck = false
    var getUpdaterStateCallCount = 0
    var stateSequence: [UpdaterState]? = nil
    
    func checkForUpdates() async throws {
        if shouldThrowOnCheck { throw URLError(.badServerResponse) }
    }
    
    func getUpdaterState() async throws -> UpdaterState {
        getUpdaterStateCallCount += 1
        if let seq = stateSequence, getUpdaterStateCallCount <= seq.count {
            return seq[getUpdaterStateCallCount - 1]
        }
        return updaterStateToReturn
    }
}
```

**What to Mock:**
- External service dependencies (ValetudoAPI)
- Network responses with multiple states/sequences
- Error conditions (throw flags like `shouldThrowOnCheck`)
- Dependencies injected via constructor
- Services that depend on actual robot hardware

**What NOT to Mock:**
- Pure data structures (Consumable, RobotConfig, etc.)
- Utility functions (MapGeometry coordinate transforms)
- View initialization (use real ViewModels with mocked dependencies)
- Core computation logic (integer arithmetic, string formatting)

## Fixtures and Factories

**Test Data:**

Factory pattern for creating test instances:

```swift
private func makeConsumable(type: String, subType: String? = nil, value: Int, unit: String) -> Consumable {
    let remaining = ConsumableRemaining(value: value, unit: unit)
    return Consumable(__class: nil, type: type, subType: subType, remaining: remaining)
}

private func makeRobotConfig() -> RobotConfig {
    RobotConfig(
        id: UUID(),
        name: "Test Robot",
        host: UUID().uuidString,
        useSSL: false
    )
}

private func makeLayer(pixels: [Int]) -> MapLayer {
    let json = #"{"pixels": \#(pixels)}"#
    let data = json.data(using: .utf8)!
    return try! JSONDecoder().decode(MapLayer.self, from: data)
}

private func makeUpdaterState(_ className: String) -> UpdaterState {
    UpdaterState(
        __class: className,
        busy: nil, currentVersion: nil, version: nil,
        releaseTimestamp: nil, downloadUrl: nil, downloadPath: nil, metaData: nil
    )
}
```

**Location:**
- Defined in `// MARK: - Helpers` section at top of test file
- Always private functions
- No test data files; all data generated in code

## Coverage

**Requirements:** Not enforced; no configuration found

**View Coverage:**
- Unit tests cover ViewModels and pure utility functions
- Views not directly tested (rely on integration testing)
- Example: `MapViewModelTests.swift` tests ViewModel state, not SwiftUI rendering

**Tested Components:**
- Utility functions: MapGeometry (200 lines of tests)
- ViewModels: MapViewModel, RobotDetailViewModel, RobotSettingsViewModel
- Models with complex logic: Consumable (remainingPercent, iconColor)
- Services: UpdateService (state transitions), MapCacheService
- Managers: SSEConnectionManager (backoff logic), RobotManager
- Data models: Timer, MapLayer

**Untested Areas:**
- View rendering and layout
- Network requests (mocked)
- Real robot communication
- UI interactions (gestures, animations)

## Test Types

**Unit Tests:**
- Scope: Pure functions and computed properties
- Approach: Direct assertion on output given input
- Example: `testCalculateMapParamsReturnsNilForEmptyLayers()`
- Example: `testRemainingPercentWithPercentUnit()`
- Execution: Runs in isolation without network/disk I/O

**Integration Tests:**
- Scope: Service coordination (UpdateService polling, state transitions)
- Approach: Verify state changes across multiple operations
- Example: `testStartDownload_fromUpdateAvailable_transitionsToReadyToApply()` uses mock API but tests full flow
- Example: `testCheckForUpdates_withApprovalPendingState_transitionsToUpdateAvailable()`
- Execution: May use mocked dependencies but tests full workflows

**E2E Tests:**
- Framework: Not used
- Scope: Full robot communication not covered in automated tests
- Testing approach: Manual testing against real robots

## Common Patterns

**Async Testing:**

No special async test support required; await within test method:
```swift
@MainActor
func testInitializationDefaultValues() {
    let config = makeRobotConfig()
    let viewModel = MapViewModel(robot: config, robotManager: manager, isFullscreen: false)
    // No async/await needed — ViewModel init is synchronous
}
```

For async services, use standard async/await:
```swift
@MainActor
func testCheckForUpdates_withApprovalPendingState_transitionsToUpdateAvailable() async throws {
    let mock = MockValetudoAPI()
    mock.updaterStateToReturn = makeUpdaterState("ValetudoUpdaterApprovalPendingState")
    let service = UpdateService(api: mock)

    await service.checkForUpdates()

    XCTAssertEqual(service.phase, .updateAvailable)
}
```

**Error Testing:**

Pattern: Set flag, verify error phase:
```swift
func testCheckForUpdates_whenAPIThrows_transitionsToError() async throws {
    let mock = MockValetudoAPI()
    mock.shouldThrowOnCheck = true
    let service = UpdateService(api: mock)

    await service.checkForUpdates()

    if case .error = service.phase {
        // expected
    } else {
        XCTFail("Expected error phase, got \(service.phase)")
    }
}
```

Pattern: Verify exception thrown:
```swift
func testDecodingInvalidJSON() {
    let json = "invalid json"
    let data = json.data(using: .utf8)!
    
    XCTAssertThrowsError(try JSONDecoder().decode(RobotConfig.self, from: data)) { error in
        XCTAssertTrue(error is DecodingError)
    }
}
```

**Boundary Testing:**

Verify edge cases and limits:
```swift
func testBackoffCapAt30SecondsForHighRetryCount() {
    for count in 3...20 {
        XCTAssertEqual(backoffDelay(retryCount: count), 30.0, "retryCount=\(count) should be capped at 30s")
    }
}

func testRemainingPercentCapsAt100() {
    let consumable = makeConsumable(type: "brush", subType: "main", value: 20000, unit: "minutes")
    XCTAssertEqual(consumable.remainingPercent, 100.0, accuracy: 0.001)
}
```

**Roundtrip Testing:**

Verify inverse operations:
```swift
func testScreenToMapAndBackIsIdentity() {
    let viewSize = CGSize(width: 400, height: 400)
    let scale = 1.5
    let offset = CGSize(width: 30, height: -20)
    let original = CGPoint(x: 150, y: 250)

    let mapCoords = screenToMapCoords(original, scale: scale, offset: offset, viewSize: viewSize)
    let backToScreen = mapToScreenCoords(mapCoords, scale: scale, offset: offset, viewSize: viewSize)

    XCTAssertEqual(backToScreen.x, original.x, accuracy: 0.001)
    XCTAssertEqual(backToScreen.y, original.y, accuracy: 0.001)
}
```

**Sequence/State Testing:**

Mock returns different values on successive calls:
```swift
mock.stateSequence = [
    makeUpdaterState("ValetudoUpdaterApprovalPendingState"),
    makeUpdaterState("ValetudoUpdaterApplyPendingState")
]

// First call gets Approval, second gets Apply
await service.checkForUpdates()  // Uses first
await service.startDownload()    // Uses second
```

---

*Testing analysis: 2026-04-04*
