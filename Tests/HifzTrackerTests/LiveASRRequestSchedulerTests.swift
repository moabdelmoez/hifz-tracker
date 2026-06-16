import XCTest
@testable import HifzTracker

final class LiveASRRequestSchedulerTests: XCTestCase {
    func testFirstSubmittedWindowStartsImmediately() {
        var scheduler = LiveASRRequestScheduler()

        let request = scheduler.submit([1, 2, 3])

        XCTAssertEqual(request, [1, 2, 3])
    }

    func testBusySchedulerKeepsOnlyNewestPendingWindow() {
        var scheduler = LiveASRRequestScheduler()
        _ = scheduler.submit([1])

        XCTAssertNil(scheduler.submit([2]))
        XCTAssertNil(scheduler.submit([3]))

        let nextRequest = scheduler.completeActiveRequest()
        XCTAssertEqual(nextRequest, [3])
    }

    func testCompletingActiveRequestStartsPendingImmediately() {
        var scheduler = LiveASRRequestScheduler()
        _ = scheduler.submit([1])
        _ = scheduler.submit([2])

        let nextRequest = scheduler.completeActiveRequest()

        XCTAssertEqual(nextRequest, [2])
        XCTAssertNil(scheduler.submit([3]))
    }

    func testResetClearsActiveAndPendingState() {
        var scheduler = LiveASRRequestScheduler()
        _ = scheduler.submit([1])
        _ = scheduler.submit([2])

        scheduler.reset()

        let request = scheduler.submit([3])
        XCTAssertEqual(request, [3])
        XCTAssertNil(scheduler.completeActiveRequest())
    }
}
