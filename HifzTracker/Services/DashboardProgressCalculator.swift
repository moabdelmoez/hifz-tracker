import Foundation
import HifzCore

enum ProgressActivityLevel: Int, CaseIterable {
    case none
    case light
    case medium
    case dark
    case darkest

    init(wordCount: Int) {
        switch wordCount {
        case ...0: self = .none
        case 1...25: self = .light
        case 26...75: self = .medium
        case 76...150: self = .dark
        default: self = .darkest
        }
    }
}

struct ProgressActivityDay: Equatable, Identifiable {
    var id: Date { date }

    var date: Date
    var wordCount: Int
    var isFuture: Bool

    var level: ProgressActivityLevel {
        ProgressActivityLevel(wordCount: wordCount)
    }
}

enum ProgressActivityCalculator {
    static func days(
        records: [SessionRecord],
        through date: Date = .now,
        calendar: Calendar = .current
    ) -> [ProgressActivityDay] {
        let today = calendar.startOfDay(for: date)
        let daysSinceSunday = calendar.component(.weekday, from: today) - 1
        guard let currentWeekStart = calendar.date(byAdding: .day, value: -daysSinceSunday, to: today),
              let rangeStart = calendar.date(byAdding: .day, value: -(52 * 7), to: currentWeekStart) else {
            return []
        }

        var wordsByDate: [Date: Int] = [:]
        for record in records where record.completedWordCount > 0 {
            wordsByDate[calendar.startOfDay(for: record.startedAt), default: 0] += record.completedWordCount
        }

        return (0..<(53 * 7)).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: rangeStart) else {
                return nil
            }
            return ProgressActivityDay(
                date: day,
                wordCount: wordsByDate[day] ?? 0,
                isFuture: day > today
            )
        }
    }
}

struct SurahProgressSummary: Equatable, Identifiable {
    struct Practice: Equatable {
        var date: Date
        var ayah: Int
        var word: Int?
    }

    var id: Int { surah.number }

    var surah: SurahInfo
    var completedWords: Int
    var totalWords: Int
    var latestPractice: Practice? = nil

    var fraction: Double {
        guard totalWords > 0 else { return 0 }
        return Double(completedWords) / Double(totalWords)
    }

    var percentLabel: String {
        guard completedWords > 0, totalWords > 0 else { return "0%" }
        guard completedWords < totalWords else { return "100%" }

        let percent = fraction * 100
        if percent < 1 {
            return "<1%"
        }

        let rounded = Int(percent.rounded())
        return "\(max(1, min(99, rounded)))%"
    }
}

enum DashboardProgressCalculator {
    static func practicedSurahs(in summaries: [SurahProgressSummary]) -> [SurahProgressSummary] {
        let practiced: [(summary: SurahProgressSummary, date: Date)] = summaries.compactMap { summary in
            summary.latestPractice.map { (summary: summary, date: $0.date) }
        }
        return practiced.sorted {
            $0.date == $1.date ? $0.summary.id < $1.summary.id : $0.date > $1.date
        }.map { $0.summary }
    }

    static func summaries(
        records: [SessionRecord],
        repository: QuranRepository?,
        surahs: [SurahInfo] = SurahCatalog.all
    ) -> [SurahProgressSummary] {
        let metricsBySurah = Dictionary(uniqueKeysWithValues: surahs.map { surah in
            (surah.number, SurahWordMetrics(surah: surah, repository: repository))
        })
        var completedBySurah: [Int: Int] = [:]
        var latestPracticeBySurah: [Int: SurahProgressSummary.Practice] = [:]

        for record in records where record.completedWordCount > 0 {
            let startSurah = record.surah
            let endSurah = record.lastSurah < startSurah ? startSurah : record.lastSurah
            let date = record.endedAt ?? record.startedAt

            for surah in startSurah...endSurah {
                guard let metrics = metricsBySurah[surah] else { continue }

                let ayah = surah == endSurah ? record.lastAyah : metrics.lastAyah
                let word = surah == endSurah ? record.lastWord : metrics.wordCountsByAyah[ayah]
                let completed = metrics.completedWords(throughAyah: ayah, wordIndex: word ?? 0)
                completedBySurah[surah] = max(completedBySurah[surah] ?? 0, completed)

                if latestPracticeBySurah[surah].map({ $0.date < date }) ?? true {
                    latestPracticeBySurah[surah] = .init(date: date, ayah: ayah, word: word)
                }
            }
        }

        return surahs.map { surah in
            let totalWords = metricsBySurah[surah.number]?.totalWords ?? 0
            let completedWords = max(0, min(totalWords, completedBySurah[surah.number] ?? 0))
            return SurahProgressSummary(
                surah: surah,
                completedWords: completedWords,
                totalWords: totalWords,
                latestPractice: latestPracticeBySurah[surah.number]
            )
        }
    }
}

private struct SurahWordMetrics {
    let wordCountsByAyah: [Int: Int]
    let totalWords: Int
    let lastAyah: Int

    init(surah: SurahInfo, repository: QuranRepository?) {
        self.lastAyah = surah.ayahCount
        guard let repository else {
            self.wordCountsByAyah = [:]
            self.totalWords = 0
            return
        }

        var counts: [Int: Int] = [:]
        var total = 0

        for ayah in 1...surah.ayahCount {
            let text = (try? repository.referenceText(surah: surah.number, ayah: ayah)) ?? ""
            let count = QuranReferenceWords.wordsForAyah(text, surah: surah.number, ayah: ayah).count
            counts[ayah] = count
            total += count
        }

        self.wordCountsByAyah = counts
        self.totalWords = total
    }

    func completedWords(throughAyah ayah: Int, wordIndex: Int) -> Int {
        guard totalWords > 0 else { return 0 }

        var completed = 0
        let clampedAyah = max(1, ayah)

        if clampedAyah > 1 {
            for earlierAyah in 1..<clampedAyah {
                completed += wordCountsByAyah[earlierAyah] ?? 0
            }
        }

        let wordsInAyah = wordCountsByAyah[clampedAyah] ?? 0
        completed += max(0, min(wordsInAyah, wordIndex))

        return max(0, min(totalWords, completed))
    }
}
