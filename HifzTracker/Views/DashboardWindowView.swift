import SwiftData
import SwiftUI
import HifzCore

struct DashboardWindowView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredSessionRecord.startedAt, order: .reverse) private var records: [StoredSessionRecord]
    @State private var isConfirmingReset = false
    @State private var resetErrorMessage: String?
    private let repository: QuranRepository?

    init(repository: QuranRepository? = AppQuranRepositoryFactory.makeRepository()) {
        self.repository = repository
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Dashboard")
                    .font(.title2.weight(.semibold))
                Spacer()

                Button {
                    isConfirmingReset = true
                } label: {
                    Label("Reset Progress…", systemImage: "arrow.counterclockwise")
                }
                .disabled(records.isEmpty)
                .help("Delete all saved tracking progress")
            }
            .padding()
            .background(.bar)

            List(summaries) { summary in
                DashboardSurahProgressRow(summary: summary)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 6)
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .alert("Reset all progress?", isPresented: $isConfirmingReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset All Progress", role: .destructive) {
                do {
                    try resetDashboardProgress(records, in: modelContext)
                } catch {
                    resetErrorMessage = error.localizedDescription
                }
            }
        } message: {
            Text("This permanently deletes every saved recitation session. This action cannot be undone.")
        }
        .alert("Unable to reset progress", isPresented: Binding(
            get: { resetErrorMessage != nil },
            set: { if !$0 { resetErrorMessage = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(resetErrorMessage ?? "The saved progress could not be deleted.")
        }
    }

    private var summaries: [SurahProgressSummary] {
        guard let repository else {
            return SurahCatalog.all.map {
                SurahProgressSummary(surah: $0, completedWords: 0, totalWords: 0)
            }
        }

        return DashboardProgressCalculator.summaries(
            records: records.map(\.coreRecord),
            repository: repository
        )
    }
}

@MainActor
func resetDashboardProgress(_ records: [StoredSessionRecord], in context: ModelContext) throws {
    records.forEach { context.delete($0) }
    do {
        try context.save()
    } catch {
        context.rollback()
        throw error
    }
}

private struct DashboardSurahProgressRow: View {
    var summary: SurahProgressSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(summary.surah.number)")
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)

                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.surah.arabicName)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)

                    Text(summary.surah.englishName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Text(summary.percentLabel)
                    .font(.callout.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, alignment: .trailing)
            }

            DashboardProgressBar(fraction: summary.fraction)
                .padding(.leading, 48)
        }
    }
}

private struct DashboardProgressBar: View {
    var fraction: Double

    var body: some View {
        GeometryReader { proxy in
            let clamped = max(0, min(1, fraction))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)

                Capsule()
                    .fill(.green)
                    .frame(width: proxy.size.width * clamped)
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}
