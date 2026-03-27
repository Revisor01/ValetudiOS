import XCTest
@testable import ValetudoApp

final class TimerTests: XCTestCase {

    /// Round-trip property: utcToLocal then localToUTC must return the original values.
    /// This holds for any timezone the test runner is in.
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

    /// Round-trip in the reverse direction: localToUTC then utcToLocal must return original.
    func testUtcToLocalRoundTrip() {
        let hours = [0, 6, 12, 18, 23]
        let minutes = [0, 30]
        for h in hours {
            for m in minutes {
                let utc = ValetudoTimer.localToUTC(hour: h, minute: m)
                let backToLocal = ValetudoTimer.utcToLocal(hour: utc.hour, minute: utc.minute)
                XCTAssertEqual(backToLocal.hour, h, "Reverse round-trip hour mismatch for \(h):\(m)")
                XCTAssertEqual(backToLocal.minute, m, "Reverse round-trip minute mismatch for \(h):\(m)")
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

    /// Output hour must always be in range [0, 23].
    func testLocalToUtcOutputRange() {
        for h in 0...23 {
            for m in [0, 30] {
                let result = ValetudoTimer.localToUTC(hour: h, minute: m)
                XCTAssertGreaterThanOrEqual(result.hour, 0)
                XCTAssertLessThanOrEqual(result.hour, 23)
                XCTAssertGreaterThanOrEqual(result.minute, 0)
                XCTAssertLessThan(result.minute, 60)
            }
        }
    }

    /// Verify that utcOffset is correctly applied: the difference between local and UTC
    /// must equal the current timezone offset (mod 24h).
    func testUtcToLocalAppliesOffset() {
        let offsetMinutes = TimeZone.current.secondsFromGMT() / 60
        let inputH = 10
        let inputM = 0
        let result = ValetudoTimer.utcToLocal(hour: inputH, minute: inputM)
        let expectedTotalMinutes = ((inputH * 60 + inputM + offsetMinutes) % (24 * 60) + 24 * 60) % (24 * 60)
        let expectedH = expectedTotalMinutes / 60
        let expectedM = expectedTotalMinutes % 60
        XCTAssertEqual(result.hour, expectedH)
        XCTAssertEqual(result.minute, expectedM)
    }
}
