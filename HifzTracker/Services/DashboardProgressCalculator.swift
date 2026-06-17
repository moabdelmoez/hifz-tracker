import Foundation
import HifzCore

struct SurahProgressSummary: Equatable, Identifiable {
    var id: Int { surah.number }

    var surah: SurahInfo
    var completedWords: Int
    var totalWords: Int

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
    static func summaries(
        records: [SessionRecord],
        repository: QuranRepository,
        surahs: [SurahInfo] = SurahCatalog.all
    ) -> [SurahProgressSummary] {
        let metricsBySurah = Dictionary(uniqueKeysWithValues: surahs.map { surah in
            (surah.number, SurahWordMetrics(surah: surah, repository: repository))
        })
        var completedBySurah: [Int: Int] = [:]

        for record in records {
            let startSurah = record.surah
            let endSurah = record.lastSurah < startSurah ? startSurah : record.lastSurah

            for surah in startSurah...endSurah {
                guard let metrics = metricsBySurah[surah] else { continue }

                let completed: Int
                if surah < endSurah {
                    completed = metrics.totalWords
                } else {
                    completed = metrics.completedWords(throughAyah: record.lastAyah, wordIndex: record.lastWord)
                }

                completedBySurah[surah] = max(completedBySurah[surah] ?? 0, completed)
            }
        }

        return surahs.map { surah in
            let totalWords = metricsBySurah[surah.number]?.totalWords ?? 0
            let completedWords = max(0, min(totalWords, completedBySurah[surah.number] ?? 0))
            return SurahProgressSummary(
                surah: surah,
                completedWords: completedWords,
                totalWords: totalWords
            )
        }
    }
}

private struct SurahWordMetrics {
    let wordCountsByAyah: [Int: Int]
    let totalWords: Int

    init(surah: SurahInfo, repository: QuranRepository) {
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
