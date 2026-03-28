import XCTest
@testable import ValetudoApp

final class RobotDetailViewModelTests: XCTestCase {

    // MARK: - Helpers

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

    private func makeAttribute(json: String) throws -> RobotAttribute {
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(RobotAttribute.self, from: data)
    }

    // MARK: - Test 1: Initialization defaults

    @MainActor
    func testInitializationDefaults() {
        let config = makeRobotConfig()
        let manager = RobotManager()
        let viewModel = RobotDetailViewModel(robot: config, robotManager: manager)

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.segments.isEmpty)
        XCTAssertTrue(viewModel.consumables.isEmpty)
        XCTAssertTrue(viewModel.events.isEmpty)
    }

    // MARK: - Test 2: Capability flags default to false (DebugConfig.showAllCapabilities == false)

    @MainActor
    func testCapabilityFlagsDefaultFalse() {
        // Only valid when DebugConfig.showAllCapabilities is false (production default)
        guard !DebugConfig.showAllCapabilities else {
            // In debug mode with showAllCapabilities=true, skip this test
            return
        }

        let config = makeRobotConfig()
        let manager = RobotManager()
        let viewModel = RobotDetailViewModel(robot: config, robotManager: manager)

        XCTAssertFalse(viewModel.hasCleanRoute)
        XCTAssertFalse(viewModel.hasObstacleImages)
        XCTAssertFalse(viewModel.hasEvents)
    }

    // MARK: - Test 3: hasConsumableWarning is false when consumables list is empty

    @MainActor
    func testHasConsumableWarningFalseWhenEmpty() {
        let config = makeRobotConfig()
        let manager = RobotManager()
        let viewModel = RobotDetailViewModel(robot: config, robotManager: manager)

        XCTAssertTrue(viewModel.consumables.isEmpty)
        XCTAssertFalse(viewModel.hasConsumableWarning)
    }

    // MARK: - Test 4: hasConsumableWarning is true when a consumable has low remaining

    @MainActor
    func testHasConsumableWarningTrueWhenLowRemaining() throws {
        let config = makeRobotConfig()
        let manager = RobotManager()
        let viewModel = RobotDetailViewModel(robot: config, robotManager: manager)

        let lowConsumable = try makeConsumable(json: """
        {"type":"filter","sub_type":null,"remaining":{"unit":"percent","value":15}}
        """)

        viewModel.consumables = [lowConsumable]
        XCTAssertTrue(viewModel.hasConsumableWarning)
    }

    // MARK: - Test 5a: isCleaning / isPaused / isRunning for "cleaning" status

    @MainActor
    func testStatusCleaningState() throws {
        let config = makeRobotConfig()
        let manager = RobotManager()
        let viewModel = RobotDetailViewModel(robot: config, robotManager: manager)

        let cleaningAttr = try makeAttribute(json: """
        {"__class":"StatusStateAttribute","value":"cleaning","flag":"none"}
        """)

        manager.robotStates[config.id] = RobotStatus(
            isOnline: true,
            attributes: [cleaningAttr]
        )

        XCTAssertTrue(viewModel.isCleaning)
        XCTAssertTrue(viewModel.isRunning)
        XCTAssertFalse(viewModel.isPaused)
    }

    // MARK: - Test 5b: isCleaning / isPaused / isRunning for "docked" status

    @MainActor
    func testStatusDockedState() throws {
        let config = makeRobotConfig()
        let manager = RobotManager()
        let viewModel = RobotDetailViewModel(robot: config, robotManager: manager)

        let dockedAttr = try makeAttribute(json: """
        {"__class":"StatusStateAttribute","value":"docked","flag":"none"}
        """)

        manager.robotStates[config.id] = RobotStatus(
            isOnline: true,
            attributes: [dockedAttr]
        )

        XCTAssertFalse(viewModel.isCleaning)
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertFalse(viewModel.isPaused)
    }

    // MARK: - Test 6: isRunning for "returning" status

    @MainActor
    func testStatusReturningIsRunning() throws {
        let config = makeRobotConfig()
        let manager = RobotManager()
        let viewModel = RobotDetailViewModel(robot: config, robotManager: manager)

        let returningAttr = try makeAttribute(json: """
        {"__class":"StatusStateAttribute","value":"returning","flag":"none"}
        """)

        manager.robotStates[config.id] = RobotStatus(
            isOnline: true,
            attributes: [returningAttr]
        )

        XCTAssertTrue(viewModel.isRunning)
        XCTAssertFalse(viewModel.isCleaning)
        XCTAssertFalse(viewModel.isPaused)
    }
}
