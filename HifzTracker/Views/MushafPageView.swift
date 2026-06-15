import SwiftUI
import HifzCore

struct MushafPageView: View {
    @Bindable var viewModel: RecitationViewModel

    var body: some View {
        VStack(spacing: 0) {
            header

            GeometryReader { proxy in
                let pageAvailableSize = CGSize(
                    width: max(280, proxy.size.width - 48),
                    height: max(360, proxy.size.height - 28)
                )

                VStack(spacing: 0) {
                    if let page = viewModel.mushafPage {
                        FullMushafPageView(
                            page: page,
                            pageNumber: viewModel.pageNumber,
                            availableSize: pageAvailableSize
                        ) { word in
                            viewModel.progressState(for: word)
                        }
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 10)], spacing: 14) {
                                ForEach(viewModel.wordProgress) { word in
                                    WordGlyphView(word: word, pageNumber: viewModel.pageNumber)
                                }
                            }
                            .environment(\.layoutDirection, .rightToLeft)
                            .padding(.horizontal, 34)
                            .padding(.vertical, 28)
                        }
                    }

                    if !viewModel.debugTranscript.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Debug Transcript")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(viewModel.debugTranscript)
                                .textSelection(.enabled)
                                .font(.body)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Hifz Tracker")
                    .font(.title2.weight(.semibold))
                Text("\(viewModel.selectedSurahInfo.arabicName) · \(viewModel.selectedSurahInfo.englishName)")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(viewModel.statusText)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.bar)
    }
}

private struct FullMushafPageView: View {
    var page: MushafPage
    var pageNumber: Int
    var availableSize: CGSize
    var state: (QuranWord) -> WordProgressState

    var body: some View {
        MushafPageCanvasView(page: page, pageNumber: pageNumber, state: state)
            .frame(width: pageSize.width, height: pageSize.height)
            .shadow(color: Color.black.opacity(0.08), radius: 10, y: 3)
    }

    private var pageSize: CGSize {
        MushafPageRenderer
            .fittedPageRect(in: CGRect(origin: .zero, size: availableSize))
            .size
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
