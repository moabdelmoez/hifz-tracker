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
        let coreRecords = records.map(\.coreRecord)
        let summaries = summaries(for: coreRecords)
        let practiced = DashboardProgressCalculator.practicedSurahs(in: summaries)

        Group {
            if practiced.isEmpty {
                ContentUnavailableView(
                    "No Saved Progress",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Recite a few words, then stop the session to save your progress.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("Practiced surahs") {
                        ForEach(practiced) { summary in
                            DashboardSurahProgressRow(summary: summary, showsLatestPractice: true)
                                .padding(.vertical, 6)
                        }
                    }
                    DisclosureGroup("Recitation activity") {
                        ProgressActivityCalendar(days: ProgressActivityCalculator.days(records: coreRecords))
                            .padding(.vertical, 6)
                    }
                    DisclosureGroup("All 114 surahs") {
                        if repository == nil {
                            Text("Furthest positions require the bundled Quran resources.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(summaries) { summary in
                            DashboardSurahProgressRow(summary: summary)
                                .padding(.vertical, 6)
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .toolbar {
            Menu {
                Button("Reset Progress…", role: .destructive) {
                    isConfirmingReset = true
                }
            } label: {
                Label("Progress actions", systemImage: "ellipsis.circle")
            }
            .disabled(records.isEmpty)
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

    private func summaries(for records: [SessionRecord]) -> [SurahProgressSummary] {
        guard records.contains(where: { $0.completedWordCount > 0 }) else { return [] }
        return DashboardProgressCalculator.summaries(records: records, repository: repository)
    }
}

private struct ProgressActivityCalendar: View {
    let days: [ProgressActivityDay]

    private let calendar = Calendar.current
    private let cellSize: CGFloat = 11
    private let spacing: CGFloat = 3
    private let weekdayLabels = ["", "Mon", "", "Wed", "", "Fri", ""]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: spacing) {
                    Color.clear
                        .frame(width: 28, height: 14)

                    ForEach(weekdayLabels.indices, id: \.self) { index in
                        Text(weekdayLabels[index])
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: cellSize, alignment: .trailing)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: spacing) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                            ZStack(alignment: .leading) {
                                Text(monthLabel(for: week))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize()
                            }
                            .frame(width: cellSize, height: 14, alignment: .leading)
                        }
                    }

                    HStack(spacing: spacing) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                            VStack(spacing: spacing) {
                                ForEach(week) { day in
                                    activityCell(for: day)
                                }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 6) {
                Spacer()
                Text("Less")
                    .foregroundStyle(.secondary)

                ForEach(ProgressActivityLevel.allCases, id: \.rawValue) { level in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color(for: level))
                        .frame(width: cellSize, height: cellSize)
                }

                Text("More")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
    }

    private var weeks: [[ProgressActivityDay]] {
        stride(from: 0, to: days.count, by: 7).map {
            Array(days[$0..<min($0 + 7, days.count)])
        }
    }

    @ViewBuilder
    private func activityCell(for day: ProgressActivityDay) -> some View {
        if day.isFuture {
            Color.clear
                .frame(width: cellSize, height: cellSize)
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color(for: day.level))
                .overlay {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.5)
                }
                .frame(width: cellSize, height: cellSize)
                .help(accessibilityLabel(for: day))
                .accessibilityLabel(accessibilityLabel(for: day))
        }
    }

    private func monthLabel(for week: [ProgressActivityDay]) -> String {
        guard let firstOfMonth = week.first(where: {
            !$0.isFuture && calendar.component(.day, from: $0.date) == 1
        }) else {
            return ""
        }
        return firstOfMonth.date.formatted(.dateTime.month(.abbreviated))
    }

    private func accessibilityLabel(for day: ProgressActivityDay) -> String {
        let date = day.date.formatted(date: .long, time: .omitted)
        let words = day.wordCount == 1 ? "1 confirmed word recited" : "\(day.wordCount) confirmed words recited"
        return "\(date), \(words)"
    }

    private func color(for level: ProgressActivityLevel) -> Color {
        switch level {
        case .none:
            Color(nsColor: .separatorColor).opacity(0.45)
        case .light:
            Color(nsColor: .systemGreen).opacity(0.28)
        case .medium:
            Color(nsColor: .systemGreen).opacity(0.52)
        case .dark:
            Color(nsColor: .systemGreen).opacity(0.76)
        case .darkest:
            Color(nsColor: .systemGreen)
        }
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
    var showsLatestPractice = false

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

                if let positionLabel {
                    Text(positionLabel)
                        .font(.callout.monospacedDigit().weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, alignment: .trailing)
                }
            }

            if !showsLatestPractice, summary.totalWords > 0 {
                DashboardProgressBar(fraction: summary.fraction)
                    .padding(.leading, 48)
            }
        }
    }

    private var positionLabel: String? {
        if showsLatestPractice, let practice = summary.latestPractice {
            let ayah = "Ayah \(practice.ayah)"
            return practice.word.map { "\(ayah) · Word \($0)" } ?? ayah
        }
        guard summary.totalWords > 0 else { return nil }
        return "Furthest position \(summary.percentLabel)"
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
