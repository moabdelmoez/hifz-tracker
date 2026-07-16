import XCTest
import HifzCore
@testable import HifzTracker

final class LiveASRRequestSchedulerTests: XCTestCase {
    func testFirstSubmittedWindowStartsImmediately() {
        var scheduler = LiveASRRequestScheduler()

        let request = scheduler.submit(window([1, 2, 3], at: 0))

        XCTAssertEqual(request, window([1, 2, 3], at: 0))
    }

    func testBusySchedulerKeepsOnlyNewestPendingWindow() {
        var scheduler = LiveASRRequestScheduler()
        _ = scheduler.submit(window([1], at: 0))

        XCTAssertNil(scheduler.submit(window([2], at: 1)))
        XCTAssertNil(scheduler.submit(window([3], at: 2)))

        let nextRequest = scheduler.completeActiveRequest()
        XCTAssertEqual(nextRequest, window([3], at: 2))
    }

    func testCompletingActiveRequestStartsPendingImmediately() {
        var scheduler = LiveASRRequestScheduler()
        _ = scheduler.submit(window([1], at: 0))
        _ = scheduler.submit(window([2], at: 1))

        let nextRequest = scheduler.completeActiveRequest()

        XCTAssertEqual(nextRequest, window([2], at: 1))
        XCTAssertNil(scheduler.submit(window([3], at: 2)))
    }

    func testResetClearsActiveAndPendingState() {
        var scheduler = LiveASRRequestScheduler()
        _ = scheduler.submit(window([1], at: 0))
        _ = scheduler.submit(window([2], at: 1))

        scheduler.reset()

        let request = scheduler.submit(window([3], at: 2))
        XCTAssertEqual(request, window([3], at: 2))
        XCTAssertNil(scheduler.completeActiveRequest())
    }

    private func window(_ samples: [Float], at start: Int) -> LiveASRAudioWindow {
        LiveASRAudioWindow(samples: samples, sampleRange: start..<(start + samples.count))
    }
}
