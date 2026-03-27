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

    func testRemainingPercentWithMinutesMainBrush() {
        // maxMinutes for main brush = 18000
        let consumable = makeConsumable(type: "brush", subType: "main", value: 9000, unit: "minutes")
        XCTAssertEqual(consumable.remainingPercent, 50.0, accuracy: 0.001)
    }

    func testRemainingPercentWithMinutesSideBrush() {
        // maxMinutes for side brush = 12000
        let consumable = makeConsumable(type: "brush", subType: "side_right", value: 6000, unit: "minutes")
        XCTAssertEqual(consumable.remainingPercent, 50.0, accuracy: 0.001)
    }

    func testRemainingPercentCapsAt100() {
        // 20000 minutes > 18000 max, should be capped at 100
        let consumable = makeConsumable(type: "brush", subType: "main", value: 20000, unit: "minutes")
        XCTAssertEqual(consumable.remainingPercent, 100.0, accuracy: 0.001)
    }

    func testRemainingPercentFilter() {
        // maxMinutes for filter = 9000
        let consumable = makeConsumable(type: "filter", value: 4500, unit: "minutes")
        XCTAssertEqual(consumable.remainingPercent, 50.0, accuracy: 0.001)
    }

    func testRemainingPercentZero() {
        let consumable = makeConsumable(type: "brush", subType: "main", value: 0, unit: "percent")
        XCTAssertEqual(consumable.remainingPercent, 0.0, accuracy: 0.001)
    }

    func testRemainingPercentFullPercent() {
        let consumable = makeConsumable(type: "filter", value: 100, unit: "percent")
        XCTAssertEqual(consumable.remainingPercent, 100.0, accuracy: 0.001)
    }

    // MARK: - iconColor

    func testIconColorGreen() {
        let consumable = makeConsumable(type: "brush", subType: "main", value: 75, unit: "percent")
        XCTAssertEqual(consumable.iconColor, .green)
    }

    func testIconColorOrange() {
        let consumable = makeConsumable(type: "brush", subType: "main", value: 35, unit: "percent")
        XCTAssertEqual(consumable.iconColor, .orange)
    }

    func testIconColorOrangeLowerBound() {
        let consumable = makeConsumable(type: "brush", subType: "main", value: 21, unit: "percent")
        XCTAssertEqual(consumable.iconColor, .orange)
    }

    func testIconColorRed() {
        let consumable = makeConsumable(type: "brush", subType: "main", value: 15, unit: "percent")
        XCTAssertEqual(consumable.iconColor, .red)
    }

    func testIconColorRedAtZero() {
        let consumable = makeConsumable(type: "filter", value: 0, unit: "percent")
        XCTAssertEqual(consumable.iconColor, .red)
    }
}
