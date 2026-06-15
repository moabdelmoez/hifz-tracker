import SwiftUI
import HifzCore

struct MushafPageView: View {
    @Bindable var viewModel: RecitationViewModel
    @AppStorage("showDebugTranscript") private var showDebugTranscript = true

    var body: some View {
        VStack(spacing: 0) {
            MushafContentView(
                page: viewModel.mushafPage,
                pageNumber: viewModel.pageNumber,
                selectedSurah: viewModel.selectedSurah,
                focusAyah: viewModel.focusedAyah,
                wordProgress: viewModel.wordProgress
            ) { word in
                viewModel.progressState(for: word)
            }

            if showDebugTranscript, !viewModel.debugTranscript.isEmpty {
                DebugTranscriptPanel(transcript: viewModel.debugTranscript)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct MushafContentView: View {
    var page: MushafPage?
    var pageNumber: Int
    var selectedSurah: Int
    var focusAyah: Int
    var wordProgress: [WordProgress]
    var state: (QuranWord) -> WordProgressState

    var body: some View {
        Group {
            if let page {
                MushafPageStage(
                    page: page,
                    pageNumber: pageNumber,
                    selectedSurah: selectedSurah,
                    focusAyah: focusAyah,
                    state: state
                )
                .id(page.pageNumber)
                .transition(.opacity)
            } else if wordProgress.isEmpty {
                ContentUnavailableView(
                    "Mushaf Unavailable",
                    systemImage: "book.closed",
                    description: Text("Install the bundled Mushaf resources to render page-aware recitation.")
                )
            } else {
                WordGridFallbackView(words: wordProgress, pageNumber: pageNumber)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.18), value: pageNumber)
    }
}

private struct MushafPageStage: View {
    var page: MushafPage
    var pageNumber: Int
    var selectedSurah: Int
    var focusAyah: Int
    var state: (QuranWord) -> WordProgressState

    var body: some View {
        GeometryReader { proxy in
            let metrics = MushafViewportMetrics(
                containerSize: proxy.size,
                canonicalContentSize: MushafPageRenderer.canonicalContentSize(for: page)
            )
            let focusY = focusCanonicalY.map(metrics.scaledCanonicalY)

            ScrollViewReader { scrollProxy in
                ScrollView(.vertical) {
                    MushafPageCanvasStack(
                        page: page,
                        pageNumber: pageNumber,
                        state: state,
                        pageSize: metrics.pageSize,
                        focusY: focusY
                    )
                    .padding(metrics.contentPadding)
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .onAppear {
                    scrollToFocusedAyah(scrollProxy)
                }
                .onChange(of: focusIdentity) {
                    scrollToFocusedAyah(scrollProxy)
                }
                .onChange(of: metrics.pageSize) {
                    scrollToFocusedAyah(scrollProxy)
                }
            }
        }
    }

    private var focusIdentity: String {
        "\(page.pageNumber)-\(selectedSurah)-\(focusAyah)"
    }

    private var focusCanonicalY: CGFloat? {
        MushafPageRenderer.canonicalAyahCenterY(surah: selectedSurah, ayah: focusAyah, in: page)
    }

    private func scrollToFocusedAyah(_ scrollProxy: ScrollViewProxy) {
        guard focusCanonicalY != nil else { return }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.16)) {
                scrollProxy.scrollTo(MushafFocusMarker.selectedAyah, anchor: .center)
            }
        }
    }
}

private enum MushafFocusMarker {
    static let selectedAyah = "selected-ayah"
}

private struct MushafPageCanvasStack: View {
    var page: MushafPage
    var pageNumber: Int
    var state: (QuranWord) -> WordProgressState
    var pageSize: CGSize
    var focusY: CGFloat?

    var body: some View {
        ZStack(alignment: .topLeading) {
            MushafPageCanvasView(page: page, pageNumber: pageNumber, state: state)
                .frame(width: pageSize.width, height: pageSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .shadow(color: Color.black.opacity(0.10), radius: 14, y: 4)

            if let focusY {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: max(0, focusY))
                    Color.clear
                        .frame(width: 1, height: 1)
                        .id(MushafFocusMarker.selectedAyah)
                    Spacer(minLength: 0)
                }
                .frame(width: pageSize.width, height: pageSize.height, alignment: .top)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }
}

struct MushafViewportMetrics {
    var containerSize: CGSize
    var canonicalContentSize = MushafPageRenderer.canonicalPageSize

    var availableSize: CGSize {
        CGSize(
            width: max(1, containerSize.width - baseInsets.leading - baseInsets.trailing),
            height: max(1, containerSize.height - baseInsets.top - baseInsets.bottom)
        )
    }

    var pageSize: CGSize {
        let width = min(max(availableSize.width, 1), canonicalContentSize.width)

        return CGSize(
            width: width,
            height: width * canonicalContentSize.height / canonicalContentSize.width
        )
    }

    var pageScale: CGFloat {
        pageSize.width / canonicalContentSize.width
    }

    var contentPadding: EdgeInsets {
        EdgeInsets(
            top: baseInsets.top + verticalCenteringPadding,
            leading: baseInsets.leading + horizontalCenteringPadding,
            bottom: baseInsets.bottom + verticalCenteringPadding,
            trailing: baseInsets.trailing + horizontalCenteringPadding
        )
    }

    func scaledCanonicalY(_ y: CGFloat) -> CGFloat {
        y * pageScale
    }

    func centeredScrollOffset(forCanonicalY y: CGFloat) -> CGFloat {
        let markerY = contentPadding.top + scaledCanonicalY(y)
        let contentHeight = contentPadding.top + pageSize.height + contentPadding.bottom
        let maximumOffset = max(0, contentHeight - containerSize.height)
        return min(max(0, markerY - containerSize.height / 2), maximumOffset)
    }

    private var baseInsets: EdgeInsets {
        let horizontal = min(max(containerSize.width * 0.04, 14), 56)
        let vertical = min(max(containerSize.height * 0.025, 12), 32)
        return EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }

    private var horizontalCenteringPadding: CGFloat {
        max(0, (availableSize.width - pageSize.width) / 2)
    }

    private var verticalCenteringPadding: CGFloat {
        max(0, (availableSize.height - pageSize.height) / 2)
    }
}

private struct WordGridFallbackView: View {
    var words: [WordProgress]
    var pageNumber: Int

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 72, maximum: 112), spacing: 10)],
                spacing: 14
            ) {
                ForEach(words) { word in
                    WordGlyphView(word: word, pageNumber: pageNumber)
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct DebugTranscriptPanel: View {
    var transcript: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Debug Transcript", systemImage: "waveform")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView {
                Text(transcript)
                    .textSelection(.enabled)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 88)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

private struct WordGlyphView: View {
    var word: WordProgress
    var pageNumber: Int = 1

    var body: some View {
        Text(word.text)
            .font(.custom(MushafFontResolver.qpcV4Tajweed.fontName(pageNumber: pageNumber), size: 42, relativeTo: .largeTitle))
            .frame(minWidth: 64, minHeight: 58)
            .padding(.horizontal, 8)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(border, lineWidth: word.state == .pending ? 0 : 1.5)
            }
            .help(help)
    }

    private var background: Color {
        switch word.state {
        case .completed: Color.green.opacity(0.18)
        case .current: Color.accentColor.opacity(0.18)
        case .uncertain: Color.yellow.opacity(0.18)
        case .correctionNeeded: Color.red.opacity(0.18)
        case .pending: Color.clear
        }
    }

    private var border: Color {
        switch word.state {
        case .completed: .green
        case .current: .accentColor
        case .uncertain: .yellow
        case .correctionNeeded: .red
        case .pending: .clear
        }
    }

    private var help: String {
        switch word.state {
        case .completed: "Completed"
        case .current: "Current word"
        case .uncertain: "Uncertain"
        case .correctionNeeded: "Correction needed"
        case .pending: "Pending"
        }
    }
}
