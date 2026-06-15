import SwiftUI
import HifzCore

struct RecitationSidebarView: View {
    @Bindable var viewModel: RecitationViewModel
    var persistSession: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SidebarSection(title: "Recitation") {
                Picker("Surah", selection: $viewModel.selectedSurah) {
                    ForEach(SurahCatalog.all) { surah in
                        Text("\(surah.number). \(surah.arabicName)  \(surah.englishName)")
                            .tag(surah.number)
                    }
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 8) {
                    Text("Start ayah")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(viewModel.startAyah)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 24, alignment: .trailing)
                    Stepper(
                        "Start ayah",
                        value: $viewModel.startAyah,
                        in: 1...viewModel.selectedSurahInfo.ayahCount
                    )
                    .labelsHidden()
                }
            }

            SidebarSection(title: "Session") {
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(viewModel.statusText)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                }

                Text("Page \(viewModel.pageNumber) · \(viewModel.selectedSurahInfo.englishName) \(viewModel.startAyah)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let message = viewModel.snapshot.message ?? viewModel.assetMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }

            Spacer(minLength: 16)

            VStack(spacing: 10) {
                Button {
                    if viewModel.isRecording {
                        persistSession()
                    }
                    viewModel.toggleRecording()
                } label: {
                    Label(viewModel.isRecording ? "Stop Recitation" : "Start Recitation", systemImage: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut("r", modifiers: [.command])
                .help(viewModel.isRecording ? "Stop Recitation (⌘R)" : "Start Recitation (⌘R)")

                HStack(spacing: 8) {
                    Button {
                        viewModel.advanceDemoProgress()
                    } label: {
                        Label("Advance", systemImage: "forward.frame.fill")
                    }
                    .disabled(!viewModel.isRecording)
                    .help("Manual smoke-test progress until ONNX assets and WAV fixtures are installed")

                    Button {
                        viewModel.markDemoCorrection()
                    } label: {
                        Label("Correction", systemImage: "exclamationmark.triangle.fill")
                    }
                    .disabled(!viewModel.isRecording)
                    .help("Simulate conservative correction-needed state")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
    }

    private var statusColor: Color {
        switch viewModel.snapshot.phase {
        case .progressing, .locked, .listening:
            .green
        case .correctionNeeded:
            .red
        case .uncertain, .findingPlace, .requestingPermission:
            .yellow
        case .failed:
            .red
        default:
            .secondary
        }
    }
}

private struct SidebarSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 8) {
                content
            }
        }
    }
}
