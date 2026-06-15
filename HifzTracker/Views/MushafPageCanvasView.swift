import AppKit
import SwiftUI
import HifzCore

struct MushafPageCanvasView: NSViewRepresentable {
    var page: MushafPage
    var pageNumber: Int
    var state: (QuranWord) -> WordProgressState

    func makeNSView(context: Context) -> MushafPageDrawingView {
        let view = MushafPageDrawingView()
        view.page = page
        view.pageNumber = pageNumber
        view.stateProvider = state
        view.fontDirectory = Bundle.main.url(forResource: "Fonts", withExtension: nil)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ nsView: MushafPageDrawingView, context: Context) {
        nsView.page = page
        nsView.pageNumber = pageNumber
        nsView.stateProvider = state
        nsView.fontDirectory = Bundle.main.url(forResource: "Fonts", withExtension: nil)
    }
}

final class MushafPageDrawingView: NSView {
    var page: MushafPage? {
        didSet { needsDisplay = true }
    }
    var pageNumber: Int = 1 {
        didSet { needsDisplay = true }
    }
    var stateProvider: ((QuranWord) -> WordProgressState)? {
        didSet { needsDisplay = true }
    }
    var fontDirectory: URL? {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.white.setFill()
        bounds.fill()

        guard let page, let fontDirectory else { return }
        do {
            try MushafPageRenderer.drawPage(
                page,
                pageNumber: pageNumber,
                fontDirectory: fontDirectory,
                in: bounds,
                stateProvider: stateProvider
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
