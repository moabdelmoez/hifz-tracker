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

    @MainActor
    func testHideRecitationTextDefaultsOffAndLeavesMushafWordsVisible() {
        let repository = InMemoryQuranRepository()
        let viewModel = RecitationViewModel(repository: repository)
        viewModel.selectedSurah = 1
        viewModel.startAyah = 1

        XCTAssertFalse(viewModel.hideRecitationText)
        XCTAssertTrue(viewModel.isMushafTextVisible(for: repository.word(surah: 1, ayah: 1, wordIndex: 1)))
        XCTAssertTrue(viewModel.isMushafTextVisible(for: repository.word(surah: 1, ayah: 2, wordIndex: 1)))
    }

    @MainActor
    func testHideRecitationTextKeepsEarlierContextVisibleAndHidesCurrentTargetWord() {
        let repository = InMemoryQuranRepository()
        let viewModel = RecitationViewModel(repository: repository)
        viewModel.selectedSurah = 1
        viewModel.startAyah = 2
        viewModel.hideRecitationText = true

        XCTAssertTrue(viewModel.isMushafTextVisible(for: repository.word(surah: 1, ayah: 1, wordIndex: 3)))
        XCTAssertFalse(viewModel.isMushafTextVisible(for: repository.word(surah: 1, ayah: 2, wordIndex: 1)))
    }

    @MainActor
    func testHideRecitationTextRevealsCompletedProvisionalAndCorrectionWords() {
        let repository = InMemoryQuranRepository()
        let viewModel = RecitationViewModel(repository: repository)
        viewModel.selectedSurah = 1
        viewModel.startAyah = 1
        viewModel.hideRecitationText = true
        let references = Self.references()

        viewModel.applyLocatedProgress(through: references[1], references: references)

        XCTAssertTrue(viewModel.isMushafTextVisible(for: repository.word(surah: 1, ayah: 1, wordIndex: 1)))
        XCTAssertTrue(viewModel.isMushafTextVisible(for: repository.word(surah: 1, ayah: 1, wordIndex: 2)))
        XCTAssertFalse(viewModel.isMushafTextVisible(for: repository.word(surah: 1, ayah: 1, wordIndex: 3)))

        let provisionalViewModel = RecitationViewModel(repository: repository)
        provisionalViewModel.selectedSurah = 1
        provisionalViewModel.startAyah = 1
        provisionalViewModel.hideRecitationText = true
        provisionalViewModel.applyProvisionalInitialHighlight(
            through: Self.location(matching: references, range: 0..<2),
            references: references
        )

        XCTAssertTrue(provisionalViewModel.isMushafTextVisible(for: repository.word(surah: 1, ayah: 1, wordIndex: 1)))
        XCTAssertTrue(provisionalViewModel.isMushafTextVisible(for: repository.word(surah: 1, ayah: 1, wordIndex: 2)))
        XCTAssertFalse(provisionalViewModel.isMushafTextVisible(for: repository.word(surah: 1, ayah: 1, wordIndex: 3)))

        let correctionViewModel = RecitationViewModel(repository: repository)
        correctionViewModel.selectedSurah = 1
        correctionViewModel.startAyah = 1
        correctionViewModel.hideRecitationText = true
        correctionViewModel.isRecording = true
        correctionViewModel.markDemoCorrection()

        XCTAssertTrue(correctionViewModel.isMushafTextVisible(for: repository.word(surah: 1, ayah: 1, wordIndex: 1)))
    }

    @MainActor
    func testHideRecitationTextRevealsCompletedAyahMarkerRows() {
        let repository = MarkerQuranRepository()
        let viewModel = RecitationViewModel(repository: repository)
        viewModel.selectedSurah = 88
        viewModel.startAyah = 1
        viewModel.hideRecitationText = true
        let references = [
            RecitationWordReference(surah: 88, ayah: 1, wordIndex: 1, text: "هل"),
            RecitationWordReference(surah: 88, ayah: 1, wordIndex: 2, text: "اتاك"),
            RecitationWordReference(surah: 88, ayah: 1, wordIndex: 3, text: "حديث"),
            RecitationWordReference(surah: 88, ayah: 1, wordIndex: 4, text: "الغاشية")
        ]

        viewModel.applyLocatedProgress(through: references[3], references: references)

        XCTAssertTrue(viewModel.isMushafTextVisible(for: repository.word(surah: 88, ayah: 1, wordIndex: 4)))
        XCTAssertTrue(
            viewModel.isMushafTextVisible(for: repository.word(surah: 88, ayah: 1, wordIndex: 5)),
            "The QPC ayah marker row should reveal when the final real word in that ayah is completed."
        )
    }

    @MainActor
    func testHideRecitationTextContinuesAcrossNextSurah() {
        let repository = InMemoryQuranRepository()
        let viewModel = RecitationViewModel(repository: repository)
        viewModel.selectedSurah = 100
        viewModel.startAyah = 11
        viewModel.hideRecitationText = true
        viewModel.isRecording = true

        XCTAssertTrue(viewModel.applyASRTranscript(Self.transcript("hundred final one two"), windowID: 1))
        XCTAssertTrue(viewModel.applyASRTranscript(Self.transcript("next surah one two"), windowID: 2))

        XCTAssertTrue(viewModel.isMushafTextVisible(for: repository.word(surah: 101, ayah: 1, wordIndex: 1)))
        XCTAssertTrue(viewModel.isMushafTextVisible(for: repository.word(surah: 101, ayah: 1, wordIndex: 4)))
        XCTAssertFalse(viewModel.isMushafTextVisible(for: repository.word(surah: 101, ayah: 1, wordIndex: 5)))
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
    func testDisplayedAyahFollowsNextTrackedAyahDuringRecitation() {
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

        viewModel.applyLocatedProgress(through: references[2], references: references)

        XCTAssertEqual(viewModel.displayedAyah, 2)
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

    @MainActor
    func testProvisionalInitialHighlightDoesNotAdvanceCommittedSnapshot() {
        let repository = InMemoryQuranRepository()
        let viewModel = RecitationViewModel(repository: repository)
        viewModel.selectedSurah = 1
        viewModel.startAyah = 1
        let references = Self.references()

        viewModel.applyProvisionalInitialHighlight(
            through: Self.location(matching: references, range: 0..<2),
            references: references
        )

        XCTAssertEqual(viewModel.snapshot.completedWordCount, 0)
    }

    @MainActor
    func testProvisionalInitialHighlightPaintsMatchedWordsAndNextCurrent() {
        let repository = InMemoryQuranRepository()
        let viewModel = RecitationViewModel(repository: repository)
        viewModel.selectedSurah = 1
        viewModel.startAyah = 1
        let references = Self.references()

        viewModel.applyProvisionalInitialHighlight(
            through: Self.location(matching: references, range: 0..<2),
            references: references
        )

        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 1, ayah: 1, wordIndex: 1)), .provisional)
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 1, ayah: 1, wordIndex: 2)), .provisional)
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 1, ayah: 1, wordIndex: 3)), .current)
    }

    @MainActor
    func testLocatedProgressReplacesProvisionalVisualStateWithAuthoritativeStates() {
        let repository = InMemoryQuranRepository()
        let viewModel = RecitationViewModel(repository: repository)
        viewModel.selectedSurah = 1
        viewModel.startAyah = 1
        let references = Self.references()

        viewModel.applyProvisionalInitialHighlight(
            through: Self.location(matching: references, range: 0..<2),
            references: references
        )
        viewModel.applyAuthoritativeLocatedProgress(
            Self.location(matching: references, range: 0..<2),
            references: references
        )

        XCTAssertEqual(viewModel.snapshot.completedWordCount, 2)
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 1, ayah: 1, wordIndex: 1)), .completed)
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 1, ayah: 1, wordIndex: 2)), .completed)
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 1, ayah: 1, wordIndex: 3)), .current)
        XCTAssertEqual(viewModel.wordProgress.map(\.state), [.completed, .completed, .current])
    }

    @MainActor
    func testProvisionalInitialHighlightClearsWhenEvidenceDisappearsBeforeLock() {
        let repository = InMemoryQuranRepository()
        let viewModel = RecitationViewModel(repository: repository)
        viewModel.selectedSurah = 1
        viewModel.startAyah = 1
        let references = Self.references()

        viewModel.applyProvisionalInitialHighlight(
            through: Self.location(matching: references, range: 0..<2),
            references: references
        )
        viewModel.clearProvisionalInitialHighlight()

        XCTAssertEqual(viewModel.snapshot.completedWordCount, 0)
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 1, ayah: 1, wordIndex: 1)), .current)
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 1, ayah: 1, wordIndex: 2)), .pending)
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 1, ayah: 1, wordIndex: 3)), .pending)
        XCTAssertEqual(viewModel.wordProgress.map(\.state), [.current, .pending, .pending])
    }

    @MainActor
    func testProvisionalInitialHighlightDoesNotMoveDisplayedAyahOrAutoFlipPage() {
        let repository = InMemoryQuranRepository()
        let viewModel = RecitationViewModel(repository: repository)
        viewModel.selectedSurah = 1
        viewModel.startAyah = 1
        viewModel.isRecording = true
        let references = Self.references()

        viewModel.applyProvisionalInitialHighlight(
            through: Self.location(matching: references, range: 0..<3),
            references: references
        )

        XCTAssertEqual(viewModel.displayedAyah, 1)
        XCTAssertEqual(viewModel.pageNumber, 1)
        XCTAssertEqual(viewModel.mushafPage?.pageNumber, 1)
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 1, ayah: 2, wordIndex: 1)), .current)
    }

    @MainActor
    func testLiveASRHighlightsNextSurahAfterCompletingSelectedSurah() {
        let repository = InMemoryQuranRepository()
        let viewModel = RecitationViewModel(repository: repository)
        viewModel.selectedSurah = 100
        viewModel.startAyah = 11
        viewModel.isRecording = true

        XCTAssertTrue(viewModel.applyASRTranscript(Self.transcript("hundred final one two"), windowID: 1))
        XCTAssertEqual(viewModel.snapshot.currentAyah, 11)

        XCTAssertTrue(viewModel.applyASRTranscript(Self.transcript("next surah one two"), windowID: 2))

        XCTAssertEqual(viewModel.snapshot.currentAyah, 1)
        XCTAssertEqual(viewModel.snapshot.completedWordCount, 4)
        XCTAssertEqual(viewModel.pageNumber, 101)
        XCTAssertEqual(viewModel.mushafPage?.pageNumber, 101)
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 101, ayah: 1, wordIndex: 1)), .completed)
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 101, ayah: 1, wordIndex: 4)), .completed)
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 101, ayah: 1, wordIndex: 5)), .current)
    }

    @MainActor
    func testSessionRecordStoresLastSurahAfterCrossSurahProgress() {
        let repository = InMemoryQuranRepository()
        let viewModel = RecitationViewModel(repository: repository)
        viewModel.selectedSurah = 100
        viewModel.startAyah = 11
        viewModel.isRecording = true
        viewModel.sessionStartedAt = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertTrue(viewModel.applyASRTranscript(Self.transcript("hundred final one two"), windowID: 1))
        XCTAssertTrue(viewModel.applyASRTranscript(Self.transcript("next surah one two"), windowID: 2))

        let record = viewModel.makeSessionRecord()

        XCTAssertEqual(record?.surah, 100)
        XCTAssertEqual(record?.lastSurah, 101)
        XCTAssertEqual(record?.lastAyah, 1)
        XCTAssertEqual(record?.lastWord, 4)
    }

    private static func references() -> [RecitationWordReference] {
        [
            RecitationWordReference(surah: 1, ayah: 1, wordIndex: 1, text: "one"),
            RecitationWordReference(surah: 1, ayah: 1, wordIndex: 2, text: "two"),
            RecitationWordReference(surah: 1, ayah: 1, wordIndex: 3, text: "three"),
            RecitationWordReference(surah: 1, ayah: 2, wordIndex: 1, text: "four")
        ]
    }

    private static func location(
        matching references: [RecitationWordReference],
        range: Range<Int>
    ) -> TranscriptLocation {
        TranscriptLocation(
            completedThrough: references[range.upperBound - 1],
            matchedWordCount: range.count,
            expectedRange: range,
            recognizedRange: 0..<range.count
        )
    }

    private static func transcript(_ text: String) -> QuranSTTTranscript {
        QuranSTTTranscript(
            text: text,
            tokenIDs: [],
            logProbabilities: ONNXLogProbabilities(values: [], timeStepCount: 0, vocabularySize: 0)
        )
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
        let surahOneHundredWords = [
            Self.makeWord(id: 1001, surah: 100, ayah: 11, wordIndex: 1, text: "hundred"),
            Self.makeWord(id: 1002, surah: 100, ayah: 11, wordIndex: 2, text: "final"),
            Self.makeWord(id: 1003, surah: 100, ayah: 11, wordIndex: 3, text: "one"),
            Self.makeWord(id: 1004, surah: 100, ayah: 11, wordIndex: 4, text: "two")
        ]
        let nextSurahWords = [
            Self.makeWord(id: 1011, surah: 101, ayah: 1, wordIndex: 1, text: "next"),
            Self.makeWord(id: 1012, surah: 101, ayah: 1, wordIndex: 2, text: "surah"),
            Self.makeWord(id: 1013, surah: 101, ayah: 1, wordIndex: 3, text: "one"),
            Self.makeWord(id: 1014, surah: 101, ayah: 1, wordIndex: 4, text: "two"),
            Self.makeWord(id: 1015, surah: 101, ayah: 1, wordIndex: 5, text: "three")
        ]
        let allWords = pageOneWords + pageTwoWords + surahOneHundredWords + nextSurahWords

        self.wordsByLocation = Dictionary(uniqueKeysWithValues: allWords.map { ($0.location, $0) })
        self.wordsByAyah = Dictionary(grouping: allWords) { "\($0.surah):\($0.ayah)" }
        self.pages = [
            1: Self.makePage(pageNumber: 1, words: pageOneWords),
            2: Self.makePage(pageNumber: 2, words: pageTwoWords),
            100: Self.makePage(pageNumber: 100, words: surahOneHundredWords),
            101: Self.makePage(pageNumber: 101, words: nextSurahWords)
        ]
        self.ayahPages = [
            "1:1": 1,
            "1:2": 2,
            "100:11": 100,
            "101:1": 101
        ]
        self.wordPages = [
            "1:1:1": 1,
            "1:1:2": 1,
            "1:1:3": 2,
            "1:2:1": 2,
            "100:11:1": 100,
            "100:11:2": 100,
            "100:11:3": 100,
            "100:11:4": 100,
            "101:1:1": 101,
            "101:1:2": 101,
            "101:1:3": 101,
            "101:1:4": 101,
            "101:1:5": 101
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

private final class MarkerQuranRepository: QuranRepository {
    private let words: [QuranWord] = [
        QuranWord(id: 1, location: "88:1:1", surah: 88, ayah: 1, wordIndex: 1, text: "ﱭ"),
        QuranWord(id: 2, location: "88:1:2", surah: 88, ayah: 1, wordIndex: 2, text: "ﱮ"),
        QuranWord(id: 3, location: "88:1:3", surah: 88, ayah: 1, wordIndex: 3, text: "ﱯ"),
        QuranWord(id: 4, location: "88:1:4", surah: 88, ayah: 1, wordIndex: 4, text: "ﱰ"),
        QuranWord(id: 5, location: "88:1:5", surah: 88, ayah: 1, wordIndex: 5, text: "ﱱ")
    ]

    func words(surah: Int, ayah: Int) throws -> [QuranWord] {
        words.filter { $0.surah == surah && $0.ayah == ayah }
    }

    func referenceText(surah: Int, ayah: Int) throws -> String {
        "هل أتاك حديث الغاشية"
    }

    func pageNumber(surah: Int, ayah: Int) -> Int {
        592
    }

    func pageNumber(surah: Int, ayah: Int, wordIndex: Int) -> Int? {
        592
    }

    func mushafPage(pageNumber: Int) throws -> MushafPage {
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
                    surahNumber: 88,
                    words: words
                )
            ]
        )
    }

    func word(surah: Int, ayah: Int, wordIndex: Int) -> QuranWord {
        words.first { $0.surah == surah && $0.ayah == ayah && $0.wordIndex == wordIndex }!
    }
}
