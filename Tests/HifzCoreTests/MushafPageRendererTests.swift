#if canImport(AppKit)
import AppKit
import XCTest
@testable import HifzCore

final class MushafPageRendererTests: XCTestCase {
    func testFitsMushafPageInsideAvailableSizeWithoutChangingAspectRatio() {
        let wideRect = MushafPageRenderer.fittedPageRect(in: CGRect(x: 0, y: 0, width: 1_600, height: 900))
        XCTAssertLessThanOrEqual(wideRect.width, 1_600.001)
        XCTAssertLessThanOrEqual(wideRect.height, 900.001)
        XCTAssertEqual(wideRect.width / wideRect.height, MushafPageRenderer.canonicalPageAspectRatio, accuracy: 0.001)

        let tallRect = MushafPageRenderer.fittedPageRect(in: CGRect(x: 0, y: 0, width: 700, height: 1_400))
        XCTAssertLessThanOrEqual(tallRect.width, 700.001)
        XCTAssertLessThanOrEqual(tallRect.height, 1_400.001)
        XCTAssertEqual(tallRect.width / tallRect.height, MushafPageRenderer.canonicalPageAspectRatio, accuracy: 0.001)
    }

    func testRendersQpcV4LineWithTajweedColorGlyphs() throws {
        let page = try makePage574()
        let recitationLine = page.lines[3]
        let image = try MushafPageRenderer.renderLine(
            recitationLine,
            pageNumber: 574,
            fontDirectory: fontDirectory,
            canvasSize: CGSize(width: 1_200, height: 220),
            fontSize: 54
        )

        XCTAssertGreaterThan(
            try saturatedPixelCount(in: image),
            1_000,
            "QPC V4 Tajweed rendering should contain colored glyph pixels, not fallback black glyph-code text."
        )
    }

    func testRendersFullPageWithVisibleTajweedAndNoEdgeClipping() throws {
        let image = try MushafPageRenderer.renderPage(
            try makePage574(),
            pageNumber: 574,
            fontDirectory: fontDirectory,
            canvasSize: CGSize(width: 768, height: 1_024),
            stateProvider: Optional<((QuranWord) -> WordProgressState)>.none
        )

        try writePreviewIfRequested(image)
        XCTAssertGreaterThan(try saturatedPixelCount(in: image), 8_000)
        XCTAssertLessThan(
            try edgeInkPixelCount(in: image, edgeWidth: 6),
            20,
            "Full-page render should fit inside the page canvas without clipping text at the edges."
        )
    }

    func testPage574ReservesFooterBandBelowFinalAyah() throws {
        let canvasSize = MushafPageRenderer.canonicalContentSize(for: try makePage574())

        XCTAssertEqual(canvasSize.height, 1_422, accuracy: 0.001)
    }

    func testRendersWordProgressHighlightsBehindQpcGlyphWords() throws {
        let page = try makePage574()
        let canvasSize = MushafPageRenderer.canonicalContentSize(for: page)
        let unhighlighted = try MushafPageRenderer.renderPage(
            page,
            pageNumber: 574,
            fontDirectory: fontDirectory,
            canvasSize: canvasSize,
            stateProvider: Optional<((QuranWord) -> WordProgressState)>.none
        )
        let highlighted = try MushafPageRenderer.renderPage(
            page,
            pageNumber: 574,
            fontDirectory: fontDirectory,
            canvasSize: canvasSize
        ) { word in
            if word.surah == 73, word.ayah == 1, word.wordIndex == 1 {
                return .current
            }
            if word.surah == 73, word.ayah == 1, word.wordIndex == 2 {
                return .completed
            }
            return .pending
        }

        let baseHighlightPixels = try paleProgressHighlightPixelCount(in: unhighlighted)
        let progressHighlightPixels = try paleProgressHighlightPixelCount(in: highlighted)

        XCTAssertGreaterThan(
            progressHighlightPixels - baseHighlightPixels,
            1_000,
            "Word-progress states should produce visible overlay pixels behind QPC V4 glyph words."
        )
    }

    func testVisibilityProviderSuppressesHiddenWordsWithoutChangingPageSize() throws {
        let page = try makePage574()
        let canvasSize = MushafPageRenderer.canonicalContentSize(for: page)
        let firstAyahLineRect = CGRect(x: 52, y: 246, width: 920, height: 130)

        let visible = try MushafPageRenderer.renderPage(
            page,
            pageNumber: 574,
            fontDirectory: fontDirectory,
            canvasSize: canvasSize,
            stateProvider: Optional<((QuranWord) -> WordProgressState)>.none
        )
        let hidden = try MushafPageRenderer.renderPage(
            page,
            pageNumber: 574,
            fontDirectory: fontDirectory,
            canvasSize: canvasSize,
            stateProvider: Optional<((QuranWord) -> WordProgressState)>.none,
            visibilityProvider: { word in
                !(word.surah == 73 && word.ayah == 1)
            }
        )
        let firstWordVisible = try MushafPageRenderer.renderPage(
            page,
            pageNumber: 574,
            fontDirectory: fontDirectory,
            canvasSize: canvasSize,
            stateProvider: Optional<((QuranWord) -> WordProgressState)>.none,
            visibilityProvider: { word in
                word.surah != 73 || word.ayah != 1 || word.wordIndex == 1
            }
        )

        XCTAssertEqual(hidden.size, visible.size)
        XCTAssertEqual(firstWordVisible.size, visible.size)

        let visibleInk = try visibleInkPixelCount(in: visible, rect: firstAyahLineRect)
        let hiddenInk = try visibleInkPixelCount(in: hidden, rect: firstAyahLineRect)
        let firstWordInk = try visibleInkPixelCount(in: firstWordVisible, rect: firstAyahLineRect)

        XCTAssertGreaterThan(
            visibleInk - hiddenInk,
            1_000,
            "Hidden ayah words should remove visible glyph ink from the ayah line."
        )
        XCTAssertGreaterThan(
            firstWordInk - hiddenInk,
            80,
            "A visible completed word should still render its glyph in the original line position."
        )
        XCTAssertLessThan(
            firstWordInk,
            visibleInk,
            "Rendering one revealed word should not leak the remaining hidden ayah text."
        )
    }

    func testVisibilityProviderKeepsAyahMarkerAfterRevealedAyah() throws {
        let page = try makePage(592)
        let canvasSize = MushafPageRenderer.canonicalContentSize(for: page)
        let firstGhashiyahLineRect = CGRect(x: 52, y: 662.5, width: 920, height: 130)

        let visible = try MushafPageRenderer.renderPage(
            page,
            pageNumber: 592,
            fontDirectory: fontDirectory,
            canvasSize: canvasSize,
            stateProvider: Optional<((QuranWord) -> WordProgressState)>.none
        )
        let onlyFirstAyahVisible = try MushafPageRenderer.renderPage(
            page,
            pageNumber: 592,
            fontDirectory: fontDirectory,
            canvasSize: canvasSize,
            stateProvider: { word in
                word.surah == 88 && word.ayah == 1 ? .completed : .pending
            },
            visibilityProvider: { word in
                word.surah != 88 || word.ayah == 1
            }
        )

        let firstAyahMarkerRect = CGRect(x: 550, y: 704, width: 56, height: 70)
        let visibleInk = try darkPixelCount(in: visible, rect: firstGhashiyahLineRect)
        let firstAyahInk = try darkPixelCount(in: onlyFirstAyahVisible, rect: firstGhashiyahLineRect)
        let markerInk = try ornamentalAyahMarkerPixelCount(in: onlyFirstAyahVisible, rect: firstAyahMarkerRect)

        XCTAssertGreaterThan(
            firstAyahInk,
            visibleInk / 3,
            "The revealed ayah should retain its shaped glyphs and ayah marker even when following target words are hidden."
        )
        XCTAssertGreaterThan(
            markerInk,
            60,
            "A revealed ayah on a mixed visible/hidden line should retain the ornamental ayah marker medallion."
        )
    }

    func testVisibilityProviderDoesNotClipVisibleWordsBeforeHiddenMarker() throws {
        let page = try makePage(603)
        let canvasSize = MushafPageRenderer.canonicalContentSize(for: page)
        let nasrFinalLineRect = CGRect(x: 52, y: 943, width: 920, height: 130)

        let visible = try MushafPageRenderer.renderPage(
            page,
            pageNumber: 603,
            fontDirectory: fontDirectory,
            canvasSize: canvasSize,
            stateProvider: Optional<((QuranWord) -> WordProgressState)>.none
        )
        let hiddenMarker = try MushafPageRenderer.renderPage(
            page,
            pageNumber: 603,
            fontDirectory: fontDirectory,
            canvasSize: canvasSize,
            stateProvider: { word in
                word.surah == 110 ? .completed : .pending
            },
            visibilityProvider: { word in
                !(word.surah == 110 && word.ayah == 3 && word.wordIndex == 8)
            }
        )

        let visibleInk = try visibleInkPixelCount(in: visible, rect: nasrFinalLineRect)
        let hiddenMarkerInk = try visibleInkPixelCount(in: hiddenMarker, rect: nasrFinalLineRect)

        XCTAssertGreaterThan(
            hiddenMarkerInk,
            visibleInk * 3 / 4,
            "Hiding only the ayah marker must not clip the final visible words. visible=\(visibleInk) hiddenMarker=\(hiddenMarkerInk)"
        )
    }

    func testUsesQULDisplayTokensForSurahHeaderAndBismillah() throws {
        let page = try makePage574()

        XCTAssertEqual(
            MushafPageRenderer.displayLine(for: page.lines[0]),
            .surahHeader(frameToken: "header", surahToken: "surah073", iconToken: "surah-icon")
        )
        XCTAssertEqual(
            MushafPageRenderer.displayLine(for: page.lines[1]),
            .bismillah(glyph: "﷽")
        )
        guard case .ayah(let glyphText) = MushafPageRenderer.displayLine(for: page.lines[2]) else {
            return XCTFail("Line 3 should render as ayah glyph text.")
        }
        XCTAssertTrue(glyphText.hasPrefix("ﱁﱂﱃ"))
        XCTAssertGreaterThan(glyphText.count, 3)
    }

    func testQULHeaderAndBismillahFontsAreBundled() {
        let requiredFontFiles = [
            "quran-common.ttf",
            "surah-name-v4.ttf",
            "bismillah.ttf"
        ]

        for fileName in requiredFontFiles {
            let path = fontDirectory.appending(path: fileName).path
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: path),
                "Missing QUL font asset: \(fileName)"
            )
        }
    }

    func testRendersMidPageSurahHeaderAtItsLayoutLine() throws {
        let page = try makePage(106)
        let headerLine = try XCTUnwrap(page.lines.first { $0.lineType == .surahName })
        let bismillahLine = try XCTUnwrap(page.lines.first { $0.lineType == .basmallah })

        XCTAssertEqual(headerLine.lineNumber, 6)
        XCTAssertEqual(headerLine.surahNumber, 5)
        XCTAssertEqual(bismillahLine.lineNumber, 7)

        let image = try MushafPageRenderer.renderPage(
            page,
            pageNumber: 106,
            fontDirectory: fontDirectory,
            canvasSize: MushafPageRenderer.canonicalContentSize(for: page),
            stateProvider: Optional<((QuranWord) -> WordProgressState)>.none
        )

        XCTAssertLessThan(
            try darkPixelCount(in: image, rect: CGRect(x: 62, y: 18, width: 900, height: 126)),
            12_000,
            "A mid-page surah header must not be drawn in the fixed top-page header slot."
        )
        XCTAssertGreaterThan(
            try darkPixelCount(in: image, rect: CGRect(x: 62, y: 458, width: 900, height: 126)),
            10_000,
            "The Surah Al-Ma'idah header should render around layout line 6."
        )
    }

    func testRendersShortSurahPageWithSeparatedAyahAndHeaderBands() throws {
        let page = try makePage(602)
        let canvasSize = MushafPageRenderer.canonicalContentSize(for: page)
        let image = try MushafPageRenderer.renderPage(
            page,
            pageNumber: 602,
            fontDirectory: fontDirectory,
            canvasSize: canvasSize,
            stateProvider: Optional<((QuranWord) -> WordProgressState)>.none
        )
        let bands = try darkRowBands(in: image, rect: CGRect(x: 52, y: 1, width: 920, height: canvasSize.height - 2))

        let headerBands = bands.filter { $0.maxCount > 720 }
        XCTAssertGreaterThanOrEqual(headerBands.count, 3)

        let ayahBandBeforeSecondHeader = bands.first { band in
            band.start > 390 && band.end < headerBands[1].start - 12 && band.maxCount < 500
        }
        XCTAssertNotNil(
            ayahBandBeforeSecondHeader,
            "The last Quraysh ayah line should remain visually separate before the Surah Al-Ma'un header."
        )
    }

    func testRendersShortSurahPageWithoutBottomEdgeClipping() throws {
        let page = try makePage(602)
        let canvasSize = MushafPageRenderer.canonicalContentSize(for: page)

        XCTAssertGreaterThan(
            canvasSize.height,
            MushafPageRenderer.canonicalPageSize.height,
            "Dense short-surah pages need a taller canonical canvas so the app can scroll to their final lines."
        )

        let image = try MushafPageRenderer.renderPage(
            page,
            pageNumber: 602,
            fontDirectory: fontDirectory,
            canvasSize: canvasSize,
            stateProvider: Optional<((QuranWord) -> WordProgressState)>.none
        )

        try writePreviewIfRequested(image)
        XCTAssertLessThan(
            try edgeInkPixelCount(in: image, edgeWidth: 6),
            20,
            "Dense short-surah pages should not push later ayah lines through the bottom edge of the page canvas."
        )
    }

    func testRendersFinalShortSurahPageWithoutBottomEdgeClipping() throws {
        let page = try makePage(604)
        let canvasSize = MushafPageRenderer.canonicalContentSize(for: page)

        XCTAssertGreaterThan(
            canvasSize.height,
            MushafPageRenderer.canonicalPageSize.height,
            "The final page has multiple short surahs and must be scrollable to its final line."
        )

        let image = try MushafPageRenderer.renderPage(
            page,
            pageNumber: 604,
            fontDirectory: fontDirectory,
            canvasSize: canvasSize,
            stateProvider: Optional<((QuranWord) -> WordProgressState)>.none
        )

        try writePreviewIfRequested(image)
        XCTAssertLessThan(
            try edgeInkPixelCount(in: image, edgeWidth: 6),
            20,
            "Page 604 should render all final surah lines without clipping at the bottom edge."
        )
    }

    func testFindsCanonicalAyahCenterForLowerShortSurahSelection() throws {
        let page = try makePage(604)
        let centerY = try XCTUnwrap(
            MushafPageRenderer.canonicalAyahCenterY(surah: 113, ayah: 1, in: page)
        )

        XCTAssertGreaterThan(centerY, 700)
        XCTAssertLessThan(centerY, 850)
    }

    private var fontDirectory: URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appending(path: "HifzTracker/Resources/Fonts")
    }

    private func makePage574() throws -> MushafPage {
        try makePage(574)
    }

    private func makePage(_ pageNumber: Int) throws -> MushafPage {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let layoutURL = root.appending(path: "HifzTracker/Resources/Layout/kfgqpc-v4-layout.sqlite")
        let mapping = try PageMapping.loadKFGQPCV4Layout(
            layoutDatabaseURL: layoutURL,
            qpcDatabaseURL: root.appending(path: "qpc-v4.db")
        )
        let repo = try SQLiteQuranRepository(
            databaseURL: root.appending(path: "qpc-v4.db"),
            tanzilURL: root.appending(path: "tanzil/quran-simple-clean.txt"),
            pageMapping: mapping,
            layoutDatabaseURL: layoutURL
        )
        return try repo.mushafPage(pageNumber: pageNumber)
    }

    private func saturatedPixelCount(in image: NSImage) throws -> Int {
        try pixelCount(in: image) { color in
            let maxComponent = max(color.redComponent, color.greenComponent, color.blueComponent)
            let minComponent = min(color.redComponent, color.greenComponent, color.blueComponent)
            return color.alphaComponent > 0.1 && maxComponent > 0.2 && maxComponent - minComponent > 0.15
        }
    }

    private func edgeInkPixelCount(in image: NSImage, edgeWidth: Int) throws -> Int {
        try pixelCount(in: image) { color, x, y, width, height in
            guard x < edgeWidth || y < edgeWidth || x >= width - edgeWidth || y >= height - edgeWidth else {
                return false
            }
            let darkness = 1 - min(color.redComponent, color.greenComponent, color.blueComponent)
            return color.alphaComponent > 0.1 && darkness > 0.25
        }
    }

    private func darkPixelCount(in image: NSImage, rect: CGRect) throws -> Int {
        try pixelCount(in: image) { color, x, y, _, _ in
            guard rect.contains(CGPoint(x: x, y: y)) else { return false }
            let darkness = 1 - min(color.redComponent, color.greenComponent, color.blueComponent)
            return color.alphaComponent > 0.1 && darkness > 0.45
        }
    }

    private func visibleInkPixelCount(in image: NSImage, rect: CGRect) throws -> Int {
        try pixelCount(in: image) { color, x, y, _, _ in
            guard rect.contains(CGPoint(x: x, y: y)) else { return false }
            let distanceFromWhite = max(
                abs(1 - color.redComponent),
                abs(1 - color.greenComponent),
                abs(1 - color.blueComponent)
            )
            return color.alphaComponent > 0.1 && distanceFromWhite > 0.08
        }
    }

    private func ornamentalAyahMarkerPixelCount(in image: NSImage, rect: CGRect) throws -> Int {
        try pixelCount(in: image) { color, x, y, _, _ in
            guard rect.contains(CGPoint(x: x, y: y)) else { return false }

            let isMagentaOrnament = color.redComponent > 0.65
                && color.blueComponent > 0.25
                && color.greenComponent < 0.35
                && color.redComponent - color.greenComponent > 0.35
            let isGreenOrnament = color.greenComponent > 0.45
                && color.redComponent < 0.35
                && color.blueComponent < 0.35
                && color.greenComponent - color.redComponent > 0.25

            return color.alphaComponent > 0.1 && (isMagentaOrnament || isGreenOrnament)
        }
    }

    private func paleProgressHighlightPixelCount(in image: NSImage) throws -> Int {
        try pixelCount(in: image) { color in
            guard color.alphaComponent > 0.1 else { return false }

            let isPaleGreen = color.greenComponent > 0.92
                && color.redComponent > 0.78
                && color.blueComponent > 0.78
                && color.greenComponent - color.redComponent > 0.035
                && color.greenComponent - color.blueComponent > 0.035

            let isPaleBlue = color.blueComponent > 0.92
                && color.redComponent > 0.72
                && color.greenComponent > 0.78
                && color.blueComponent - color.redComponent > 0.055
                && color.blueComponent - color.greenComponent > 0.025

            return isPaleGreen || isPaleBlue
        }
    }

    private func darkRowBands(in image: NSImage, rect: CGRect) throws -> [DarkRowBand] {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            XCTFail("Unable to read rendered image pixels.")
            return []
        }

        var rows: [(y: Int, count: Int)] = []
        let xRange = max(0, Int(rect.minX))..<min(bitmap.pixelsWide, Int(rect.maxX))
        let yRange = max(0, Int(rect.minY))..<min(bitmap.pixelsHigh, Int(rect.maxY))
        for y in yRange {
            var count = 0
            for x in xRange {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }
                let darkness = 1 - min(color.redComponent, color.greenComponent, color.blueComponent)
                if color.alphaComponent > 0.1 && darkness > 0.45 {
                    count += 1
                }
            }
            if count > 20 {
                rows.append((y, count))
            }
        }

        guard let first = rows.first else { return [] }
        var bands: [DarkRowBand] = []
        var start = first.y
        var previous = first.y
        var total = first.count
        var maxCount = first.count
        for row in rows.dropFirst() {
            if row.y <= previous + 1 {
                previous = row.y
                total += row.count
                maxCount = max(maxCount, row.count)
            } else {
                if previous - start > 3 {
                    bands.append(DarkRowBand(start: start, end: previous, total: total, maxCount: maxCount))
                }
                start = row.y
                previous = row.y
                total = row.count
                maxCount = row.count
            }
        }
        if previous - start > 3 {
            bands.append(DarkRowBand(start: start, end: previous, total: total, maxCount: maxCount))
        }
        return bands
    }

    private func pixelCount(in image: NSImage, matching predicate: (NSColor) -> Bool) throws -> Int {
        try pixelCount(in: image) { color, _, _, _, _ in predicate(color) }
    }

    private func pixelCount(
        in image: NSImage,
        matching predicate: (NSColor, Int, Int, Int, Int) -> Bool
    ) throws -> Int {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            XCTFail("Unable to read rendered image pixels.")
            return 0
        }

        var count = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }
                if predicate(color, x, y, bitmap.pixelsWide, bitmap.pixelsHigh) {
                    count += 1
                }
            }
        }
        return count
    }

    private func writePreviewIfRequested(_ image: NSImage) throws {
        guard let outputPath = ProcessInfo.processInfo.environment["HIFZ_RENDER_PREVIEW_PATH"] else {
            return
        }
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Unable to create renderer preview PNG.")
            return
        }
        try png.write(to: URL(fileURLWithPath: outputPath))
    }
}

private struct DarkRowBand {
    var start: Int
    var end: Int
    var total: Int
    var maxCount: Int
}
#endif
