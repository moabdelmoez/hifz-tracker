import AppKit
import XCTest
@testable import HifzTracker

final class AppDelegateTests: XCTestCase {
    @MainActor
    func testReopenWithoutVisibleWindowsOpensRecitation() {
        var opened = false
        let delegate = AppDelegate()
        delegate.openRecitationWindow = { opened = true }

        XCTAssertFalse(delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false))
        XCTAssertTrue(opened)
    }

    @MainActor
    func testReopenWithVisibleWindowsUsesDefaultHandling() {
        let delegate = AppDelegate()
        delegate.openRecitationWindow = { XCTFail("An additional Recitation window should not open") }

        XCTAssertTrue(delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: true))
    }
}
