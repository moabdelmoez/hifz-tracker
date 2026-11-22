import SwiftUI
import HifzCore

struct RecitationSidebarView: View {
    @Bindable var viewModel: RecitationViewModel
    var persistSession: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    RecitationSetupSection(viewModel: viewModel)
                    Divider()
                    SessionSummarySection(viewModel: viewModel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 14)
            }

            Divider()
                .opacity(0.6)

            RecitationActionBar(viewModel: viewModel, persistSession: persistSession)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
        }
    }
}

private struct RecitationSetupSection: View {
    @Bindable var viewModel: RecitationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Surah")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityHidden(true)

                Picker("Surah", selection: $viewModel.selectedSurah) {
                    ForEach(SurahCatalog.all) { surah in
                        Text("\(surah.number). \(surah.arabicName)  \(surah.englishName)")
                            .lineLimit(1)
                            .tag(surah.number)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
            }

            LabeledContent {
                Picker("Start ayah", selection: $viewModel.startAyah) {
                    ForEach(1...viewModel.selectedSurahInfo.ayahCount, id: \.self) { ayah in
                        Text("\(ayah)")
                            .tag(ayah)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 64)
            } label: {
                Text("Start ayah")
            }

            Toggle("Hide Ayah", isOn: $viewModel.hideRecitationText)
                .toggleStyle(.switch)
                .help("Reveal each word as you recite it")
        }
    }
}

private struct SessionSummarySection: View {
    var viewModel: RecitationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current position")
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)

            HStack {
                Text("Ayah \(viewModel.displayedAyah)")
                Spacer(minLength: 8)
                Text("Page \(viewModel.pageNumber)")
            }
            .font(.body.monospacedDigit())
            .accessibilityElement(children: .combine)

            if viewModel.isRecording {
                VoiceActivityIndicator()
            }

            if let message = viewModel.snapshot.message ?? viewModel.assetMessage {
                Text(message)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }
}

struct VoiceActivityIndicatorMetrics {
    static let circleCount = 4
    static let circleSize: CGFloat = 42
    static let circleSpacing: CGFloat = 12
    static let frameHeight: CGFloat = 64
    static let activeScale: CGFloat = 1.06
    static let stepIntervalNanoseconds: UInt64 = 320_000_000

    static func nextIndex(after index: Int) -> Int {
        (index + 1) % circleCount
    }
}

private struct VoiceActivityIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var highlightedIndex = 0

    var body: some View {
        HStack(spacing: VoiceActivityIndicatorMetrics.circleSpacing) {
            ForEach(0..<VoiceActivityIndicatorMetrics.circleCount, id: \.self) { index in
                Circle()
                    .fill(color(for: index))
                    .frame(
                        width: VoiceActivityIndicatorMetrics.circleSize,
                        height: VoiceActivityIndicatorMetrics.circleSize
                    )
                    .scaleEffect(index == highlightedIndex ? VoiceActivityIndicatorMetrics.activeScale : 1.0)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: highlightedIndex)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: VoiceActivityIndicatorMetrics.frameHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Listening to recitation")
        .task(id: reduceMotion) {
            highlightedIndex = 0
            guard !reduceMotion else { return }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: VoiceActivityIndicatorMetrics.stepIntervalNanoseconds)
                guard !Task.isCancelled else { return }

                highlightedIndex = VoiceActivityIndicatorMetrics.nextIndex(after: highlightedIndex)
            }
        }
    }

    private func color(for index: Int) -> Color {
        guard index == highlightedIndex else {
            return Color(nsColor: .separatorColor).opacity(0.78)
        }

        return Color(red: 0.77, green: 0.86, blue: 0.89)
    }
}

private struct RecitationActionBar: View {
    @Bindable var viewModel: RecitationViewModel
    var persistSession: () -> Void

    var body: some View {
        Button {
            if viewModel.isRecording {
                persistSession()
            }
            viewModel.toggleRecording()
        } label: {
            Group {
                if isStarting {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityHidden(true)
                        Text(primaryTitle)
                    }
                } else {
                    Label(primaryTitle, systemImage: primarySystemImage)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isStarting)
        .keyboardShortcut("r", modifiers: [.command])
        .help("\(primaryTitle) (⌘R)")
    }

    private var primaryTitle: String {
        if isStarting { return "Starting Recitation…" }
        return viewModel.isRecording ? "Stop Recitation" : "Start Recitation"
    }

    private var primarySystemImage: String {
        viewModel.isRecording ? "stop.fill" : "mic.fill"
    }

    private var isStarting: Bool {
        viewModel.snapshot.phase == .requestingPermission
    }
}

@MainActor
private enum RecitationSidebarPreviewData {
    static func viewModel(
        phase: RecitationPhase,
        isRecording: Bool = false,
        audioLevel: Double = 0,
        completed: Bool = false,
        message: String? = nil
    ) -> RecitationViewModel {
        let viewModel = RecitationViewModel(repository: nil)
        viewModel.selectedSurah = 3
        viewModel.startAyah = 1
        viewModel.snapshot = RecitationSnapshot(
            phase: phase,
            currentAyah: 1,
            currentWord: completed ? nil : 2,
            completedWordCount: completed ? 3 : 1,
            message: message
        )
        viewModel.isRecording = isRecording
        viewModel.audioLevel = audioLevel
        viewModel.assetMessage = nil
        viewModel.wordProgress = [
            WordProgress(wordIndex: 1, text: "الم", state: .completed),
            WordProgress(wordIndex: 2, text: "الله", state: completed ? .completed : .current),
            WordProgress(wordIndex: 3, text: "لا", state: completed ? .completed : .pending)
        ]
        return viewModel
    }
}

#Preview("Ready") {
    RecitationSidebarView(
        viewModel: RecitationSidebarPreviewData.viewModel(phase: .idle),
        persistSession: {}
    )
    .frame(width: 288, height: 680)
}

#Preview("Listening") {
    RecitationSidebarView(
        viewModel: RecitationSidebarPreviewData.viewModel(phase: .listening, isRecording: true, audioLevel: 0.18),
        persistSession: {}
    )
    .frame(width: 288, height: 680)
}

#Preview("Reciting") {
    RecitationSidebarView(
        viewModel: RecitationSidebarPreviewData.viewModel(phase: .progressing, isRecording: true, audioLevel: 0.72),
        persistSession: {}
    )
    .frame(width: 288, height: 680)
}

#Preview("Correction") {
    RecitationSidebarView(
        viewModel: RecitationSidebarPreviewData.viewModel(phase: .correctionNeeded, isRecording: true, audioLevel: 0.44),
        persistSession: {}
    )
    .frame(width: 288, height: 680)
}

#Preview("Stopped") {
    RecitationSidebarView(
        viewModel: RecitationSidebarPreviewData.viewModel(phase: .stopped),
        persistSession: {}
    )
    .frame(width: 288, height: 680)
}

#Preview("Completed") {
    RecitationSidebarView(
        viewModel: RecitationSidebarPreviewData.viewModel(phase: .stopped, completed: true),
        persistSession: {}
    )
    .frame(width: 288, height: 680)
}

#Preview("Failed") {
    RecitationSidebarView(
        viewModel: RecitationSidebarPreviewData.viewModel(
            phase: .failed,
            message: "Microphone permission was denied."
        ),
        persistSession: {}
    )
    .frame(width: 288, height: 680)
}
