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

    private var fontDirectory: URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appending(path: "HifzTracker/Resources/Fonts")
    }

    private func makePage574() throws -> MushafPage {
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
        return try repo.mushafPage(pageNumber: 574)
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
#endif
