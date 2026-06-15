import XCTest
import HifzCore
@testable import HifzTracker

final class RecitationViewModelTests: XCTestCase {
    @MainActor
    func testDefaultsToBeginningOfSelectedSurah() {
        let viewModel = RecitationViewModel(repository: nil)

        XCTAssertEqual(viewModel.selectedSurah, 73)
        XCTAssertEqual(viewModel.startAyah, 1)
    }

    func testAudioLevelMeterKeepsSilenceAtZero() {
        var meter = AudioLevelMeter()

        let level = meter.update(with: Array(repeating: Float(0), count: 128))

        XCTAssertEqual(level, 0, accuracy: 0.001)
        XCTAssertEqual(meter.level, 0, accuracy: 0.001)
    }

    func testAudioLevelMeterRaisesLevelForLoudSamples() {
        var meter = AudioLevelMeter()

        let level = meter.update(with: Array(repeating: Float(0.75), count: 128))

        XCTAssertGreaterThan(level, 0.45)
        XCTAssertLessThanOrEqual(level, 1)
    }

    func testAudioLevelMeterDecaysSmoothlyForQuietSamplesAndResets() {
        var meter = AudioLevelMeter()
        let loudLevel = meter.update(with: Array(repeating: Float(0.85), count: 128))

        let quietLevel = meter.update(with: Array(repeating: Float(0), count: 128))

        XCTAssertGreaterThan(quietLevel, 0)
        XCTAssertLessThan(quietLevel, loudLevel)

        meter.reset()

        XCTAssertEqual(meter.level, 0, accuracy: 0.001)
    }

    @MainActor
    func testAutoFlipsToPageContainingNextTrackedWordDuringRecitation() {
        let repository = InMemoryQuranRepository()
        let viewModel = RecitationViewModel(repository: repository)
        viewModel.selectedSurah = 1
        viewModel.startAyah = 1
        viewModel.isRecording = true

        let references = [
            RecitationWordReference(surah: 1, ayah: 1, wordIndex: 1, text: "one"),
            RecitationWordReference(surah: 1, ayah: 1, wordIndex: 2, text: "two"),
            RecitationWordReference(surah: 1, ayah: 1, wordIndex: 3, text: "three"),
            RecitationWordReference(surah: 1, ayah: 2, wordIndex: 1, text: "four")
        ]

        viewModel.applyLocatedProgress(through: references[1], references: references)

        XCTAssertEqual(viewModel.pageNumber, 2)
        XCTAssertEqual(viewModel.mushafPage?.pageNumber, 2)
        XCTAssertEqual(viewModel.focusedAyah, 1)
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 1, ayah: 1, wordIndex: 3)), .current)
    }

    @MainActor
    func testDoesNotAutoFlipWhenLocatedProgressIsAppliedOutsideActiveRecitation() {
        let repository = InMemoryQuranRepository()
        let viewModel = RecitationViewModel(repository: repository)
        viewModel.selectedSurah = 1
        viewModel.startAyah = 1

        let references = [
            RecitationWordReference(surah: 1, ayah: 1, wordIndex: 1, text: "one"),
            RecitationWordReference(surah: 1, ayah: 1, wordIndex: 2, text: "two"),
            RecitationWordReference(surah: 1, ayah: 1, wordIndex: 3, text: "three")
        ]

        viewModel.applyLocatedProgress(through: references[1], references: references)

        XCTAssertEqual(viewModel.pageNumber, 1)
        XCTAssertEqual(viewModel.mushafPage?.pageNumber, 1)
    }
}

private final class InMemoryQuranRepository: QuranRepository {
    private let wordsByLocation: [String: QuranWord]
    private let wordsByAyah: [String: [QuranWord]]
    private let pages: [Int: MushafPage]
    private let ayahPages: [String: Int]
    private let wordPages: [String: Int]

    init() {
        let pageOneWords = [
            Self.makeWord(id: 1, surah: 1, ayah: 1, wordIndex: 1, text: "one"),
            Self.makeWord(id: 2, surah: 1, ayah: 1, wordIndex: 2, text: "two")
        ]
        let pageTwoWords = [
            Self.makeWord(id: 3, surah: 1, ayah: 1, wordIndex: 3, text: "three"),
            Self.makeWord(id: 4, surah: 1, ayah: 2, wordIndex: 1, text: "four")
        ]
        let allWords = pageOneWords + pageTwoWords

        self.wordsByLocation = Dictionary(uniqueKeysWithValues: allWords.map { ($0.location, $0) })
        self.wordsByAyah = Dictionary(grouping: allWords) { "\($0.surah):\($0.ayah)" }
        self.pages = [
            1: Self.makePage(pageNumber: 1, words: pageOneWords),
            2: Self.makePage(pageNumber: 2, words: pageTwoWords)
        ]
        self.ayahPages = [
            "1:1": 1,
            "1:2": 2
        ]
        self.wordPages = [
            "1:1:1": 1,
            "1:1:2": 1,
            "1:1:3": 2,
            "1:2:1": 2
        ]
    }

    func words(surah: Int, ayah: Int) throws -> [QuranWord] {
        wordsByAyah["\(surah):\(ayah)"] ?? []
    }

    func referenceText(surah: Int, ayah: Int) throws -> String {
        try words(surah: surah, ayah: ayah).map(\.text).joined(separator: " ")
    }

    func pageNumber(surah: Int, ayah: Int) -> Int {
        ayahPages["\(surah):\(ayah)"] ?? 1
    }

    func pageNumber(surah: Int, ayah: Int, wordIndex: Int) -> Int? {
        wordPages["\(surah):\(ayah):\(wordIndex)"]
    }

    func mushafPage(pageNumber: Int) throws -> MushafPage {
        pages[pageNumber] ?? MushafPage(pageNumber: pageNumber, lines: [])
    }

    func word(surah: Int, ayah: Int, wordIndex: Int) -> QuranWord {
        wordsByLocation["\(surah):\(ayah):\(wordIndex)"]!
    }

    private static func makeWord(id: Int, surah: Int, ayah: Int, wordIndex: Int, text: String) -> QuranWord {
        QuranWord(
            id: id,
            location: "\(surah):\(ayah):\(wordIndex)",
            surah: surah,
            ayah: ayah,
            wordIndex: wordIndex,
            text: text
        )
    }

    private static func makePage(pageNumber: Int, words: [QuranWord]) -> MushafPage {
        MushafPage(
            pageNumber: pageNumber,
            lines: [
                MushafPageLine(
                    pageNumber: pageNumber,
                    lineNumber: 1,
                    lineType: .ayah,
                    isCentered: false,
                    firstWordID: words.first?.id,
                    lastWordID: words.last?.id,
                    surahNumber: words.first?.surah,
                    words: words
                )
            ]
        )
    }
}
