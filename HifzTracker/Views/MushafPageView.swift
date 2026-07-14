import SwiftUI
import HifzCore

struct MushafPageView: View {
    @Bindable var viewModel: RecitationViewModel
    @AppStorage("showDebugTranscript") private var showDebugTranscript = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHoveringReader = false
    @FocusState private var focusedPageControl: PageControl?

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
            } isTextVisible: { word in
                viewModel.isMushafTextVisible(for: word)
            } isFallbackTextVisible: { word in
                viewModel.isSelectedAyahWordTextVisible(for: word)
            }
            .overlay {
                HStack {
                    MushafPageNavigationButton(
                        label: "Next Page",
                        systemImage: "chevron.left",
                        shortcut: .leftArrow,
                        action: viewModel.showNextMushafPage
                    )
                    .focused($focusedPageControl, equals: .next)
                    .disabled(viewModel.pageNumber >= 604)

                    Spacer()

                    MushafPageNavigationButton(
                        label: "Previous Page",
                        systemImage: "chevron.right",
                        shortcut: .rightArrow,
                        action: viewModel.showPreviousMushafPage
                    )
                    .focused($focusedPageControl, equals: .previous)
                    .disabled(viewModel.pageNumber <= 1)
                }
                .environment(\.layoutDirection, .leftToRight)
                .padding(.horizontal, 12)
                .opacity(showsPageControls ? 1 : 0)
                .allowsHitTesting(showsPageControls)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: showsPageControls)
            }
            .onHover { isHoveringReader = $0 }

            if showDebugTranscript, !viewModel.debugTranscript.isEmpty {
                DebugTranscriptPanel(transcript: viewModel.debugTranscript)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var showsPageControls: Bool {
        isHoveringReader || focusedPageControl != nil
    }

    private enum PageControl: Hashable {
        case next
        case previous
    }
}

private struct MushafPageNavigationButton: View {
    @Environment(\.isEnabled) private var isEnabled

    var label: String
    var systemImage: String
    var shortcut: KeyEquivalent
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .frame(width: 44, height: 72)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.quaternary, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .opacity(isEnabled ? 1 : 0.35)
        .keyboardShortcut(shortcut, modifiers: [])
        .help("\(label) (\(shortcut == .leftArrow ? "←" : "→"))")
        .accessibilityLabel(label)
    }
}

private struct MushafContentView: View {
    var page: MushafPage?
    var pageNumber: Int
    var selectedSurah: Int
    var focusAyah: Int
    var wordProgress: [WordProgress]
    var state: (QuranWord) -> WordProgressState
    var isTextVisible: (QuranWord) -> Bool
    var isFallbackTextVisible: (WordProgress) -> Bool

    var body: some View {
        Group {
            if let page {
                MushafPageStage(
                    page: page,
                    pageNumber: pageNumber,
                    selectedSurah: selectedSurah,
                    focusAyah: focusAyah,
                    state: state,
                    isTextVisible: isTextVisible
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
                WordGridFallbackView(
                    words: wordProgress,
                    pageNumber: pageNumber,
                    isTextVisible: isFallbackTextVisible
                )
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
    var isTextVisible: (QuranWord) -> Bool

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
                        isTextVisible: isTextVisible,
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
    var isTextVisible: (QuranWord) -> Bool
    var pageSize: CGSize
    var focusY: CGFloat?

    var body: some View {
        ZStack(alignment: .topLeading) {
            MushafPageCanvasView(
                page: page,
                pageNumber: pageNumber,
                state: state,
                isTextVisible: isTextVisible
            )
                .frame(width: pageSize.width, height: pageSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .shadow(color: Color.black.opacity(0.10), radius: 14, y: 4)

            MushafPageNumberFooter(pageNumber: page.pageNumber, pageSize: pageSize)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

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

private struct MushafPageNumberFooter: View {
    var pageNumber: Int
    var pageSize: CGSize

    var body: some View {
        VStack {
            Spacer()

            Text(MushafPageNumberFormatter.string(for: pageNumber))
                .font(.custom(
                    MushafFontResolver.qpcV4TajweedFontName(pageNumber: pageNumber),
                    size: max(10, pageSize.width * 0.032),
                    relativeTo: .caption
                ))
                .foregroundStyle(Color.black.opacity(0.62))
                .lineLimit(1)
                .padding(.bottom, max(8, pageSize.height * 0.012))
        }
        .frame(width: pageSize.width, height: pageSize.height)
    }
}

enum MushafPageNumberFormatter {
    private static let arabicIndicDigits: [Character: Character] = [
        "0": "٠",
        "1": "١",
        "2": "٢",
        "3": "٣",
        "4": "٤",
        "5": "٥",
        "6": "٦",
        "7": "٧",
        "8": "٨",
        "9": "٩"
    ]

    static func string(for pageNumber: Int) -> String {
        String(pageNumber).map { digit in
            arabicIndicDigits[digit] ?? digit
        }
        .reduce(into: "") { result, digit in
            result.append(digit)
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
    var isTextVisible: (WordProgress) -> Bool

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 72, maximum: 112), spacing: 10)],
                spacing: 14
            ) {
                ForEach(words) { word in
                    WordGlyphView(
                        word: word,
                        pageNumber: pageNumber,
                        isTextVisible: isTextVisible(word)
                    )
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
    var isTextVisible = true

    private var presentation: MushafWordGlyphPresentation {
        MushafWordGlyphPresentation(word: word, isTextVisible: isTextVisible)
    }

    var body: some View {
        Text(presentation.displayText)
            .font(.custom(MushafFontResolver.qpcV4TajweedFontName(pageNumber: pageNumber), size: 42, relativeTo: .largeTitle))
            .frame(minWidth: 64, minHeight: 58)
            .padding(.horizontal, 8)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(border, lineWidth: presentation.isHighlighted ? 1.5 : 0)
            }
            .help(presentation.help)
    }

    private var background: Color {
        guard presentation.isTextVisible else { return .clear }

        switch word.state {
        case .completed: return Color.green.opacity(0.18)
        case .current: return Color.accentColor.opacity(0.18)
        case .provisional: return Color.orange.opacity(0.14)
        case .uncertain: return Color.yellow.opacity(0.18)
        case .correctionNeeded: return Color.red.opacity(0.18)
        case .pending: return Color.clear
        }
    }

    private var border: Color {
        guard presentation.isTextVisible else { return .clear }

        switch word.state {
        case .completed: return .green
        case .current: return .accentColor
        case .provisional: return .orange
        case .uncertain: return .yellow
        case .correctionNeeded: return .red
        case .pending: return .clear
        }
    }
}

struct MushafWordGlyphPresentation {
    var word: WordProgress
    var isTextVisible: Bool

    var displayText: String {
        isTextVisible ? word.text : ""
    }

    var isHighlighted: Bool {
        isTextVisible && word.state != .pending
    }

    var help: String {
        guard isTextVisible else { return "Hidden" }

        switch word.state {
        case .completed: return "Completed"
        case .current: return "Current word"
        case .provisional: return "Provisional"
        case .uncertain: return "Uncertain"
        case .correctionNeeded: return "Correction needed"
        case .pending: return "Pending"
        }
    }
}
