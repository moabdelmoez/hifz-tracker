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
    func testLocatedProgressOnlyHighlightsConfirmedWords() {
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
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 1, ayah: 1, wordIndex: 2)), .completed)
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 1, ayah: 1, wordIndex: 3)), .pending)

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

        XCTAssertTrue(viewModel.applyASRTranscript(
            Self.transcript("hundred final one two"),
            windowID: 1,
            sampleRange: 0..<400
        ))
        XCTAssertTrue(viewModel.applyASRTranscript(
            Self.transcript("next surah one two"),
            windowID: 2,
            sampleRange: 400..<800
        ))

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
    func testAutoFlipsToPageContainingLastConfirmedWordDuringRecitation() {
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

        XCTAssertEqual(viewModel.pageNumber, 1)
        XCTAssertEqual(viewModel.mushafPage?.pageNumber, 1)
        XCTAssertEqual(viewModel.focusedAyah, 1)
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 1, ayah: 1, wordIndex: 3)), .pending)
    }

    @MainActor
    func testDisplayedAyahFollowsLastConfirmedAyahDuringRecitation() {
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

        XCTAssertEqual(viewModel.displayedAyah, 1)
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
    func testManualPageBrowsingKeepsRecitationSetupUnchanged() {
        let viewModel = RecitationViewModel(repository: InMemoryQuranRepository())
        viewModel.selectedSurah = 1
        viewModel.startAyah = 1

        viewModel.showNextMushafPage()

        XCTAssertEqual(viewModel.pageNumber, 2)
        XCTAssertEqual(viewModel.selectedSurah, 1)
        XCTAssertEqual(viewModel.startAyah, 1)

        viewModel.showPreviousMushafPage()

        XCTAssertEqual(viewModel.pageNumber, 1)
    }

    @MainActor
    func testManualPageBrowsingStopsAtMushafBoundaries() {
        let viewModel = RecitationViewModel(repository: InMemoryQuranRepository())
        viewModel.selectedSurah = 1

        viewModel.showPreviousMushafPage()
        XCTAssertEqual(viewModel.pageNumber, 1)

        viewModel.selectedSurah = 114
        XCTAssertEqual(viewModel.pageNumber, 604)

        viewModel.showNextMushafPage()
        XCTAssertEqual(viewModel.pageNumber, 604)
    }

    @MainActor
    func testLiveProgressResumesAutoFollowAfterManualBrowsing() {
        let viewModel = RecitationViewModel(repository: InMemoryQuranRepository())
        viewModel.selectedSurah = 1
        viewModel.startAyah = 1
        viewModel.isRecording = true
        viewModel.showNextMushafPage()

        viewModel.applyLocatedProgress(through: Self.references()[0], references: Self.references())

        XCTAssertEqual(viewModel.pageNumber, 1)
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
    func testProvisionalInitialHighlightPaintsOnlyMatchedWords() {
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
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 1, ayah: 1, wordIndex: 3)), .pending)
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
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 1, ayah: 1, wordIndex: 3)), .pending)
        XCTAssertEqual(viewModel.wordProgress.map(\.state), [.completed, .completed, .pending])
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
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 1, ayah: 2, wordIndex: 1)), .pending)
    }

    @MainActor
    func testLiveASRHighlightsNextSurahAfterCompletingSelectedSurah() {
        let repository = InMemoryQuranRepository()
        let viewModel = RecitationViewModel(repository: repository)
        viewModel.selectedSurah = 100
        viewModel.startAyah = 11
        viewModel.isRecording = true

        XCTAssertTrue(viewModel.applyASRTranscript(
            Self.transcript("hundred final one two"),
            windowID: 1,
            sampleRange: 0..<400
        ))
        XCTAssertEqual(viewModel.snapshot.currentAyah, 11)

        XCTAssertTrue(viewModel.applyASRTranscript(
            Self.transcript("next surah one two"),
            windowID: 2,
            sampleRange: 400..<800
        ))

        XCTAssertEqual(viewModel.snapshot.currentAyah, 1)
        XCTAssertEqual(viewModel.snapshot.completedWordCount, 4)
        XCTAssertEqual(viewModel.pageNumber, 101)
        XCTAssertEqual(viewModel.mushafPage?.pageNumber, 101)
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 101, ayah: 1, wordIndex: 1)), .completed)
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 101, ayah: 1, wordIndex: 4)), .completed)
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 101, ayah: 1, wordIndex: 5)), .pending)
    }

    @MainActor
    func testLiveASRUsesFreshSameWindowEvidenceAcrossSurahBoundary() {
        let repository = InMemoryQuranRepository()
        let viewModel = RecitationViewModel(repository: repository)
        viewModel.selectedSurah = 100
        viewModel.startAyah = 11
        viewModel.isRecording = true

        XCTAssertTrue(viewModel.applyASRTranscript(
            Self.transcript("hundred final one two next surah one two"),
            windowID: 1,
            sampleRange: 0..<800
        ))

        XCTAssertEqual(viewModel.snapshot.currentAyah, 1)
        XCTAssertEqual(viewModel.snapshot.completedWordCount, 4)
        XCTAssertEqual(viewModel.pageNumber, 101)
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 101, ayah: 1, wordIndex: 4)), .completed)
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 101, ayah: 1, wordIndex: 5)), .pending)
    }

    @MainActor
    func testLiveASRStopsAfterOneSameWindowAyahBoundary() {
        let repository = InMemoryQuranRepository()
        let viewModel = RecitationViewModel(repository: repository)
        viewModel.selectedSurah = 101
        viewModel.startAyah = 1
        viewModel.isRecording = true

        XCTAssertTrue(viewModel.applyASRTranscript(
            Self.transcript("next surah one two three second ayah one two third ayah one two"),
            windowID: 1,
            sampleRange: 0..<1_300
        ))

        XCTAssertEqual(viewModel.snapshot.currentAyah, 2)
        XCTAssertEqual(viewModel.snapshot.completedWordCount, 4)
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 101, ayah: 2, wordIndex: 4)), .completed)
        XCTAssertEqual(viewModel.progressState(for: repository.word(surah: 101, ayah: 3, wordIndex: 2)), .pending)
    }

    @MainActor
    func testSessionRecordStoresLastSurahAfterCrossSurahProgress() {
        let repository = InMemoryQuranRepository()
        let viewModel = RecitationViewModel(repository: repository)
        viewModel.selectedSurah = 100
        viewModel.startAyah = 11
        viewModel.isRecording = true
        viewModel.sessionStartedAt = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertTrue(viewModel.applyASRTranscript(
            Self.transcript("hundred final one two"),
            windowID: 1,
            sampleRange: 0..<400
        ))
        XCTAssertTrue(viewModel.applyASRTranscript(
            Self.transcript("next surah one two"),
            windowID: 2,
            sampleRange: 400..<800
        ))

        let record = viewModel.makeSessionRecord()

        XCTAssertEqual(record?.surah, 100)
        XCTAssertEqual(record?.lastSurah, 101)
        XCTAssertEqual(record?.lastAyah, 1)
        XCTAssertEqual(record?.lastWord, 4)
    }

    @MainActor
    func testLiveASRHoldsProgressWhenWordTimingIsMissing() {
        let viewModel = RecitationViewModel(repository: InMemoryQuranRepository())
        viewModel.selectedSurah = 100
        viewModel.startAyah = 11
        viewModel.isRecording = true
        let transcript = QuranSTTTranscript(
            text: "hundred final one two",
            tokenIDs: [],
            logProbabilities: ONNXLogProbabilities(values: [], timeStepCount: 0, vocabularySize: 0)
        )

        XCTAssertFalse(viewModel.applyASRTranscript(
            transcript,
            windowID: 1,
            sampleRange: 0..<400
        ))
        XCTAssertEqual(viewModel.snapshot.completedWordCount, 0)
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
        let words = text.split(separator: " ").map(String.init)
        return QuranSTTTranscript(
            text: text,
            tokenIDs: [],
            timedWords: words.enumerated().map { index, word in
                QuranSTTTimedWord(text: word, timeStepRange: index..<(index + 1))
            },
            logProbabilities: ONNXLogProbabilities(
                values: [],
                timeStepCount: words.count,
                vocabularySize: 0
            )
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
        let nextSurahSecondAyahWords = [
            Self.makeWord(id: 1021, surah: 101, ayah: 2, wordIndex: 1, text: "second"),
            Self.makeWord(id: 1022, surah: 101, ayah: 2, wordIndex: 2, text: "ayah"),
            Self.makeWord(id: 1023, surah: 101, ayah: 2, wordIndex: 3, text: "one"),
            Self.makeWord(id: 1024, surah: 101, ayah: 2, wordIndex: 4, text: "two")
        ]
        let nextSurahThirdAyahWords = [
            Self.makeWord(id: 1031, surah: 101, ayah: 3, wordIndex: 1, text: "third"),
            Self.makeWord(id: 1032, surah: 101, ayah: 3, wordIndex: 2, text: "ayah"),
            Self.makeWord(id: 1033, surah: 101, ayah: 3, wordIndex: 3, text: "one"),
            Self.makeWord(id: 1034, surah: 101, ayah: 3, wordIndex: 4, text: "two")
        ]
        let nextSurahPageWords = nextSurahWords + nextSurahSecondAyahWords + nextSurahThirdAyahWords
        let allWords = pageOneWords + pageTwoWords + surahOneHundredWords + nextSurahPageWords

        self.wordsByLocation = Dictionary(uniqueKeysWithValues: allWords.map { ($0.location, $0) })
        self.wordsByAyah = Dictionary(grouping: allWords) { "\($0.surah):\($0.ayah)" }
        self.pages = [
            1: Self.makePage(pageNumber: 1, words: pageOneWords),
            2: Self.makePage(pageNumber: 2, words: pageTwoWords),
            100: Self.makePage(pageNumber: 100, words: surahOneHundredWords),
            101: Self.makePage(pageNumber: 101, words: nextSurahPageWords),
            604: MushafPage(pageNumber: 604, lines: [])
        ]
        self.ayahPages = [
            "1:1": 1,
            "1:2": 2,
            "100:11": 100,
            "101:1": 101,
            "101:2": 101,
            "101:3": 101,
            "114:1": 604
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
            "101:1:5": 101,
            "101:2:1": 101,
            "101:2:2": 101,
            "101:2:3": 101,
            "101:2:4": 101,
            "101:3:1": 101,
            "101:3:2": 101,
            "101:3:3": 101,
            "101:3:4": 101
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
