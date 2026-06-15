import SwiftData
import SwiftUI
import HifzCore

struct HistoryWindowView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredSessionRecord.startedAt, order: .reverse) private var records: [StoredSessionRecord]
    @State private var exportMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("History")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    exportHistory()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    resetHistory()
                } label: {
                    Label("Reset", systemImage: "trash")
                }
            }
            .padding()
            .background(.bar)

            if records.isEmpty {
                ContentUnavailableView("No Sessions", systemImage: "clock", description: Text("Completed recitation sessions will appear here."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(records) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label(for: record))
                            .font(.headline)
                        Text("\(record.completedWordCount) words · last position \(record.lastAyah):\(record.lastWord)")
                            .foregroundStyle(.secondary)
                        if !record.coreRecord.correctionEvents.isEmpty {
                            Text("\(record.coreRecord.correctionEvents.count) correction-needed event(s)")
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if let exportMessage {
                Text(exportMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding([.horizontal, .bottom])
                    .textSelection(.enabled)
            }
        }
    }

    private func label(for record: StoredSessionRecord) -> String {
        let surah = SurahCatalog.surah(record.surah)?.englishName ?? "Surah \(record.surah)"
        return "\(surah) from ayah \(record.startAyah)"
    }

    private func exportHistory() {
        do {
            let data = try SessionHistoryExporter.exportJSON(records: records.map(\.coreRecord))
            let url = FileManager.default.homeDirectoryForCurrentUser
                .appending(path: "Desktop")
                .appending(path: "hifz-tracker-history.json")
            try data.write(to: url, options: .atomic)
            exportMessage = "Exported to \(url.path)"
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func resetHistory() {
        for record in records {
            modelContext.delete(record)
        }
        try? modelContext.save()
    }
}
