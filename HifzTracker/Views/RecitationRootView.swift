import SwiftData
import SwiftUI
import HifzCore

struct RecitationRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @State private var viewModel = RecitationViewModel()

    var body: some View {
        NavigationSplitView {
            RecitationSidebarView(viewModel: viewModel) {
                persistCurrentSession()
            }
            .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
        } detail: {
            MushafPageView(viewModel: viewModel)
                .toolbar {
                    ToolbarItemGroup {
                        Button {
                            openWindow(id: "history")
                        } label: {
                            Label("History", systemImage: "clock.arrow.circlepath")
                        }
                        .help("Open History")

                        Button {
                            openSettings()
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .help("Open Settings")
                    }
                }
        }
    }

    private func persistCurrentSession() {
        guard let record = viewModel.makeSessionRecord() else { return }
        modelContext.insert(StoredSessionRecord(record: record))
        try? modelContext.save()
    }
}
