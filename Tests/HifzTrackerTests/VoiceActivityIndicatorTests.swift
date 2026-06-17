import XCTest
@testable import HifzTracker

final class VoiceActivityIndicatorTests: XCTestCase {
    func testIndicatorUsesFourCircles() {
        XCTAssertEqual(VoiceActivityIndicatorMetrics.circleCount, 4)
    }

    func testHighlightCycleWrapsAfterLastCircle() {
        XCTAssertEqual(VoiceActivityIndicatorMetrics.nextIndex(after: 0), 1)
        XCTAssertEqual(VoiceActivityIndicatorMetrics.nextIndex(after: 1), 2)
        XCTAssertEqual(VoiceActivityIndicatorMetrics.nextIndex(after: 2), 3)
        XCTAssertEqual(VoiceActivityIndicatorMetrics.nextIndex(after: 3), 0)
    }

    func testHighlightStepIntervalMatchesDesignCadence() {
        XCTAssertEqual(VoiceActivityIndicatorMetrics.stepIntervalNanoseconds, 320_000_000)
    }
}
