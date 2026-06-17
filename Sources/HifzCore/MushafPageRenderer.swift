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

    public static func canonicalContentSize(for page: MushafPage) -> CGSize {
        canonicalContentSize(lineLayout: MushafLineLayout(lines: page.lines))
    }

    public static func canonicalAyahCenterY(surah: Int, ayah: Int, in page: MushafPage) -> CGFloat? {
        let lineLayout = MushafLineLayout(lines: page.lines)
        guard let line = page.lines.sorted(by: { $0.lineNumber < $1.lineNumber }).first(where: { line in
            line.words.contains { $0.surah == surah && $0.ayah == ayah }
        }) else {
            return nil
        }

        return lineLayout.yPosition(for: line) + canonicalAyahLineRect(y: 0).height / 2
    }

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
        fittedPageRect(in: bounds, canonicalSize: canonicalPageSize)
    }

    private static func fittedPageRect(in bounds: CGRect, canonicalSize: CGSize) -> CGRect {
        guard bounds.width > 0, bounds.height > 0 else { return .zero }

        let scale = min(bounds.width / canonicalSize.width, bounds.height / canonicalSize.height)
        let size = CGSize(width: canonicalSize.width * scale, height: canonicalSize.height * scale)
        return CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private static func canonicalContentSize(lineLayout: MushafLineLayout) -> CGSize {
        CGSize(
            width: canonicalPageSize.width,
            height: max(canonicalPageSize.height, lineLayout.requiredContentHeight)
        )
    }

    public static func renderPage(
        _ page: MushafPage,
        pageNumber: Int,
        fontDirectory: URL,
        canvasSize: CGSize,
        stateProvider: ((QuranWord) -> WordProgressState)?,
        visibilityProvider: ((QuranWord) -> Bool)? = nil
    ) throws -> NSImage {
        let image = NSImage(size: canvasSize, flipped: true) { rect in
            do {
                try drawPage(
                    page,
                    pageNumber: pageNumber,
                    fontDirectory: fontDirectory,
                    in: rect,
                    stateProvider: stateProvider,
                    visibilityProvider: visibilityProvider
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
        stateProvider: ((QuranWord) -> WordProgressState)?,
        visibilityProvider: ((QuranWord) -> Bool)? = nil
    ) throws {
        let lineLayout = MushafLineLayout(lines: page.lines)
        let pageRect = fittedPageRect(in: bounds, canonicalSize: canonicalContentSize(lineLayout: lineLayout))
        guard pageRect.width > 0, pageRect.height > 0 else { return }

        NSColor.white.setFill()
        pageRect.fill()

        let scale = pageRect.width / canonicalPageSize.width

        for line in page.lines.sorted(by: { $0.lineNumber < $1.lineNumber }) {
            switch displayLine(for: line) {
            case .surahHeader(let frameToken, let surahToken, let iconToken):
                try drawQULSurahHeader(
                    frameToken: frameToken,
                    surahToken: surahToken,
                    iconToken: iconToken,
                    y: lineLayout.yPosition(for: line),
                    pageRect: pageRect,
                    scale: scale,
                    fontDirectory: fontDirectory
                )
            case .bismillah(let glyph):
                try drawQULBismillah(
                    glyph,
                    y: lineLayout.yPosition(for: line),
                    pageRect: pageRect,
                    scale: scale,
                    fontDirectory: fontDirectory
                )
            case .ayah:
                let lineRect = canonicalAyahLineRect(
                    y: lineLayout.yPosition(for: line)
                )
                .scaled(from: pageRect.origin, by: scale)

                try drawLine(
                    line,
                    pageNumber: pageNumber,
                    fontDirectory: fontDirectory,
                    in: lineRect,
                    fontSize: canonicalAyahFontSize(lineLayout: lineLayout) * scale,
                    stateProvider: stateProvider,
                    visibilityProvider: visibilityProvider
                )
            }
        }
    }

    public static func renderLine(
        _ line: MushafPageLine,
        pageNumber: Int,
        fontDirectory: URL,
        canvasSize: CGSize,
        fontSize: CGFloat,
        visibilityProvider: ((QuranWord) -> Bool)? = nil
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
            stateProvider: nil,
            visibilityProvider: visibilityProvider
        )
        return image
    }

    public static func drawLine(
        _ line: MushafPageLine,
        pageNumber: Int,
        fontDirectory: URL,
        in rect: CGRect,
        fontSize: CGFloat,
        stateProvider: ((QuranWord) -> WordProgressState)?,
        visibilityProvider: ((QuranWord) -> Bool)? = nil
    ) throws {
        guard !line.words.isEmpty else { return }

        let font = try pageFont(pageNumber: pageNumber, fontDirectory: fontDirectory, size: fontSize)
        let attributes = textAttributes(font: font, centered: line.isCentered)
        drawHighlights(
            for: line,
            in: rect,
            attributes: attributes,
            stateProvider: stateProvider,
            visibilityProvider: visibilityProvider
        )

        if hasHiddenWords(in: line, visibilityProvider: visibilityProvider) {
            drawVisibleWords(for: line, in: rect, attributes: attributes, visibilityProvider: visibilityProvider)
        } else {
            let text = glyphText(for: line)
            NSAttributedString(string: text, attributes: attributes).draw(in: rect)
        }
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
        stateProvider: ((QuranWord) -> WordProgressState)?,
        visibilityProvider: ((QuranWord) -> Bool)?
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
            if isTextVisible(for: word, visibilityProvider: visibilityProvider) {
                drawHighlight(for: stateProvider(word), in: wordRect)
            }
            rightEdge -= wordWidth
        }
    }

    private static func drawVisibleWords(
        for line: MushafPageLine,
        in rect: CGRect,
        attributes: [NSAttributedString.Key: Any],
        visibilityProvider: ((QuranWord) -> Bool)?
    ) {
        var rightEdge = rect.maxX
        for word in line.words {
            let wordWidth = (word.text as NSString).size(withAttributes: attributes).width
            defer { rightEdge -= wordWidth }

            guard isTextVisible(for: word, visibilityProvider: visibilityProvider) else {
                continue
            }

            let wordRect = CGRect(
                x: rightEdge - wordWidth,
                y: rect.minY,
                width: wordWidth,
                height: rect.height
            )
            NSAttributedString(string: word.text, attributes: attributes).draw(in: wordRect)
        }
    }

    private static func hasHiddenWords(
        in line: MushafPageLine,
        visibilityProvider: ((QuranWord) -> Bool)?
    ) -> Bool {
        guard let visibilityProvider else { return false }
        return line.words.contains { !visibilityProvider($0) }
    }

    private static func isTextVisible(
        for word: QuranWord,
        visibilityProvider: ((QuranWord) -> Bool)?
    ) -> Bool {
        visibilityProvider?(word) ?? true
    }

    private static func drawHighlight(for state: WordProgressState, in rect: CGRect) {
        let color: NSColor
        switch state {
        case .completed:
            color = NSColor.systemGreen.withAlphaComponent(0.16)
        case .current:
            color = NSColor.controlAccentColor.withAlphaComponent(0.18)
        case .provisional:
            color = NSColor.systemOrange.withAlphaComponent(0.14)
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
        y: CGFloat,
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
            in: canonicalSurahHeaderRect(y: y).scaled(from: pageRect.origin, by: scale),
            font: frameFont
        )
        drawCenteredToken(
            "\(surahToken) \(iconToken)",
            in: canonicalSurahTitleRect(y: y).scaled(from: pageRect.origin, by: scale),
            font: titleFont
        )
    }

    private static func drawQULBismillah(
        _ glyph: String,
        y: CGFloat,
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
            in: canonicalBismillahRect(y: y).scaled(from: pageRect.origin, by: scale),
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

    private static func canonicalSurahHeaderRect(y: CGFloat) -> CGRect {
        CGRect(x: 62, y: y, width: 900, height: 126)
    }

    private static func canonicalSurahTitleRect(y: CGFloat) -> CGRect {
        CGRect(x: 360, y: y + 40, width: 304, height: 56)
    }

    private static func canonicalBismillahRect(y: CGFloat) -> CGRect {
        return CGRect(x: 246, y: y, width: 532, height: 78)
    }

    private static func canonicalAyahLineRect(y: CGFloat) -> CGRect {
        CGRect(x: 52, y: y, width: 920, height: 130)
    }

    private static func canonicalAyahFontSize(lineLayout: MushafLineLayout) -> CGFloat {
        lineLayout.containsSpecialLines ? 54 : 51
    }
}

private struct MushafLineLayout {
    private static let topHeaderY: CGFloat = 18
    private static let topAyahY: CGFloat = 46
    private static let headerToBismillahStep: CGFloat = 136
    private static let headerToAyahStep: CGFloat = 148
    private static let bismillahToAyahStep: CGFloat = 92
    private static let ayahToAyahStepWithSpecialLines: CGFloat = 80.5
    private static let ayahToAyahStepWithoutSpecialLines: CGFloat = 88
    private static let ayahToHeaderStep: CGFloat = 147
    private static let minimumContentHeight: CGFloat = 1_366
    private static let bottomMargin: CGFloat = 32
    private static let surahHeaderHeight: CGFloat = 126
    private static let bismillahHeight: CGFloat = 78
    private static let ayahLineHeight: CGFloat = 130

    private let yPositionsByLineNumber: [Int: CGFloat]
    let containsSpecialLines: Bool
    let requiredContentHeight: CGFloat

    init(lines: [MushafPageLine]) {
        let sortedLines = lines.sorted { $0.lineNumber < $1.lineNumber }
        containsSpecialLines = sortedLines.contains { $0.lineType == .surahName || $0.lineType == .basmallah }

        var positions: [Int: CGFloat] = [:]
        var previousLine: MushafPageLine?
        var previousY: CGFloat?
        var maximumLineBottom: CGFloat = 0
        for line in sortedLines {
            let y: CGFloat
            if let previousLine, let previousY {
                y = Self.yPosition(after: previousLine, previousY: previousY, before: line, containsSpecialLines: containsSpecialLines)
            } else {
                y = Self.firstLineY(for: line)
            }

            positions[line.lineNumber] = y
            maximumLineBottom = max(maximumLineBottom, Self.bottomY(for: line, y: y))
            previousLine = line
            previousY = y
        }
        yPositionsByLineNumber = positions
        requiredContentHeight = max(Self.minimumContentHeight, maximumLineBottom + Self.bottomMargin)
    }

    func yPosition(for line: MushafPageLine) -> CGFloat {
        yPositionsByLineNumber[line.lineNumber] ?? Self.firstLineY(for: line)
    }

    private static func firstLineY(for line: MushafPageLine) -> CGFloat {
        switch line.lineType {
        case .surahName:
            topHeaderY
        case .basmallah:
            topHeaderY + headerToBismillahStep
        case .ayah, .unknown:
            topAyahY
        }
    }

    private static func bottomY(for line: MushafPageLine, y: CGFloat) -> CGFloat {
        switch line.lineType {
        case .surahName:
            y + surahHeaderHeight
        case .basmallah:
            y + bismillahHeight
        case .ayah, .unknown:
            y + ayahLineHeight
        }
    }

    private static func yPosition(
        after previousLine: MushafPageLine,
        previousY: CGFloat,
        before line: MushafPageLine,
        containsSpecialLines: Bool
    ) -> CGFloat {
        switch (previousLine.lineType, line.lineType) {
        case (.surahName, .basmallah):
            previousY + headerToBismillahStep
        case (.surahName, .ayah), (.surahName, .unknown):
            previousY + headerToAyahStep
        case (.basmallah, .ayah), (.basmallah, .unknown):
            previousY + bismillahToAyahStep
        case (.ayah, .surahName), (.unknown, .surahName):
            previousY + ayahToHeaderStep
        case (.ayah, .ayah), (.ayah, .unknown), (.unknown, .ayah), (.unknown, .unknown):
            previousY + (containsSpecialLines ? ayahToAyahStepWithSpecialLines : ayahToAyahStepWithoutSpecialLines)
        default:
            previousY + (containsSpecialLines ? ayahToAyahStepWithSpecialLines : ayahToAyahStepWithoutSpecialLines)
        }
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
