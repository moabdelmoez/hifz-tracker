import AppKit
import XCTest
@testable import HifzTracker

final class MushafPageCanvasViewTests: XCTestCase {
    func testMushafPageNumberUsesArabicIndicDigits() {
        XCTAssertEqual(MushafPageNumberFormatter.string(for: 574), "٥٧٤")
        XCTAssertEqual(MushafPageNumberFormatter.string(for: 3), "٣")
    }

    @MainActor
    func testDrawingViewLetsSwiftUIFrameControlCanvasSize() {
        let view = MushafPageDrawingView()

        XCTAssertEqual(view.intrinsicContentSize.width, NSView.noIntrinsicMetric)
        XCTAssertEqual(view.intrinsicContentSize.height, NSView.noIntrinsicMetric)
    }

    func testViewportMetricsFitWidthAndOverflowVerticallyInShortWindows() {
        let metrics = MushafViewportMetrics(containerSize: CGSize(width: 520, height: 360))

        XCTAssertLessThanOrEqual(metrics.pageSize.width, metrics.availableSize.width)
        XCTAssertGreaterThan(metrics.pageSize.height, metrics.availableSize.height)
    }

    func testViewportMetricsCapPageAtCanonicalWidthForWideWindows() {
        let metrics = MushafViewportMetrics(containerSize: CGSize(width: 1_800, height: 1_200))

        XCTAssertEqual(metrics.pageSize.width, 1_024)
        XCTAssertLessThan(metrics.contentPadding.leading, 400)
        XCTAssertLessThan(metrics.contentPadding.trailing, 400)
    }

    func testViewportMetricsUseDynamicContentHeightForScrollableDensePages() {
        let metrics = MushafViewportMetrics(
            containerSize: CGSize(width: 1_200, height: 900),
            canonicalContentSize: CGSize(width: 1_024, height: 1_620)
        )

        XCTAssertEqual(metrics.pageSize.width, 1_024)
        XCTAssertEqual(metrics.pageSize.height, 1_620, accuracy: 0.001)
        XCTAssertGreaterThan(metrics.pageSize.height, metrics.availableSize.height)
    }

}
