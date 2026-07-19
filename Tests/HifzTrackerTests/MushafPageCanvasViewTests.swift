import AppKit
import HifzCore
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

    @MainActor
    func testDrawingViewInvalidatesOnlyWhenPresentationChanges() {
        let word = QuranWord(id: 1, location: "1:1:1", surah: 1, ayah: 1, wordIndex: 1, text: "word")
        let page = MushafPage(pageNumber: 1, lines: [
            MushafPageLine(
                pageNumber: 1,
                lineNumber: 1,
                lineType: .ayah,
                isCentered: false,
                firstWordID: 1,
                lastWordID: 1,
                surahNumber: 1,
                words: [word]
            )
        ])
        let pending = MushafPagePresentation(page: page, state: { _ in .pending }, isTextVisible: { _ in true })
        let completed = MushafPagePresentation(page: page, state: { _ in .completed }, isTextVisible: { _ in true })
        let view = MushafPageDrawingView()

        XCTAssertTrue(view.update(page: page, pageNumber: 1, presentation: pending, fontDirectory: nil))
        XCTAssertFalse(view.update(page: page, pageNumber: 1, presentation: pending, fontDirectory: nil))
        XCTAssertTrue(view.update(page: page, pageNumber: 1, presentation: completed, fontDirectory: nil))
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
