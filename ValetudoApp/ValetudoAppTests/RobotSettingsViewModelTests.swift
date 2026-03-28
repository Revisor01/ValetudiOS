import XCTest
@testable import ValetudoApp

final class RobotSettingsViewModelTests: XCTestCase {

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
        let viewModel = RobotSettingsViewModel(robot: config, robotManager: manager)

        XCTAssertEqual(viewModel.volume, 80)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.mapSnapshots.isEmpty)
        XCTAssertTrue(viewModel.voicePacks.isEmpty)
        XCTAssertFalse(viewModel.pendingMapChangeEnabled)
    }

    // MARK: - Test 2: Capability flags default to false (DebugConfig.showAllCapabilities == false)

    @MainActor
    func testCapabilityFlagsDefaultFalse() {
        guard !DebugConfig.showAllCapabilities else {
            return
        }

        let config = makeRobotConfig()
        let manager = RobotManager()
        let viewModel = RobotSettingsViewModel(robot: config, robotManager: manager)

        XCTAssertFalse(viewModel.hasVoicePack)
        XCTAssertFalse(viewModel.hasMapSnapshots)
        XCTAssertFalse(viewModel.hasPendingMapChange)
    }

    // MARK: - Test 3: VoicePack list is empty after init (no API call)

    @MainActor
    func testVoicePackListEmptyAfterInit() {
        let config = makeRobotConfig()
        let manager = RobotManager()
        let viewModel = RobotSettingsViewModel(robot: config, robotManager: manager)

        XCTAssertTrue(viewModel.voicePacks.isEmpty)
    }

    // MARK: - Test 4: MapSnapshots empty and not restoring after init

    @MainActor
    func testMapSnapshotsEmptyAndNotRestoringAfterInit() {
        let config = makeRobotConfig()
        let manager = RobotManager()
        let viewModel = RobotSettingsViewModel(robot: config, robotManager: manager)

        XCTAssertTrue(viewModel.mapSnapshots.isEmpty)
        XCTAssertFalse(viewModel.isRestoringSnapshot)
    }
}
