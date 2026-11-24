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
            Text("Recitation position")
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)

            HStack {
                Text("Ayah \(viewModel.readerPosition.ayah)")
                Spacer(minLength: 8)
                Text("Viewing page \(viewModel.pageNumber)")
            }
            .font(.body.monospacedDigit())
            .accessibilityElement(children: .combine)

            if let message = viewModel.snapshot.message ?? viewModel.assetMessage {
                Text(message)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
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
        message: String? = nil
    ) -> RecitationViewModel {
        let viewModel = RecitationViewModel(repository: nil)
        viewModel.selectedSurah = 3
        viewModel.startAyah = 1
        viewModel.snapshot = RecitationSnapshot(
            phase: phase,
            message: message
        )
        viewModel.isRecording = isRecording
        viewModel.assetMessage = nil
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

#Preview("Recording") {
    RecitationSidebarView(
        viewModel: RecitationSidebarPreviewData.viewModel(phase: .listening, isRecording: true),
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
