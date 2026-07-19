import AppKit
import SwiftUI
import HifzCore
import OSLog

private let mushafLogger = Logger(subsystem: "dev.mostafa.HifzTracker", category: "Mushaf")
private let mushafSignposter = OSSignposter(logger: mushafLogger)

struct MushafPageCanvasView: NSViewRepresentable {
    var page: MushafPage
    var pageNumber: Int
    var state: (QuranWord) -> WordProgressState
    var isTextVisible: (QuranWord) -> Bool = { _ in true }

    func makeNSView(context: Context) -> MushafPageDrawingView {
        let view = MushafPageDrawingView()
        view.update(
            page: page,
            pageNumber: pageNumber,
            presentation: presentation,
            fontDirectory: Bundle.main.url(forResource: "Fonts", withExtension: nil)
        )
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ nsView: MushafPageDrawingView, context: Context) {
        nsView.update(
            page: page,
            pageNumber: pageNumber,
            presentation: presentation,
            fontDirectory: Bundle.main.url(forResource: "Fonts", withExtension: nil)
        )
    }

    private var presentation: MushafPagePresentation {
        MushafPagePresentation(page: page, state: state, isTextVisible: isTextVisible)
    }
}

struct MushafPagePresentation: Equatable {
    struct Word: Equatable {
        var state: WordProgressState
        var isTextVisible: Bool
    }

    private var wordsByLocation: [String: Word]

    init(
        page: MushafPage,
        state: (QuranWord) -> WordProgressState,
        isTextVisible: (QuranWord) -> Bool
    ) {
        wordsByLocation = Dictionary(uniqueKeysWithValues: page.lines.flatMap(\.words).map { word in
            (word.location, Word(state: state(word), isTextVisible: isTextVisible(word)))
        })
    }

    func state(for word: QuranWord) -> WordProgressState {
        wordsByLocation[word.location]?.state ?? .pending
    }

    func isTextVisible(for word: QuranWord) -> Bool {
        wordsByLocation[word.location]?.isTextVisible ?? true
    }
}

final class MushafPageDrawingView: NSView {
    private var page: MushafPage?
    private var pageNumber = 1
    private var presentation: MushafPagePresentation?
    private var fontDirectory: URL?

    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override func setFrameSize(_ newSize: NSSize) {
        let sizeChanged = frame.size != newSize
        super.setFrameSize(newSize)
        if sizeChanged {
            needsDisplay = true
        }
    }

    @discardableResult
    func update(
        page: MushafPage,
        pageNumber: Int,
        presentation: MushafPagePresentation,
        fontDirectory: URL?
    ) -> Bool {
        guard self.page != page
                || self.pageNumber != pageNumber
                || self.presentation != presentation
                || self.fontDirectory != fontDirectory else {
            return false
        }

        self.page = page
        self.pageNumber = pageNumber
        self.presentation = presentation
        self.fontDirectory = fontDirectory
        needsDisplay = true
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        let interval = mushafSignposter.beginInterval("MushafPageDraw")
        defer { mushafSignposter.endInterval("MushafPageDraw", interval) }

        super.draw(dirtyRect)
        NSColor.white.setFill()
        bounds.fill()

        guard let page, let presentation, let fontDirectory else { return }
        do {
            try MushafPageRenderer.drawPage(
                page,
                pageNumber: pageNumber,
                fontDirectory: fontDirectory,
                in: bounds,
                stateProvider: presentation.state,
                visibilityProvider: presentation.isTextVisible
            )
        } catch {
            drawRenderError(in: bounds)
        }
    }

    private func drawRenderError(in rect: NSRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: NSColor.systemRed,
            .paragraphStyle: paragraph
        ]
        NSAttributedString(string: "Unable to render Mushaf page", attributes: attributes).draw(in: rect)
    }
}
