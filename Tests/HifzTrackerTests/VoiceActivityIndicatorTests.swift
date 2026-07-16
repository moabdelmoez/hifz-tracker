import XCTest
@testable import HifzTracker

final class VoiceActivityIndicatorTests: XCTestCase {
    func testIndicatorUsesFourCircles() {
        XCTAssertEqual(VoiceActivityIndicatorMetrics.circleCount, 4)
    }

    func testIndicatorFitsMinimumSidebarContentWidth() {
        let width = Double(VoiceActivityIndicatorMetrics.circleCount) * Double(VoiceActivityIndicatorMetrics.circleSize)
            + Double(VoiceActivityIndicatorMetrics.circleCount - 1) * Double(VoiceActivityIndicatorMetrics.circleSpacing)

        XCTAssertLessThanOrEqual(width, 208)
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
