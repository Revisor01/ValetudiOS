import XCTest
@testable import ValetudoApp

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
        XCTAssertTrue(viewModel.drawnZones.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.selectedSegmentIds.isEmpty)
        XCTAssertEqual(viewModel.selectedIterations, 1)
    }

    // MARK: - Test 2: Capability flags default to false

    @MainActor
    func testCapabilityFlagsDefaultFalse() {
        let config = makeRobotConfig()
        let manager = RobotManager()
        let viewModel = MapViewModel(robot: config, robotManager: manager, isFullscreen: false)

        XCTAssertFalse(viewModel.hasZoneCleaning)
        XCTAssertFalse(viewModel.hasGoTo)
    }

    // MARK: - Test 3: cancelEditMode resets editMode and drawnZones

    @MainActor
    func testCancelEditModeResetsState() {
        let config = makeRobotConfig()
        let manager = RobotManager()
        let viewModel = MapViewModel(robot: config, robotManager: manager, isFullscreen: false)

        viewModel.editMode = .zone
        let zone = CleaningZone(
            points: ZonePoints(
                pA: ZonePoint(x: 0, y: 0),
                pB: ZonePoint(x: 10, y: 0),
                pC: ZonePoint(x: 10, y: 10),
                pD: ZonePoint(x: 0, y: 10)
            )
        )
        viewModel.drawnZones = [zone]

        viewModel.cancelEditMode()

        XCTAssertEqual(viewModel.editMode, .none)
        XCTAssertTrue(viewModel.drawnZones.isEmpty)
    }

    // MARK: - Test 4: isCleaning default is false

    @MainActor
    func testIsCleaningDefaultFalse() {
        let config = makeRobotConfig()
        let manager = RobotManager()
        let viewModel = MapViewModel(robot: config, robotManager: manager, isFullscreen: false)

        XCTAssertFalse(viewModel.isCleaning)
    }

    // MARK: - Test 5: errorMessage is settable

    @MainActor
    func testErrorMessageIsSettable() {
        let config = makeRobotConfig()
        let manager = RobotManager()
        let viewModel = MapViewModel(robot: config, robotManager: manager, isFullscreen: false)

        viewModel.errorMessage = "Test Fehler"
        XCTAssertEqual(viewModel.errorMessage, "Test Fehler")
    }
}
