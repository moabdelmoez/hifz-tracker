import AppKit
import XCTest
@testable import HifzTracker

final class MushafPageCanvasViewTests: XCTestCase {
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

    func testViewportMetricsCanCenterLowerSelectedAyahInsteadOfLeavingItAtBottom() {
        let metrics = MushafViewportMetrics(
            containerSize: CGSize(width: 864, height: 756),
            canonicalContentSize: CGSize(width: 1_024, height: 1_641)
        )
        let falaqFirstAyahCenterY: CGFloat = 766.5

        XCTAssertGreaterThan(
            metrics.scaledCanonicalY(falaqFirstAyahCenterY),
            metrics.availableSize.height * 0.78,
            "Without focus scrolling, Al-Falaq ayah 1 lands at the bottom of this viewport."
        )
        XCTAssertGreaterThan(
            metrics.centeredScrollOffset(forCanonicalY: falaqFirstAyahCenterY),
            120,
            "The selected ayah needs a positive scroll offset so it is comfortably visible."
        )
    }
}
