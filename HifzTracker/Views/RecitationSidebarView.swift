import SwiftUI
import HifzCore

struct RecitationSidebarView: View {
    @Bindable var viewModel: RecitationViewModel
    var persistSession: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    RecitationSetupSection(viewModel: viewModel)
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
        SidebarSection(title: "Recitation") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    Text("Surah")
                        .foregroundStyle(.primary)
                        .frame(width: 64, alignment: .leading)

                    Picker("Surah", selection: $viewModel.selectedSurah) {
                        ForEach(SurahCatalog.all) { surah in
                            Text("\(surah.number). \(surah.arabicName)  \(surah.englishName)")
                                .lineLimit(1)
                                .tag(surah.number)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }

                Divider()

                HStack(spacing: 8) {
                    Text("Start ayah")
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Text("\(viewModel.startAyah)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 28, alignment: .trailing)
                    Stepper(
                        "Start ayah",
                        value: $viewModel.startAyah,
                        in: 1...viewModel.selectedSurahInfo.ayahCount
                    )
                    .labelsHidden()
                }

                Divider()

                HStack(spacing: 8) {
                    Text("Hide")
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Toggle("Hide recitation text", isOn: $viewModel.hideRecitationText)
                        .labelsHidden()
                        .help("Hide recitation text until it is recited")
                }
            }
        }
    }
}

private struct SessionSummarySection: View {
    var viewModel: RecitationViewModel

    private var visualState: RecitationVisualState {
        RecitationVisualState(phase: viewModel.snapshot.phase, wordProgress: viewModel.wordProgress)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    RecitationStatusPill(text: viewModel.statusText, visualState: visualState)

                    Spacer(minLength: 8)

                    Text("Page \(viewModel.pageNumber)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(viewModel.selectedSurahInfo.arabicName) · \(viewModel.selectedSurahInfo.englishName)")
                        .font(.callout.weight(.medium))
                        .lineLimit(1)

                    Text("Ayah \(viewModel.displayedAyah)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                VoiceActivityIndicator(isActive: viewModel.isRecording)

                if let message = viewModel.snapshot.message ?? viewModel.assetMessage {
                    Divider()

                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
    }
}

struct VoiceActivityIndicatorMetrics {
    static let circleCount = 4
    static let circleSize: CGFloat = 58
    static let circleSpacing: CGFloat = 16
    static let frameHeight: CGFloat = 86
    static let activeScale: CGFloat = 1.06
    static let stepIntervalNanoseconds: UInt64 = 320_000_000

    static func nextIndex(after index: Int) -> Int {
        (index + 1) % circleCount
    }
}

private struct VoiceActivityIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isActive: Bool
    @State private var highlightedIndex = 0

    var body: some View {
        let shouldAnimate = isActive && !reduceMotion

        HStack(spacing: VoiceActivityIndicatorMetrics.circleSpacing) {
            ForEach(0..<VoiceActivityIndicatorMetrics.circleCount, id: \.self) { index in
                Circle()
                    .fill(color(for: index))
                    .frame(
                        width: VoiceActivityIndicatorMetrics.circleSize,
                        height: VoiceActivityIndicatorMetrics.circleSize
                    )
                    .scaleEffect(isActive && index == highlightedIndex ? VoiceActivityIndicatorMetrics.activeScale : 1.0)
                    .animation(.easeInOut(duration: 0.22), value: highlightedIndex)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: VoiceActivityIndicatorMetrics.frameHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isActive ? "Listening to recitation" : "Recitation idle")
        .task(id: shouldAnimate) {
            highlightedIndex = 0
            guard shouldAnimate else { return }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: VoiceActivityIndicatorMetrics.stepIntervalNanoseconds)
                guard !Task.isCancelled else { return }

                highlightedIndex = VoiceActivityIndicatorMetrics.nextIndex(after: highlightedIndex)
            }
        }
    }

    private func color(for index: Int) -> Color {
        guard isActive, index == highlightedIndex else {
            return Color(nsColor: .separatorColor).opacity(0.78)
        }

        return Color(red: 0.77, green: 0.86, blue: 0.89)
    }
}

private struct RecitationStatusPill: View {
    var text: String
    var visualState: RecitationVisualState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(visualState.tint)
                .frame(width: 7, height: 7)

            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(visualState.tint.opacity(0.10), in: Capsule())
        .overlay {
            Capsule()
                .stroke(visualState.tint.opacity(0.16), lineWidth: 0.5)
        }
        .accessibilityLabel("Status: \(text)")
    }
}

private struct RecitationActionBar: View {
    @Bindable var viewModel: RecitationViewModel
    var persistSession: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button {
                if viewModel.isRecording {
                    persistSession()
                }
                viewModel.toggleRecording()
            } label: {
                Label(primaryTitle, systemImage: primarySystemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut("r", modifiers: [.command])
            .help("\(primaryTitle) (⌘R)")

            HStack(spacing: 8) {
                Button {
                    viewModel.advanceDemoProgress()
                } label: {
                    Label("Advance", systemImage: "forward.frame.fill")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!viewModel.isRecording)
                .help("Manual smoke-test progress until ONNX assets and WAV fixtures are installed")

                Button {
                    viewModel.markDemoCorrection()
                } label: {
                    Label("Correction", systemImage: "exclamationmark.triangle.fill")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!viewModel.isRecording)
                .help("Simulate conservative correction-needed state")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .labelStyle(.titleAndIcon)
        }
    }

    private var primaryTitle: String {
        viewModel.isRecording ? "Stop Recitation" : "Start Recitation"
    }

    private var primarySystemImage: String {
        viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill"
    }
}

private struct SidebarSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.quaternary, lineWidth: 0.5)
            }
        }
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
