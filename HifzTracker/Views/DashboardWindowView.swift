import SwiftData
import SwiftUI
import HifzCore

struct DashboardWindowView: View {
    @Query(sort: \StoredSessionRecord.startedAt, order: .reverse) private var records: [StoredSessionRecord]
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
