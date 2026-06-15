import SwiftUI
import HifzCore

struct RecitationSidebarView: View {
    @Bindable var viewModel: RecitationViewModel
    var persistSession: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Surah")
                    .font(.headline)

                Picker("Surah", selection: $viewModel.selectedSurah) {
                    ForEach(SurahCatalog.all) { surah in
                        Text("\(surah.number). \(surah.arabicName)  \(surah.englishName)")
                            .tag(surah.number)
                    }
                }
                .labelsHidden()

                Stepper(value: $viewModel.startAyah, in: 1...viewModel.selectedSurahInfo.ayahCount) {
                    Text("Start ayah \(viewModel.startAyah)")
                        .monospacedDigit()
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)

                    Text(viewModel.statusText)
                        .font(.headline)
                }

                Text("Page \(viewModel.pageNumber) · \(viewModel.selectedSurahInfo.englishName) \(viewModel.startAyah)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let message = viewModel.snapshot.message ?? viewModel.assetMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Spacer()

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

                HStack {
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
            }
        }
        .padding()
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
