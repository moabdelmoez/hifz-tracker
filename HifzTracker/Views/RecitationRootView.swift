import SwiftData
import SwiftUI
import HifzCore

struct RecitationRootView: View {
    let registerWindowAction: (OpenWindowAction) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @State private var viewModel = RecitationViewModel()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            RecitationSidebarView(viewModel: viewModel) {
                persistCurrentSession()
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 288, max: 340)
        } detail: {
            MushafPageView(viewModel: viewModel)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        let surah = SurahCatalog.surah(viewModel.readerPosition.surah) ?? viewModel.selectedSurahInfo
                        Text("\(surah.arabicName) · \(surah.englishName)")
                            .font(.headline)
                            .lineLimit(1)
                    }

                    ToolbarItem(placement: .status) {
                        RecitationStatusLabel(
                            text: viewModel.statusText,
                            color: RecitationVisualState(
                                phase: viewModel.snapshot.phase,
                                wordProgress: viewModel.wordProgress
                            ).tint
                        )
                    }

                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            openWindow(id: "progress")
                        } label: {
                            Label("Progress", systemImage: "chart.bar.xaxis")
                        }
                        .help("Open Progress")

                        Button {
                            openSettings()
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .help("Open Settings")
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            registerWindowAction(openWindow)
        }
    }

    private func persistCurrentSession() {
        guard let record = viewModel.makeSessionRecord() else { return }
        modelContext.insert(StoredSessionRecord(record: record))
        try? modelContext.save()
    }

}

private struct RecitationStatusLabel: View {
    var text: String
    var color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)

            Text(text)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .accessibilityLabel("Status: \(text)")
    }
}
