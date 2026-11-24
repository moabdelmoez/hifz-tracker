import XCTest
import HifzCore
@testable import HifzTracker

final class DashboardProgressCalculatorTests: XCTestCase {
    func testNoRecordsProducesAllSurahsAtZeroProgress() {
        let summaries = DashboardProgressCalculator.summaries(
            records: [],
            repository: DashboardProgressRepository()
        )

        XCTAssertEqual(summaries.count, 114)
        XCTAssertEqual(summaries.first?.surah.number, 1)
        XCTAssertEqual(summaries.last?.surah.number, 114)
        XCTAssertTrue(summaries.allSatisfy { $0.completedWords == 0 })
        XCTAssertTrue(summaries.allSatisfy { $0.fraction == 0 })
        XCTAssertTrue(summaries.allSatisfy { $0.percentLabel == "0%" })
    }

    func testPartialRecordUsesWordBasedProgress() {
        let summaries = DashboardProgressCalculator.summaries(
            records: [
                makeRecord(surah: 1, lastSurah: 1, lastAyah: 1, lastWord: 2)
            ],
            repository: DashboardProgressRepository(),
            surahs: testSurahs
        )

        XCTAssertEqual(summaries[0].completedWords, 2)
        XCTAssertEqual(summaries[0].totalWords, 6)
        XCTAssertEqual(summaries[0].fraction, 2.0 / 6.0, accuracy: 0.001)
        XCTAssertEqual(summaries[0].percentLabel, "33%")
    }

    func testSilentSessionDoesNotCreditAnySurahProgress() {
        var silent = makeRecord(surah: 1, lastSurah: 1, lastAyah: 2, lastWord: 1)
        silent.startAyah = 2
        silent.completedWordCount = 0

        let summaries = DashboardProgressCalculator.summaries(
            records: [silent, makeRecord(surah: 3, lastSurah: 3, lastAyah: 1, lastWord: 1)],
            repository: DashboardProgressRepository(),
            surahs: testSurahs
        )

        XCTAssertEqual(summaries.filter { $0.completedWords > 0 }.map(\.id), [3])
        XCTAssertEqual(DashboardProgressCalculator.practicedSurahs(in: summaries).map(\.id), [3])
        XCTAssertNil(summaries[0].latestPractice)
    }

    func testPracticedSurahsUseMostRecentSessionAndKeepFurthestPosition() {
        let earlier = makeRecord(surah: 1, lastSurah: 1, lastAyah: 2, lastWord: 2)
        var recent = makeRecord(surah: 1, lastSurah: 1, lastAyah: 1, lastWord: 2)
        recent.endedAt = Date(timeIntervalSince1970: 1_700_000_060)
        var latest = makeRecord(surah: 3, lastSurah: 3, lastAyah: 1, lastWord: 1)
        latest.endedAt = Date(timeIntervalSince1970: 1_700_000_090)

        let summaries = DashboardProgressCalculator.summaries(
            records: [latest, earlier, recent], repository: DashboardProgressRepository(), surahs: testSurahs
        )

        XCTAssertEqual(DashboardProgressCalculator.practicedSurahs(in: summaries).map(\.id), [3, 1])
        XCTAssertEqual(summaries[0].latestPractice?.ayah, 1)
        XCTAssertEqual(summaries[0].latestPractice?.word, 2)
        XCTAssertEqual(summaries[0].percentLabel, "100%")
    }

    func testSavedPracticeRemainsVisibleWithoutQuranRepository() {
        let summaries = DashboardProgressCalculator.summaries(
            records: [makeRecord(surah: 1, lastSurah: 2, lastAyah: 1, lastWord: 2)],
            repository: nil,
            surahs: testSurahs
        )

        let practiced = DashboardProgressCalculator.practicedSurahs(in: summaries)
        XCTAssertEqual(practiced.map(\.id), [1, 2])
        XCTAssertEqual(practiced.first?.latestPractice?.ayah, 2)
        XCTAssertNil(practiced.first?.latestPractice?.word)
        XCTAssertEqual(practiced.last?.latestPractice?.word, 2)
        XCTAssertEqual(practiced.last?.totalWords, 0)
    }

    func testMultipleRecordsChooseFarthestSavedPosition() {
        let summaries = DashboardProgressCalculator.summaries(
            records: [
                makeRecord(surah: 1, lastSurah: 1, lastAyah: 1, lastWord: 2),
                makeRecord(surah: 1, lastSurah: 1, lastAyah: 2, lastWord: 1)
            ],
            repository: DashboardProgressRepository(),
            surahs: testSurahs
        )

        XCTAssertEqual(summaries[0].completedWords, 5)
        XCTAssertEqual(summaries[0].totalWords, 6)
        XCTAssertEqual(summaries[0].percentLabel, "83%")
    }

    func testCrossSurahRecordCompletesStartAndPartiallyFillsEnd() {
        let summaries = DashboardProgressCalculator.summaries(
            records: [
                makeRecord(surah: 1, lastSurah: 2, lastAyah: 1, lastWord: 2)
            ],
            repository: DashboardProgressRepository(),
            surahs: testSurahs
        )

        XCTAssertEqual(summaries[0].completedWords, 6)
        XCTAssertEqual(summaries[0].percentLabel, "100%")
        XCTAssertEqual(summaries[0].latestPractice?.ayah, 2)
        XCTAssertEqual(summaries[0].latestPractice?.word, 2)
        XCTAssertEqual(summaries[1].completedWords, 2)
        XCTAssertEqual(summaries[1].totalWords, 3)
        XCTAssertEqual(summaries[1].percentLabel, "67%")
    }

    func testLegacyRecordDefaultsLastSurahToStartSurah() {
        let legacyRecord = SessionRecord(
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_000_030),
            surah: 1,
            startAyah: 1,
            lastAyah: 2,
            lastWord: 1,
            completedWordCount: 5,
            correctionEvents: []
        )

        let summaries = DashboardProgressCalculator.summaries(
            records: [legacyRecord],
            repository: DashboardProgressRepository(),
            surahs: testSurahs
        )

        XCTAssertEqual(summaries[0].completedWords, 5)
        XCTAssertEqual(summaries[0].percentLabel, "83%")
        XCTAssertEqual(summaries[1].completedWords, 0)
        XCTAssertEqual(summaries[1].percentLabel, "0%")
    }

    private var testSurahs: [SurahInfo] {
        [
            SurahInfo(number: 1, arabicName: "الفاتحة", englishName: "Al-Fatihah", ayahCount: 2),
            SurahInfo(number: 2, arabicName: "البقرة", englishName: "Al-Baqarah", ayahCount: 1),
            SurahInfo(number: 3, arabicName: "آل عمران", englishName: "Ali 'Imran", ayahCount: 1)
        ]
    }

    private func makeRecord(
        surah: Int,
        lastSurah: Int,
        lastAyah: Int,
        lastWord: Int
    ) -> SessionRecord {
        SessionRecord(
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_000_030),
            surah: surah,
            startAyah: 1,
            lastSurah: lastSurah,
            lastAyah: lastAyah,
            lastWord: lastWord,
            completedWordCount: lastWord,
            correctionEvents: []
        )
    }
}

private final class DashboardProgressRepository: QuranRepository {
    private let referenceTextByKey = [
        "1:1": "one two three four",
        "1:2": "five six",
        "2:1": "alpha beta gamma",
        "3:1": "start"
    ]

    func words(surah: Int, ayah: Int) throws -> [QuranWord] {
        []
    }

    func referenceText(surah: Int, ayah: Int) throws -> String {
        referenceTextByKey["\(surah):\(ayah)"] ?? ""
    }

    func pageNumber(surah: Int, ayah: Int) -> Int {
        surah
    }

    func mushafPage(pageNumber: Int) throws -> MushafPage {
        MushafPage(pageNumber: pageNumber, lines: [])
    }
}
