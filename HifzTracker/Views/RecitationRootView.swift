import SwiftData
import SwiftUI
import HifzCore

struct RecitationRootView: View {
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
                .navigationTitle("Hifz Tracker")
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            toggleSidebar()
                        } label: {
                            Label("Toggle Sidebar", systemImage: "sidebar.left")
                        }
                        .help("Toggle Sidebar")
                    }

                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 1) {
                            Text("Hifz Tracker")
                                .font(.headline)
                            Text("\(viewModel.selectedSurahInfo.arabicName) · \(viewModel.selectedSurahInfo.englishName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .lineLimit(1)
                        .accessibilityElement(children: .combine)
                    }

                    ToolbarItem(placement: .status) {
                        RecitationStatusBadge(text: viewModel.statusText, color: statusColor)
                    }

                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            openWindow(id: "dashboard")
                        } label: {
                            Label("Dashboard", systemImage: "chart.bar.xaxis")
                        }
                        .help("Open Dashboard")

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
    }

    private func persistCurrentSession() {
        guard let record = viewModel.makeSessionRecord() else { return }
        modelContext.insert(StoredSessionRecord(record: record))
        try? modelContext.save()
    }

    private func toggleSidebar() {
        withAnimation(.smooth(duration: 0.18)) {
            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
        }
    }

    private var statusColor: Color {
        switch viewModel.snapshot.phase {
        case .progressing, .locked, .listening:
            .green
        case .correctionNeeded, .failed:
            .red
        case .uncertain, .findingPlace, .requestingPermission:
            .yellow
        default:
            .secondary
        }
    }
}

private struct RecitationStatusBadge: View {
    var text: String
    var color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            Text(text)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: Capsule())
        .accessibilityLabel("Status: \(text)")
    }
}
