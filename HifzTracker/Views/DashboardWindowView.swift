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
                Text("Progress")
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

            ProgressActivityCalendar(days: activityDays)
                .padding()

            Divider()

            if records.isEmpty {
                ContentUnavailableView(
                    "No Saved Progress",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Complete a recitation session to begin tracking your progress.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(summaries) { summary in
                    DashboardSurahProgressRow(summary: summary)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 6)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
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

    private var activityDays: [ProgressActivityDay] {
        ProgressActivityCalculator.days(records: records.map(\.coreRecord))
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

private struct ProgressActivityCalendar: View {
    let days: [ProgressActivityDay]

    private let calendar = Calendar.current
    private let cellSize: CGFloat = 11
    private let spacing: CGFloat = 3
    private let weekdayLabels = ["", "Mon", "", "Wed", "", "Fri", ""]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recitation activity")
                .font(.headline)

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
