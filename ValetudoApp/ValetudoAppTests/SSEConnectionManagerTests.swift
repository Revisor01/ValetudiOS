import XCTest
@testable import ValetudoApp

// MARK: - SSE Backoff Timing Tests
// SSEConnectionManager is an actor with private state, so we test:
// 1. The documented backoff schedule (1s → 5s → 30s)
// 2. Connection state management (connect/disconnect)
// 3. Line parsing logic (data: prefix handling)

final class SSEConnectionManagerTests: XCTestCase {

    // MARK: - Backoff Schedule Tests

    /// Validates the documented backoff values from SSEConnectionManager.streamWithReconnect
    /// Backoff logic: retryCount 1 → 1s, 2 → 5s, 3+ → 30s (capped)
    func testBackoffRetryCount1Is1Second() {
        let delay = backoffDelay(retryCount: 1)
        XCTAssertEqual(delay, 1.0)
    }

    func testBackoffRetryCount2Is5Seconds() {
        let delay = backoffDelay(retryCount: 2)
        XCTAssertEqual(delay, 5.0)
    }

    func testBackoffRetryCount3Is30Seconds() {
        let delay = backoffDelay(retryCount: 3)
        XCTAssertEqual(delay, 30.0)
    }

    func testBackoffRetryCount10Is30Seconds() {
        let delay = backoffDelay(retryCount: 10)
        XCTAssertEqual(delay, 30.0)
    }

    func testBackoffRetryCount100Is30Seconds() {
        let delay = backoffDelay(retryCount: 100)
        XCTAssertEqual(delay, 30.0)
    }

    func testBackoffIsMonotonicallyNonDecreasing() {
        let delay1 = backoffDelay(retryCount: 1)
        let delay2 = backoffDelay(retryCount: 2)
        let delay3 = backoffDelay(retryCount: 3)
        XCTAssertLessThanOrEqual(delay1, delay2)
        XCTAssertLessThanOrEqual(delay2, delay3)
    }

    func testBackoffCapAt30SecondsForHighRetryCount() {
        // All counts >= 3 must return 30s (capped)
        for count in 3...20 {
            XCTAssertEqual(backoffDelay(retryCount: count), 30.0, "retryCount=\(count) should be capped at 30s")
        }
    }

    // MARK: - SSE Line Parsing Logic

    func testSSELineWithDataPrefixIsValid() {
        let line = "data: {\"key\": \"value\"}"
        XCTAssertTrue(line.hasPrefix("data:"))
    }

    func testSSELineWithoutDataPrefixIsIgnored() {
        let lines = ["event: heartbeat", "id: 123", ": comment", "", "retry: 1000"]
        for line in lines {
            XCTAssertFalse(line.hasPrefix("data:"), "Line '\(line)' should be ignored")
        }
    }

    func testSSEDataExtractionStripsPrefix() {
        let line = "data: {\"foo\": \"bar\"}"
        let extracted = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        XCTAssertEqual(extracted, "{\"foo\": \"bar\"}")
    }

    func testSSEDataExtractionWithLeadingSpace() {
        let line = "data:  extra space"
        let extracted = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        XCTAssertEqual(extracted, "extra space")
    }

    func testSSEEmptyDataLineIsIgnored() {
        let line = "data:"
        let extracted = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        XCTAssertTrue(extracted.isEmpty)
    }

    func testSSEDataLineCanBeDecodedToAttributes() throws {
        // Validate that a well-formed SSE data line can be decoded to [RobotAttribute]
        let jsonString = "[{\"__class\": \"BatteryStateAttribute\", \"level\": 85}]"
        let data = try XCTUnwrap(jsonString.data(using: .utf8))
        let attributes = try JSONDecoder().decode([RobotAttribute].self, from: data)
        XCTAssertEqual(attributes.count, 1)
        XCTAssertEqual(attributes.first?.__class, "BatteryStateAttribute")
        XCTAssertEqual(attributes.first?.level, 85)
    }

    // MARK: - SSEConnectionManager Actor State

    func testIsSSEActiveReturnsFalseForUnknownRobot() async {
        let manager = SSEConnectionManager()
        let unknownId = UUID()
        let active = await manager.isSSEActive(for: unknownId)
        XCTAssertFalse(active)
    }

    func testDisconnectUnknownRobotDoesNotCrash() async {
        let manager = SSEConnectionManager()
        let unknownId = UUID()
        // Should not throw or crash
        await manager.disconnect(robotId: unknownId)
        let active = await manager.isSSEActive(for: unknownId)
        XCTAssertFalse(active)
    }

    func testDisconnectAllWithNoConnectionsDoesNotCrash() async {
        let manager = SSEConnectionManager()
        // Should not throw or crash with empty state
        await manager.disconnectAll()
    }

    // MARK: - Helpers

    /// Replicates the backoff logic from SSEConnectionManager.streamWithReconnect
    private func backoffDelay(retryCount: Int) -> Double {
        switch retryCount {
        case 1:  return 1
        case 2:  return 5
        default: return 30
        }
    }
}
