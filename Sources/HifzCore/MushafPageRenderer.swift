#if canImport(AppKit)
import AppKit
import CoreText

public enum MushafPageRendererError: Error, Equatable {
    case missingFontFile(String)
    case unavailableFont(String)
}

public enum MushafDisplayLine: Equatable, Sendable {
    case surahHeader(frameToken: String, surahToken: String, iconToken: String)
    case bismillah(glyph: String)
    case ayah(glyphText: String)
}

public enum MushafPageRenderer {
    public static let canonicalPageSize = CGSize(width: 1_024, height: 1_366)
    public static let canonicalPageAspectRatio = canonicalPageSize.width / canonicalPageSize.height

    public static func glyphText(for line: MushafPageLine) -> String {
        line.words.map(\.text).joined()
    }

    public static func displayLine(for line: MushafPageLine) -> MushafDisplayLine {
        switch line.lineType {
        case .surahName:
            let surahToken = String(format: "surah%03d", line.surahNumber ?? 0)
            return .surahHeader(frameToken: "header", surahToken: surahToken, iconToken: "surah-icon")
        case .basmallah:
            return .bismillah(glyph: "﷽")
        case .ayah, .unknown:
            return .ayah(glyphText: glyphText(for: line))
        }
    }

    public static func fittedPageRect(in bounds: CGRect) -> CGRect {
        guard bounds.width > 0, bounds.height > 0 else { return .zero }

        let scale = min(bounds.width / canonicalPageSize.width, bounds.height / canonicalPageSize.height)
        let size = CGSize(width: canonicalPageSize.width * scale, height: canonicalPageSize.height * scale)
        return CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    public static func renderPage(
        _ page: MushafPage,
        pageNumber: Int,
        fontDirectory: URL,
        canvasSize: CGSize,
        stateProvider: ((QuranWord) -> WordProgressState)?
    ) throws -> NSImage {
        let image = NSImage(size: canvasSize, flipped: true) { rect in
            do {
                try drawPage(
                    page,
                    pageNumber: pageNumber,
                    fontDirectory: fontDirectory,
                    in: rect,
                    stateProvider: stateProvider
                )
                return true
            } catch {
                return false
            }
        }
        image.cacheMode = .always
        return image
    }

    public static func drawPage(
        _ page: MushafPage,
        pageNumber: Int,
        fontDirectory: URL,
        in bounds: CGRect,
        stateProvider: ((QuranWord) -> WordProgressState)?
    ) throws {
        let pageRect = fittedPageRect(in: bounds)
        guard pageRect.width > 0, pageRect.height > 0 else { return }

        NSColor.white.setFill()
        pageRect.fill()

        let scale = pageRect.width / canonicalPageSize.width
        let hasOpeningHeader = page.lines.contains { $0.lineType == .surahName || $0.lineType == .basmallah }

        for line in page.lines.sorted(by: { $0.lineNumber < $1.lineNumber }) {
            switch displayLine(for: line) {
            case .surahHeader(let frameToken, let surahToken, let iconToken):
                try drawQULSurahHeader(
                    frameToken: frameToken,
                    surahToken: surahToken,
                    iconToken: iconToken,
                    pageRect: pageRect,
                    scale: scale,
                    fontDirectory: fontDirectory
                )
            case .bismillah(let glyph):
                try drawQULBismillah(
                    glyph,
                    pageRect: pageRect,
                    scale: scale,
                    fontDirectory: fontDirectory
                )
            case .ayah:
                let lineRect = canonicalAyahLineRect(
                    lineNumber: line.lineNumber,
                    hasOpeningHeader: hasOpeningHeader
                )
                .scaled(from: pageRect.origin, by: scale)

                try drawLine(
                    line,
                    pageNumber: pageNumber,
                    fontDirectory: fontDirectory,
                    in: lineRect,
                    fontSize: canonicalAyahFontSize(hasOpeningHeader: hasOpeningHeader) * scale,
                    stateProvider: stateProvider
                )
            }
        }
    }

    public static func renderLine(
        _ line: MushafPageLine,
        pageNumber: Int,
        fontDirectory: URL,
        canvasSize: CGSize,
        fontSize: CGFloat
    ) throws -> NSImage {
        let image = NSImage(size: canvasSize)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.white.setFill()
        NSRect(origin: .zero, size: canvasSize).fill()

        let lineHeight = fontSize * 1.85
        let rect = NSRect(
            x: 40,
            y: (canvasSize.height - lineHeight) / 2,
            width: canvasSize.width - 80,
            height: lineHeight
        )
        try drawLine(
            line,
            pageNumber: pageNumber,
            fontDirectory: fontDirectory,
            in: rect,
            fontSize: fontSize,
            stateProvider: nil
        )
        return image
    }

    public static func drawLine(
        _ line: MushafPageLine,
        pageNumber: Int,
        fontDirectory: URL,
        in rect: CGRect,
        fontSize: CGFloat,
        stateProvider: ((QuranWord) -> WordProgressState)?
    ) throws {
        guard !line.words.isEmpty else { return }

        let font = try pageFont(pageNumber: pageNumber, fontDirectory: fontDirectory, size: fontSize)
        let attributes = textAttributes(font: font, centered: line.isCentered)
        drawHighlights(for: line, in: rect, attributes: attributes, stateProvider: stateProvider)

        let text = glyphText(for: line)
        NSAttributedString(string: text, attributes: attributes).draw(in: rect)
    }

    public static func pageFont(pageNumber: Int, fontDirectory: URL, size: CGFloat) throws -> NSFont {
        let fontName = MushafFontResolver.qpcV4Tajweed.fontName(pageNumber: pageNumber)
        if let font = NSFont(name: fontName, size: size) {
            return font
        }

        let fontURL = fontDirectory.appending(path: MushafFontResolver.qpcV4Tajweed.fontFileName(pageNumber: pageNumber))
        guard FileManager.default.fileExists(atPath: fontURL.path) else {
            throw MushafPageRendererError.missingFontFile(fontURL.path)
        }

        var registrationError: Unmanaged<CFError>?
        _ = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &registrationError)

        guard let font = NSFont(name: fontName, size: size) else {
            throw MushafPageRendererError.unavailableFont(fontName)
        }
        return font
    }

    private static func textAttributes(font: NSFont, centered: Bool) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = centered ? .center : .right
        paragraph.baseWritingDirection = .rightToLeft
        paragraph.lineBreakMode = .byClipping
        return [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .ligature: 1,
            .paragraphStyle: paragraph
        ]
    }

    private static func drawHighlights(
        for line: MushafPageLine,
        in rect: CGRect,
        attributes: [NSAttributedString.Key: Any],
        stateProvider: ((QuranWord) -> WordProgressState)?
    ) {
        guard let stateProvider else { return }

        var rightEdge = rect.maxX
        for word in line.words {
            let wordWidth = (word.text as NSString).size(withAttributes: attributes).width
            let wordRect = CGRect(
                x: rightEdge - wordWidth - 4,
                y: rect.midY - rect.height * 0.24,
                width: wordWidth + 8,
                height: rect.height * 0.48
            )
            drawHighlight(for: stateProvider(word), in: wordRect)
            rightEdge -= wordWidth
        }
    }

    private static func drawHighlight(for state: WordProgressState, in rect: CGRect) {
        let color: NSColor
        switch state {
        case .completed:
            color = NSColor.systemGreen.withAlphaComponent(0.16)
        case .current:
            color = NSColor.controlAccentColor.withAlphaComponent(0.18)
        case .uncertain:
            color = NSColor.systemYellow.withAlphaComponent(0.2)
        case .correctionNeeded:
            color = NSColor.systemRed.withAlphaComponent(0.18)
        case .pending:
            return
        }

        color.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5).fill()
    }

    private static func drawQULSurahHeader(
        frameToken: String,
        surahToken: String,
        iconToken: String,
        pageRect: CGRect,
        scale: CGFloat,
        fontDirectory: URL
    ) throws {
        let frameFont = try bundledFont(
            candidates: ["quran-common"],
            fileNames: ["quran-common.ttf"],
            fontDirectory: fontDirectory,
            size: 112 * scale
        )
        let titleFont = try bundledFont(
            candidates: ["surah-name-v4"],
            fileNames: ["surah-name-v4.ttf"],
            fontDirectory: fontDirectory,
            size: 50 * scale
        )

        drawCenteredToken(
            frameToken,
            in: CGRect(x: 62, y: 18, width: 900, height: 126).scaled(from: pageRect.origin, by: scale),
            font: frameFont
        )
        drawCenteredToken(
            "\(surahToken) \(iconToken)",
            in: CGRect(x: 360, y: 58, width: 304, height: 56).scaled(from: pageRect.origin, by: scale),
            font: titleFont
        )
    }

    private static func drawQULBismillah(
        _ glyph: String,
        pageRect: CGRect,
        scale: CGFloat,
        fontDirectory: URL
    ) throws {
        let font = try bundledFont(
            candidates: ["bismillah", "icomoon"],
            fileNames: ["bismillah.ttf", "bismillah.woff2"],
            fontDirectory: fontDirectory,
            size: 64 * scale
        )
        drawCenteredToken(
            glyph,
            in: CGRect(x: 246, y: 154, width: 532, height: 78).scaled(from: pageRect.origin, by: scale),
            font: font
        )
    }

    private static func drawCenteredToken(_ text: String, in rect: CGRect, font: NSFont) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.baseWritingDirection = .rightToLeft
        paragraph.lineBreakMode = .byClipping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .ligature: 1,
            .paragraphStyle: paragraph
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let drawRect = CGRect(
            x: rect.midX - textSize.width / 2,
            y: rect.midY - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        NSAttributedString(string: text, attributes: attributes).draw(in: drawRect)
    }

    private static func bundledFont(
        candidates: [String],
        fileNames: [String],
        fontDirectory: URL,
        size: CGFloat
    ) throws -> NSFont {
        for candidate in candidates {
            if let font = NSFont(name: candidate, size: size) {
                return font
            }
        }

        for fileName in fileNames {
            let fontURL = fontDirectory.appending(path: fileName)
            guard FileManager.default.fileExists(atPath: fontURL.path) else {
                continue
            }
            var registrationError: Unmanaged<CFError>?
            _ = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &registrationError)
        }

        for candidate in candidates {
            if let font = NSFont(name: candidate, size: size) {
                return font
            }
        }

        let expectedPath = fontDirectory.appending(path: fileNames.first ?? "").path
        if !FileManager.default.fileExists(atPath: expectedPath) {
            throw MushafPageRendererError.missingFontFile(expectedPath)
        }
        throw MushafPageRendererError.unavailableFont(candidates.first ?? "")
    }

    private static func canonicalAyahLineRect(lineNumber: Int, hasOpeningHeader: Bool) -> CGRect {
        if hasOpeningHeader {
            let index = max(0, lineNumber - 3)
            return CGRect(x: 52, y: 246 + CGFloat(index) * 80.5, width: 920, height: 130)
        }

        let index = max(0, lineNumber - 1)
        return CGRect(x: 52, y: 46 + CGFloat(index) * 88, width: 920, height: 130)
    }

    private static func canonicalAyahFontSize(hasOpeningHeader: Bool) -> CGFloat {
        hasOpeningHeader ? 54 : 51
    }
}

private extension CGRect {
    func scaled(from origin: CGPoint, by scale: CGFloat) -> CGRect {
        CGRect(
            x: origin.x + minX * scale,
            y: origin.y + minY * scale,
            width: width * scale,
            height: height * scale
        )
    }
}

private extension NSBezierPath {
    func stroke(lineWidth: CGFloat) {
        self.lineWidth = lineWidth
        stroke()
    }
}
#endif
