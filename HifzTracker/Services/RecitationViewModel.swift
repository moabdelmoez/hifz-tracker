import Foundation
import Observation
import HifzCore
import OSLog

private let asrLogger = Logger(subsystem: "dev.mostafa.HifzTracker", category: "ASR")

@MainActor
@Observable
final class RecitationViewModel {
    var selectedSurah: Int = 73 {
        didSet { clampStartAyah(); loadSelectedAyah() }
    }
    var startAyah: Int = 4 {
        didSet { loadSelectedAyah() }
    }
    var snapshot = RecitationSnapshot()
    var wordProgress: [WordProgress] = []
    var mushafPage: MushafPage?
    var debugTranscript = ""
    var isRecording = false
    var assetMessage: String?

    private let repository: QuranRepository?
    private let microphone = MicrophoneCaptureService()
    private let transcriptLocator = TranscriptPositionLocator(minimumRunLength: 2)
    private var reducer = RecitationStateReducer()
    private var sessionStartedAt: Date?
    private var liveASRService: LiveQuranTranscriptionService?
    private var liveSampleWindow = LiveASRSampleWindow()
    private var transcriptionTask: Task<Void, Never>?
    private var wordStatesByLocation: [String: WordProgressState] = [:]

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
        repository?.pageNumber(surah: selectedSurah, ayah: startAyah) ?? selectedSurah
    }

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    func startRecording() {
        let request = RecitationSessionRequest(surah: selectedSurah, startAyah: startAyah)
        reducer = RecitationStateReducer()
        snapshot = reducer.reduce(.startRequested(request))
        asrLogger.info("[DEBUG-asr73] start_requested surah=\(self.selectedSurah, privacy: .public) ayah=\(self.startAyah, privacy: .public)")
        Task {
            do {
                let service = try AppASRFactory.makeLiveService()
                liveASRService = service
                liveSampleWindow.reset()
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
                asrLogger.info("[DEBUG-asr73] recording_started surah=\(self.selectedSurah, privacy: .public) ayah=\(self.startAyah, privacy: .public)")
            } catch {
                asrLogger.error("[DEBUG-asr73] start_failed error=\(error.localizedDescription, privacy: .public)")
                snapshot = reducer.reduce(.fail(error.localizedDescription))
                isRecording = false
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
        asrLogger.info("[DEBUG-asr73] stop_requested phase=\(self.snapshot.phase.rawValue, privacy: .public) completed=\(self.snapshot.completedWordCount, privacy: .public)")
        microphone.stop()
        transcriptionTask?.cancel()
        transcriptionTask = nil
        liveASRService = nil
        liveSampleWindow.reset()
        snapshot = reducer.reduce(.stop)
        isRecording = false
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
            let words = try repository?.words(surah: selectedSurah, ayah: startAyah) ?? []
            wordProgress = words.map { WordProgress(wordIndex: $0.wordIndex, text: $0.text, state: .pending) }
            if !wordProgress.isEmpty {
                wordProgress[0].state = .current
            }
            mushafPage = try repository?.mushafPage(pageNumber: pageNumber)
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
        guard let windowSamples = liveSampleWindow.append(samples) else { return }
        guard transcriptionTask == nil else {
            asrLogger.info("[DEBUG-asr73] window_emit_skipped busy=true emittedSamples=\(windowSamples.count, privacy: .public)")
            return
        }

        asrLogger.info("[DEBUG-asr73] window_emit samples=\(windowSamples.count, privacy: .public)")
        transcriptionTask = Task { [weak self, service, windowSamples] in
            do {
                let startedAt = ContinuousClock.now
                asrLogger.info("[DEBUG-asr73] transcribe_start samples=\(windowSamples.count, privacy: .public)")
                let transcript = try await service.transcribe(samples: windowSamples)
                let elapsed = startedAt.duration(to: .now).components
                let milliseconds = (elapsed.seconds * 1_000) + (elapsed.attoseconds / 1_000_000_000_000_000)
                asrLogger.info("[DEBUG-asr73] transcribe_done ms=\(milliseconds, privacy: .public) tokenCount=\(transcript.tokenIDs.count, privacy: .public) text=\(transcript.text, privacy: .public)")
                self?.applyASRTranscript(transcript)
            } catch is CancellationError {
                asrLogger.info("[DEBUG-asr73] transcribe_cancelled")
            } catch {
                asrLogger.error("[DEBUG-asr73] transcribe_failed error=\(error.localizedDescription, privacy: .public)")
                self?.handleASRError(error)
            }
            self?.clearTranscriptionTask()
        }
    }

    private func applyASRTranscript(_ transcript: QuranSTTTranscript) {
        guard isRecording else { return }

        debugTranscript = transcript.text
        let recognizedWords = QuranTextNormalizer
            .asrComparable(transcript.text)
            .split(separator: " ")
            .map(String.init)
        asrLogger.info("[DEBUG-asr73] transcript_words count=\(recognizedWords.count, privacy: .public) normalized=\(recognizedWords.joined(separator: " "), privacy: .public)")
        guard !recognizedWords.isEmpty else {
            asrLogger.info("[DEBUG-asr73] transcript_empty finding_place=true")
            snapshot = reducer.reduce(.findingPlace)
            return
        }

        let expectedReferences = referenceWordsForSelectedSurah()
        asrLogger.info("[DEBUG-asr73] expected_scope count=\(expectedReferences.count, privacy: .public) first=\(expectedReferences.first?.location ?? "none", privacy: .public) last=\(expectedReferences.last?.location ?? "none", privacy: .public)")
        guard !expectedReferences.isEmpty else { return }

        guard let location = transcriptLocator.locate(expected: expectedReferences, recognizedWords: recognizedWords) else {
            asrLogger.info("[DEBUG-asr73] no_location_match finding_place=true")
            snapshot = reducer.reduce(.findingPlace)
            return
        }

        asrLogger.info("[DEBUG-asr73] located ayah=\(location.completedThrough.ayah, privacy: .public) word=\(location.completedThrough.wordIndex, privacy: .public) matched=\(location.matchedWordCount, privacy: .public) recognizedRange=\(location.recognizedRange.lowerBound, privacy: .public)..<\(location.recognizedRange.upperBound, privacy: .public)")
        snapshot = reducer.reduce(.progressAdvanced(
            ayah: location.completedThrough.ayah,
            completedWordCount: location.completedThrough.wordIndex
        ))
        applyProgress(through: location.completedThrough, references: expectedReferences)
    }

    private func handleASRError(_ error: Error) {
        guard isRecording else { return }
        snapshot = reducer.reduce(.fail(error.localizedDescription))
        microphone.stop()
        isRecording = false
    }

    private func clearTranscriptionTask() {
        transcriptionTask = nil
    }

    private func referenceWordsForSelectedSurah() -> [RecitationWordReference] {
        guard let repository else { return [] }

        var references: [RecitationWordReference] = []
        for ayah in startAyah...selectedSurahInfo.ayahCount {
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

    private func applyProgress(through completedWord: RecitationWordReference, references: [RecitationWordReference]) {
        guard let completedOffset = references.firstIndex(where: {
            $0.surah == completedWord.surah &&
            $0.ayah == completedWord.ayah &&
            $0.wordIndex == completedWord.wordIndex
        }) else { return }

        for reference in references.prefix(completedOffset + 1) {
            wordStatesByLocation[reference.location] = .completed
        }
        if references.indices.contains(completedOffset + 1) {
            wordStatesByLocation[references[completedOffset + 1].location] = .current
        }
        syncSelectedAyahWordProgress(through: completedWord)
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

    private func wordLocation(surah: Int, ayah: Int, wordIndex: Int) -> String {
        "\(surah):\(ayah):\(wordIndex)"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
