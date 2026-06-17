import Foundation
import Observation
import HifzCore
import OSLog

private let asrLogger = Logger(subsystem: "dev.mostafa.HifzTracker", category: "ASR")

@MainActor
@Observable
final class RecitationViewModel {
    var selectedSurah: Int = 73 {
        didSet {
            invalidateReferenceScope()
            clampStartAyah()
            loadSelectedAyah()
        }
    }
    var startAyah: Int = 1 {
        didSet {
            invalidateReferenceScope()
            loadSelectedAyah()
        }
    }
    var snapshot = RecitationSnapshot()
    var wordProgress: [WordProgress] = []
    var mushafPage: MushafPage?
    var debugTranscript = ""
    var audioLevel = 0.0
    var isRecording = false
    var assetMessage: String?
    var focusedAyah: Int {
        focusedReference?.ayah ?? snapshot.currentAyah ?? startAyah
    }
    var displayedAyah: Int {
        focusedAyah
    }

    private let repository: QuranRepository?
    private let microphone = MicrophoneCaptureService()
    private var transcriptLocator = ProgressiveTranscriptLocator()
    private var reducer = RecitationStateReducer()
    private var sessionStartedAt: Date?
    private var liveASRService: LiveQuranTranscriptionService?
    private var liveSampleWindow = LiveASRSampleWindow()
    private var liveASRRequestScheduler = LiveASRRequestScheduler()
    private var audioLevelMeter = AudioLevelMeter()
    private var transcriptionTask: Task<Void, Never>?
    private var wordStatesByLocation: [String: WordProgressState] = [:]
    private var displayedPageNumber = 73
    private var focusedReference: RecitationWordReference?
    private var referenceScopeCache: ReferenceScopeCache?

    init(repository: QuranRepository? = AppQuranRepositoryFactory.makeRepository()) {
        self.repository = repository
        loadSelectedAyah()
        assetMessage = AppAssetStatus.summary()
    }

    var selectedSurahInfo: SurahInfo {
        SurahCatalog.surah(selectedSurah) ?? SurahCatalog.all[72]
    }

    var statusText: String {
        switch snapshot.phase {
        case .idle: "Ready"
        case .requestingPermission: "Requesting microphone"
        case .listening: "Listening"
        case .findingPlace: "Finding place"
        case .locked: "Locked"
        case .progressing: "Progress"
        case .correctionNeeded: "Correction needed"
        case .uncertain: "Uncertain"
        case .stopped: "Stopped"
        case .failed: "Failed"
        }
    }

    var pageNumber: Int {
        displayedPageNumber
    }

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    func startRecording() {
        let request = RecitationSessionRequest(surah: selectedSurah, startAyah: startAyah)
        reducer = RecitationStateReducer()
        resetAudioLevel()
        snapshot = reducer.reduce(.startRequested(request))
        Task {
            do {
                let service = try AppASRFactory.makeLiveService()
                liveASRService = service
                liveSampleWindow.reset()
                liveASRRequestScheduler.reset()
                transcriptLocator.reset()
                _ = referenceIndexForSelectedSurah()
                transcriptionTask?.cancel()
                transcriptionTask = nil

                try await microphone.startStreamingAudio { [weak self] samples in
                    Task { @MainActor in
                        self?.handleMicrophoneSamples(samples)
                    }
                }
                snapshot = reducer.reduce(.permissionGranted)
                snapshot = reducer.reduce(.placeLocked(ayah: startAyah, word: 1))
                isRecording = true
                sessionStartedAt = Date()
                debugTranscript = ""
            } catch {
                asrLogger.error("start_failed error=\(error.localizedDescription, privacy: .public)")
                snapshot = reducer.reduce(.fail(error.localizedDescription))
                isRecording = false
                resetAudioLevel()
            }
        }
    }

    func advanceDemoProgress() {
        guard isRecording else { return }
        let completed = min(wordProgress.count, max(1, snapshot.completedWordCount + 1))
        snapshot = reducer.reduce(.progressAdvanced(ayah: startAyah, completedWordCount: completed))
        applyProgress(completed: completed)
        debugTranscript = wordProgress
            .filter { $0.state == .completed }
            .map(\.text)
            .joined(separator: " ")
    }

    func markDemoCorrection() {
        guard isRecording else { return }
        let current = max(1, min(wordProgress.count, snapshot.completedWordCount + 1))
        let expected = wordProgress[safe: current - 1]?.text ?? "expected"
        let mismatch = AlignmentMismatch(expectedWordIndex: current, expectedWord: expected, recognizedWord: "غير مطابق")
        snapshot = reducer.reduce(.strongMismatch(mismatch))
        snapshot = reducer.reduce(.strongMismatch(mismatch))
        applyCorrection(wordIndex: current)
    }

    func stopRecording() {
        microphone.stop()
        transcriptionTask?.cancel()
        transcriptionTask = nil
        liveASRService = nil
        liveSampleWindow.reset()
        liveASRRequestScheduler.reset()
        transcriptLocator.reset()
        snapshot = reducer.reduce(.stop)
        isRecording = false
        resetAudioLevel()
    }

    func makeSessionRecord() -> SessionRecord? {
        guard let started = sessionStartedAt else { return nil }
        return SessionRecord(
            startedAt: started,
            endedAt: Date(),
            surah: selectedSurah,
            startAyah: startAyah,
            lastAyah: snapshot.currentAyah ?? startAyah,
            lastWord: max(1, min(wordProgress.count, snapshot.completedWordCount)),
            completedWordCount: snapshot.completedWordCount,
            correctionEvents: snapshot.correctionEvents
        )
    }

    func progressState(for word: QuranWord) -> WordProgressState {
        wordStatesByLocation[wordLocation(surah: word.surah, ayah: word.ayah, wordIndex: word.wordIndex)] ?? .pending
    }

    private func loadSelectedAyah() {
        do {
            let selectedPageNumber = repository?.pageNumber(surah: selectedSurah, ayah: startAyah) ?? selectedSurah
            displayedPageNumber = selectedPageNumber
            focusedReference = nil
            let words = try repository?.words(surah: selectedSurah, ayah: startAyah) ?? []
            wordProgress = words.map { WordProgress(wordIndex: $0.wordIndex, text: $0.text, state: .pending) }
            if !wordProgress.isEmpty {
                wordProgress[0].state = .current
            }
            mushafPage = try repository?.mushafPage(pageNumber: selectedPageNumber)
            resetDisplayedWordStates()
        } catch {
            snapshot = RecitationSnapshot(phase: .failed, message: error.localizedDescription)
            wordProgress = []
            mushafPage = nil
            wordStatesByLocation = [:]
        }
    }

    private func clampStartAyah() {
        let maxAyah = selectedSurahInfo.ayahCount
        if startAyah > maxAyah {
            startAyah = maxAyah
        }
        if startAyah < 1 {
            startAyah = 1
        }
    }

    private func applyProgress(completed: Int) {
        wordProgress = wordProgress.map { word in
            if word.wordIndex <= completed {
                WordProgress(wordIndex: word.wordIndex, text: word.text, state: .completed)
            } else if word.wordIndex == completed + 1 {
                WordProgress(wordIndex: word.wordIndex, text: word.text, state: .current)
            } else {
                WordProgress(wordIndex: word.wordIndex, text: word.text, state: .pending)
            }
        }
        syncSelectedAyahProgressToPageStates()
    }

    private func applyCorrection(wordIndex: Int) {
        wordProgress = wordProgress.map { word in
            if word.wordIndex == wordIndex {
                WordProgress(wordIndex: word.wordIndex, text: word.text, state: .correctionNeeded)
            } else {
                word
            }
        }
        wordStatesByLocation[wordLocation(surah: selectedSurah, ayah: startAyah, wordIndex: wordIndex)] = .correctionNeeded
    }

    private func handleMicrophoneSamples(_ samples: [Float]) {
        guard isRecording, let service = liveASRService else { return }
        audioLevel = audioLevelMeter.update(with: samples)
        guard let windowSamples = liveSampleWindow.append(samples) else { return }
        submitLiveASRWindow(windowSamples, service: service)
    }

    private func submitLiveASRWindow(_ samples: [Float], service: LiveQuranTranscriptionService) {
        guard let requestSamples = liveASRRequestScheduler.submit(samples) else { return }
        startLiveASRTranscription(samples: requestSamples, service: service)
    }

    private func startLiveASRTranscription(samples: [Float], service: LiveQuranTranscriptionService) {
        transcriptionTask = Task { [weak self, service, samples] in
            do {
                let transcript = try await service.transcribe(samples: samples)
                self?.applyASRTranscript(transcript)
            } catch is CancellationError {
            } catch {
                asrLogger.error("transcribe_failed error=\(error.localizedDescription, privacy: .public)")
                self?.handleASRError(error)
            }
            self?.completeLiveASRTranscription()
        }
    }

    private func completeLiveASRTranscription() {
        transcriptionTask = nil
        guard isRecording, let service = liveASRService else {
            liveASRRequestScheduler.reset()
            return
        }
        guard let pendingSamples = liveASRRequestScheduler.completeActiveRequest() else { return }
        startLiveASRTranscription(samples: pendingSamples, service: service)
    }

    private func applyASRTranscript(_ transcript: QuranSTTTranscript) {
        guard isRecording else { return }

        debugTranscript = transcript.text
        let recognizedWords = QuranTextNormalizer
            .asrComparable(transcript.text)
            .split(separator: " ")
            .map(String.init)
        guard !recognizedWords.isEmpty else {
            _ = markFindingPlaceIfNeeded()
            return
        }

        guard let referenceIndex = referenceIndexForSelectedSurah() else { return }
        let expectedReferences = referenceIndex.expected
        guard !expectedReferences.isEmpty else { return }

        guard let location = transcriptLocator.locate(index: referenceIndex, recognizedWords: recognizedWords) else {
            _ = markFindingPlaceIfNeeded()
            return
        }

        snapshot = reducer.reduce(.progressAdvanced(
            ayah: location.completedThrough.ayah,
            completedWordCount: location.completedThrough.wordIndex
        ))
        applyLocatedProgress(through: location.completedThrough, references: expectedReferences)
    }

    func applyLocatedProgress(through completedWord: RecitationWordReference, references: [RecitationWordReference]) {
        guard let completedOffset = references.firstIndex(where: {
            $0.surah == completedWord.surah &&
            $0.ayah == completedWord.ayah &&
            $0.wordIndex == completedWord.wordIndex
        }) else { return }

        for reference in references.prefix(completedOffset + 1) {
            wordStatesByLocation[reference.location] = .completed
        }

        let focusedReference: RecitationWordReference
        if references.indices.contains(completedOffset + 1) {
            focusedReference = references[completedOffset + 1]
            wordStatesByLocation[focusedReference.location] = .current
        } else {
            focusedReference = completedWord
        }

        self.focusedReference = focusedReference
        syncSelectedAyahWordProgress(through: completedWord)
        autoFlipDisplayedPageIfNeeded(toFollow: focusedReference)
    }

    private func handleASRError(_ error: Error) {
        guard isRecording else { return }
        snapshot = reducer.reduce(.fail(error.localizedDescription))
        microphone.stop()
        isRecording = false
        resetAudioLevel()
    }

    private func resetAudioLevel() {
        audioLevelMeter.reset()
        audioLevel = audioLevelMeter.level
    }

    @discardableResult
    private func markFindingPlaceIfNeeded() -> Bool {
        guard snapshot.completedWordCount == 0 else { return false }
        snapshot = reducer.reduce(.findingPlace)
        return true
    }

    private func referenceIndexForSelectedSurah() -> TranscriptPositionIndex? {
        let finalAyah = selectedSurahInfo.ayahCount
        if let referenceScopeCache,
           referenceScopeCache.surah == selectedSurah,
           referenceScopeCache.startAyah == startAyah,
           referenceScopeCache.finalAyah == finalAyah {
            return referenceScopeCache.index
        }

        let references = referenceWordsForSelectedSurah(finalAyah: finalAyah)
        let index = TranscriptPositionIndex(expected: references)
        referenceScopeCache = ReferenceScopeCache(
            surah: selectedSurah,
            startAyah: startAyah,
            finalAyah: finalAyah,
            index: index
        )
        return index
    }

    private func referenceWordsForSelectedSurah(finalAyah: Int) -> [RecitationWordReference] {
        guard let repository else { return [] }

        var references: [RecitationWordReference] = []
        for ayah in startAyah...finalAyah {
            let text = (try? repository.referenceText(surah: selectedSurah, ayah: ayah)) ?? ""
            let referenceWords = QuranReferenceWords.wordsForAyah(text, surah: selectedSurah, ayah: ayah)
            guard !referenceWords.isEmpty else { continue }

            let glyphWords = (try? repository.words(surah: selectedSurah, ayah: ayah)) ?? []
            for (offset, word) in referenceWords.enumerated() {
                let wordIndex = glyphWords.indices.contains(offset) ? glyphWords[offset].wordIndex : offset + 1
                references.append(RecitationWordReference(
                    surah: selectedSurah,
                    ayah: ayah,
                    wordIndex: wordIndex,
                    text: word
                ))
            }
        }
        return references
    }

    private func invalidateReferenceScope() {
        referenceScopeCache = nil
        transcriptLocator.reset()
    }

    private func applyUncertain(wordIndex: Int) {
        wordProgress = wordProgress.map { word in
            if word.wordIndex == wordIndex {
                WordProgress(wordIndex: word.wordIndex, text: word.text, state: .uncertain)
            } else {
                word
            }
        }
        wordStatesByLocation[wordLocation(surah: selectedSurah, ayah: startAyah, wordIndex: wordIndex)] = .uncertain
    }

    private func resetDisplayedWordStates() {
        var states: [String: WordProgressState] = [:]
        for word in mushafPage?.lines.flatMap(\.words) ?? [] {
            states[wordLocation(surah: word.surah, ayah: word.ayah, wordIndex: word.wordIndex)] = .pending
        }
        states[wordLocation(surah: selectedSurah, ayah: startAyah, wordIndex: 1)] = .current
        wordStatesByLocation = states
    }

    private func syncSelectedAyahWordProgress(through completedWord: RecitationWordReference) {
        wordProgress = wordProgress.map { word in
            let state: WordProgressState
            if completedWord.ayah > startAyah || word.wordIndex <= completedWord.wordIndex {
                state = .completed
            } else if completedWord.ayah == startAyah, word.wordIndex == completedWord.wordIndex + 1 {
                state = .current
            } else {
                state = .pending
            }
            return WordProgress(wordIndex: word.wordIndex, text: word.text, state: state)
        }
    }

    private func syncSelectedAyahProgressToPageStates() {
        for word in wordProgress {
            wordStatesByLocation[wordLocation(surah: selectedSurah, ayah: startAyah, wordIndex: word.wordIndex)] = word.state
        }
    }

    private func autoFlipDisplayedPageIfNeeded(toFollow reference: RecitationWordReference) {
        guard isRecording, let repository else { return }
        guard let targetPageNumber = repository.pageNumber(
            surah: reference.surah,
            ayah: reference.ayah,
            wordIndex: reference.wordIndex
        ) else { return }
        guard targetPageNumber != displayedPageNumber else { return }
        guard (1...604).contains(targetPageNumber) else { return }

        do {
            let page = try repository.mushafPage(pageNumber: targetPageNumber)
            displayedPageNumber = targetPageNumber
            mushafPage = page
        } catch {
            asrLogger.error("auto_page_flip_failed page=\(targetPageNumber, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
        }
    }

    private func wordLocation(surah: Int, ayah: Int, wordIndex: Int) -> String {
        "\(surah):\(ayah):\(wordIndex)"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct ReferenceScopeCache {
    var surah: Int
    var startAyah: Int
    var finalAyah: Int
    var index: TranscriptPositionIndex
}
