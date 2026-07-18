import Foundation
import Observation
import HifzCore
import OSLog

private let asrLogger = Logger(subsystem: "dev.mostafa.HifzTracker", category: "ASR")

@MainActor
@Observable
final class RecitationViewModel {
    private static let voiceOnsetLevel = 0.02
    private static let mushafPageRange = 1...604

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
    var hideRecitationText = false
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
    var sessionStartedAt: Date?
    private var liveASRService: LiveQuranTranscriptionService?
    private var liveSampleWindow = LiveASRSampleWindow()
    private var liveASRRequestScheduler = LiveASRRequestScheduler()
    private var liveASRTimingProbe = LiveASRTimingProbe()
    private let liveASRLocatorOutcomeProbe = LiveASRLocatorOutcomeProbe()
    private var provisionalInitialHighlightTracker = ProvisionalInitialHighlightTracker()
    private var provisionalHighlightLocation: TranscriptLocation?
    private var provisionalVisualLocations: Set<String> = []
    private var audioLevelMeter = AudioLevelMeter()
    private var transcriptionTask: Task<Void, Never>?
    private var wordStatesByLocation: [String: WordProgressState] = [:]
    private var referenceWordCountByAyah: [String: Int] = [:]
    private var displayedPageNumber = 73
    private var focusedReference: RecitationWordReference?
    private var lastCompletedReference: RecitationWordReference?
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
        loadSelectedAyah()
        let startTimestamp = nowNanoseconds()
        liveASRTimingProbe.startRequested(atNanoseconds: startTimestamp)
        asrLogger.info("live_asr_timing event=start_requested")
        let request = RecitationSessionRequest(surah: selectedSurah, startAyah: startAyah)
        reducer = RecitationStateReducer()
        resetAudioLevel()
        snapshot = reducer.reduce(.startRequested(request))
        Task {
            do {
                let service = try AppASRFactory.makeLiveService()
                logLiveASREvent("service_ready", metrics: liveASRTimingProbe.eventMetrics(atNanoseconds: nowNanoseconds()))
                liveASRService = service
                liveSampleWindow.reset()
                liveASRRequestScheduler.reset()
                transcriptLocator.reset()
                clearAndResetProvisionalInitialHighlightState()
                let referenceIndex = referenceIndexForSelectedSurah()
                logLiveASREvent(
                    "reference_ready",
                    metrics: liveASRTimingProbe.eventMetrics(atNanoseconds: nowNanoseconds()),
                    referenceCount: referenceIndex?.count ?? 0
                )
                transcriptionTask?.cancel()
                transcriptionTask = nil

                try await microphone.startStreamingAudio { [weak self] samples in
                    Task { @MainActor in
                        self?.handleMicrophoneSamples(samples)
                    }
                }
                logLiveASREvent("microphone_ready", metrics: liveASRTimingProbe.eventMetrics(atNanoseconds: nowNanoseconds()))
                snapshot = reducer.reduce(.permissionGranted)
                snapshot = reducer.reduce(.placeLocked(ayah: startAyah, word: 1))
                isRecording = true
                sessionStartedAt = Date()
                lastCompletedReference = nil
                debugTranscript = ""
                let recordingMetrics = liveASRTimingProbe.recordingStarted(atNanoseconds: nowNanoseconds())
                logLiveASREvent("recording_started", metrics: recordingMetrics)
            } catch {
                asrLogger.error("start_failed error=\(error.localizedDescription, privacy: .public)")
                snapshot = reducer.reduce(.fail(error.localizedDescription))
                isRecording = false
                liveASRTimingProbe.reset()
                resetAudioLevel()
            }
        }
    }

    func stopRecording() {
        microphone.stop()
        transcriptionTask?.cancel()
        transcriptionTask = nil
        liveASRService = nil
        liveSampleWindow.reset()
        liveASRRequestScheduler.reset()
        liveASRTimingProbe.reset()
        transcriptLocator.reset()
        clearAndResetProvisionalInitialHighlightState()
        snapshot = reducer.reduce(.stop)
        isRecording = false
        lastCompletedReference = nil
        resetAudioLevel()
    }

    func makeSessionRecord() -> SessionRecord? {
        guard let started = sessionStartedAt else { return nil }
        return SessionRecord(
            startedAt: started,
            endedAt: Date(),
            surah: selectedSurah,
            startAyah: startAyah,
            lastSurah: lastCompletedReference?.surah ?? selectedSurah,
            lastAyah: snapshot.currentAyah ?? startAyah,
            lastWord: lastCompletedReference?.wordIndex ?? max(1, min(wordProgress.count, snapshot.completedWordCount)),
            completedWordCount: snapshot.completedWordCount,
            correctionEvents: snapshot.correctionEvents
        )
    }

    func showNextMushafPage() {
        displayMushafPage(displayedPageNumber + 1)
    }

    func showPreviousMushafPage() {
        displayMushafPage(displayedPageNumber - 1)
    }

    func progressState(for word: QuranWord) -> WordProgressState {
        let state = wordStatesByLocation[wordLocation(surah: word.surah, ayah: word.ayah, wordIndex: word.wordIndex)] ?? .pending
        guard state == .pending,
              let markerState = inheritedAyahMarkerState(for: word) else {
            return state
        }
        return markerState
    }

    func isMushafTextVisible(for word: QuranWord) -> Bool {
        isRecitationTextVisible(
            state: progressState(for: word),
            surah: word.surah,
            ayah: word.ayah
        )
    }

    func isSelectedAyahWordTextVisible(for word: WordProgress) -> Bool {
        isRecitationTextVisible(
            state: word.state,
            surah: selectedSurah,
            ayah: startAyah
        )
    }

    private func loadSelectedAyah() {
        do {
            let selectedPageNumber = repository?.pageNumber(surah: selectedSurah, ayah: startAyah) ?? selectedSurah
            displayedPageNumber = selectedPageNumber
            focusedReference = nil
            lastCompletedReference = nil
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

    private func handleMicrophoneSamples(_ samples: [Float]) {
        guard isRecording, let service = liveASRService else { return }
        audioLevel = audioLevelMeter.update(with: samples)
        if audioLevel >= Self.voiceOnsetLevel,
           let metrics = liveASRTimingProbe.voiceOnset(atNanoseconds: nowNanoseconds()) {
            logLiveASREvent("voice_onset", metrics: metrics)
        }
        guard let window = liveSampleWindow.append(samples) else { return }
        submitLiveASRWindow(window, service: service)
    }

    private func submitLiveASRWindow(_ window: LiveASRAudioWindow, service: LiveQuranTranscriptionService) {
        guard let requestWindow = liveASRRequestScheduler.submit(window) else {
            let metrics = liveASRTimingProbe.pendingWindow(
                .stored,
                sampleCount: window.samples.count,
                sampleRate: liveSampleWindow.sampleRate,
                atNanoseconds: nowNanoseconds()
            )
            logLiveASRPendingWindow(metrics)
            return
        }
        startLiveASRTranscription(window: requestWindow, service: service)
    }

    private func startLiveASRTranscription(
        window: LiveASRAudioWindow,
        service: LiveQuranTranscriptionService
    ) {
        let timingToken = liveASRTimingProbe.transcriptionStarted(
            sampleCount: window.samples.count,
            sampleRate: liveSampleWindow.sampleRate,
            atNanoseconds: nowNanoseconds()
        )
        logLiveASRTranscriptionStarted(timingToken)

        transcriptionTask = Task { [weak self, service, window, timingToken] in
            do {
                let transcript = try await service.transcribe(samples: window.samples)
                guard let self else { return }
                let metrics = self.liveASRTimingProbe.transcriptionFinished(
                    timingToken,
                    atNanoseconds: self.nowNanoseconds()
                )
                self.logLiveASRTranscriptionFinished(metrics)
                let didApplyHighlight = self.applyASRTranscript(
                    transcript,
                    windowID: timingToken.windowID,
                    sampleRange: window.sampleRange
                )
                if didApplyHighlight {
                    self.logLiveASRHighlightApplied(windowID: timingToken.windowID)
                }
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
        guard let pendingWindow = liveASRRequestScheduler.completeActiveRequest() else { return }
        let metrics = liveASRTimingProbe.pendingWindow(
            .handoffStarted,
            sampleCount: pendingWindow.samples.count,
            sampleRate: liveSampleWindow.sampleRate,
            atNanoseconds: nowNanoseconds()
        )
        logLiveASRPendingWindow(metrics)
        startLiveASRTranscription(window: pendingWindow, service: service)
    }

    private func nowNanoseconds() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    private func logLiveASRPendingWindow(_ metrics: LiveASRTimingProbe.PendingWindowMetrics) {
        let elapsedMilliseconds = metrics.elapsedSinceRecordingStartMilliseconds ?? -1
        switch metrics.event {
        case .stored:
            asrLogger.info("live_asr_timing event=pending_window_stored pending_store_count=\(metrics.count, privacy: .public) sample_count=\(metrics.sampleCount, privacy: .public) audio_ms=\(metrics.audioMilliseconds, privacy: .public) elapsed_since_recording_start_ms=\(elapsedMilliseconds, privacy: .public)")
        case .handoffStarted:
            asrLogger.info("live_asr_timing event=pending_window_handoff_started handoff_count=\(metrics.count, privacy: .public) sample_count=\(metrics.sampleCount, privacy: .public) audio_ms=\(metrics.audioMilliseconds, privacy: .public) elapsed_since_recording_start_ms=\(elapsedMilliseconds, privacy: .public)")
        }
    }

    private func logLiveASRTranscriptionStarted(_ token: LiveASRTimingProbe.TranscriptionToken) {
        asrLogger.info("live_asr_timing event=transcription_started window_id=\(token.windowID, privacy: .public) sample_count=\(token.sampleCount, privacy: .public) audio_ms=\(token.audioMilliseconds, privacy: .public)")
    }

    private func logLiveASRTranscriptionFinished(_ metrics: LiveASRTimingProbe.TranscriptionFinishedMetrics) {
        let firstLatencyMilliseconds = metrics.firstTranscriptLatencyMilliseconds ?? -1
        let firstSinceStartRequestMilliseconds = metrics.firstTranscriptEventMetrics?.elapsedSinceStartRequestMilliseconds ?? -1
        let firstSinceVoiceOnsetMilliseconds = metrics.firstTranscriptEventMetrics?.elapsedSinceVoiceOnsetMilliseconds ?? -1
        let intervalMilliseconds = metrics.transcriptIntervalMilliseconds ?? -1
        let averageIntervalMilliseconds = metrics.averageTranscriptIntervalMilliseconds ?? -1
        asrLogger.info("live_asr_timing event=transcription_finished window_id=\(metrics.windowID, privacy: .public) sample_count=\(metrics.sampleCount, privacy: .public) audio_ms=\(metrics.audioMilliseconds, privacy: .public) processing_ms=\(metrics.processingMilliseconds, privacy: .public) first_transcript_latency_ms=\(firstLatencyMilliseconds, privacy: .public) first_transcript_since_start_request_ms=\(firstSinceStartRequestMilliseconds, privacy: .public) first_transcript_since_voice_onset_ms=\(firstSinceVoiceOnsetMilliseconds, privacy: .public) transcript_interval_ms=\(intervalMilliseconds, privacy: .public) average_transcript_interval_ms=\(averageIntervalMilliseconds, privacy: .public)")
    }

    private func logLiveASRHighlightApplied(windowID: Int) {
        let metrics = liveASRTimingProbe.highlightApplied(atNanoseconds: nowNanoseconds())
        let elapsedSinceStartRequestMilliseconds = metrics?.elapsedSinceStartRequestMilliseconds ?? -1
        let elapsedSinceRecordingStartMilliseconds = metrics?.elapsedSinceRecordingStartMilliseconds ?? -1
        let elapsedSinceVoiceOnsetMilliseconds = metrics?.elapsedSinceVoiceOnsetMilliseconds ?? -1
        asrLogger.info("live_asr_timing event=highlight_applied window_id=\(windowID, privacy: .public) first_highlight_since_start_request_ms=\(elapsedSinceStartRequestMilliseconds, privacy: .public) first_highlight_since_recording_start_ms=\(elapsedSinceRecordingStartMilliseconds, privacy: .public) first_highlight_since_voice_onset_ms=\(elapsedSinceVoiceOnsetMilliseconds, privacy: .public)")
    }

    private func logLiveASREvent(
        _ event: String,
        metrics: LiveASRTimingProbe.EventMetrics,
        referenceCount: Int = -1
    ) {
        let elapsedSinceStartRequestMilliseconds = metrics.elapsedSinceStartRequestMilliseconds ?? -1
        let elapsedSinceRecordingStartMilliseconds = metrics.elapsedSinceRecordingStartMilliseconds ?? -1
        let elapsedSinceVoiceOnsetMilliseconds = metrics.elapsedSinceVoiceOnsetMilliseconds ?? -1
        asrLogger.info("live_asr_timing event=\(event, privacy: .public) elapsed_since_start_request_ms=\(elapsedSinceStartRequestMilliseconds, privacy: .public) elapsed_since_recording_start_ms=\(elapsedSinceRecordingStartMilliseconds, privacy: .public) elapsed_since_voice_onset_ms=\(elapsedSinceVoiceOnsetMilliseconds, privacy: .public) reference_count=\(referenceCount, privacy: .public)")
    }

    private func logLiveASRLocatorOutcome(_ metrics: LiveASRLocatorOutcomeProbe.Metrics) {
        let matchedWordCount = metrics.matchedWordCount ?? -1
        let requiredWordCount = metrics.requiredWordCount ?? -1
        let completedOffset = metrics.completedOffset ?? -1
        let acceptedOffset = metrics.acceptedOffset ?? -1
        let completedSurah = metrics.completedSurah ?? -1
        let completedAyah = metrics.completedAyah ?? -1
        let completedWord = metrics.completedWord ?? -1
        asrLogger.info("live_asr_locator event=locator_outcome window_id=\(metrics.windowID, privacy: .public) reason=\(metrics.reason, privacy: .public) recognized_word_count=\(metrics.recognizedWordCount, privacy: .public) expected_reference_count=\(metrics.expectedReferenceCount, privacy: .public) completed_word_count_before=\(metrics.completedWordCountBefore, privacy: .public) matched_word_count=\(matchedWordCount, privacy: .public) required_word_count=\(requiredWordCount, privacy: .public) completed_offset=\(completedOffset, privacy: .public) accepted_offset=\(acceptedOffset, privacy: .public) completed_surah=\(completedSurah, privacy: .public) completed_ayah=\(completedAyah, privacy: .public) completed_word=\(completedWord, privacy: .public)")
    }

    private func logProvisionalInitialHighlight(
        state: String,
        windowID: Int,
        location: TranscriptLocation?,
        confirmationCount: Int
    ) {
        let matchedWordCount = location?.matchedWordCount ?? -1
        let completedSurah = location?.completedThrough.surah ?? -1
        let completedAyah = location?.completedThrough.ayah ?? -1
        let completedWord = location?.completedThrough.wordIndex ?? -1
        asrLogger.info("live_asr_locator event=provisional_initial_highlight state=\(state, privacy: .public) window_id=\(windowID, privacy: .public) matched_word_count=\(matchedWordCount, privacy: .public) confirmation_count=\(confirmationCount, privacy: .public) completed_surah=\(completedSurah, privacy: .public) completed_ayah=\(completedAyah, privacy: .public) completed_word=\(completedWord, privacy: .public)")
    }

    @discardableResult
    func applyASRTranscript(
        _ transcript: QuranSTTTranscript,
        windowID: Int,
        sampleRange: Range<Int>? = nil
    ) -> Bool {
        let recognizedWords = QuranTextNormalizer
            .asrComparable(transcript.text)
            .split(separator: " ")
            .map(String.init)

        guard isRecording else {
            let metrics = liveASRLocatorOutcomeProbe.metrics(
                windowID: windowID,
                recognizedWordCount: recognizedWords.count,
                expectedReferenceCount: 0,
                completedWordCountBefore: snapshot.completedWordCount,
                failureReason: .notRecording
            )
            logLiveASRLocatorOutcome(metrics)
            return false
        }

        debugTranscript = transcript.text
        guard !recognizedWords.isEmpty else {
            let metrics = liveASRLocatorOutcomeProbe.metrics(
                windowID: windowID,
                recognizedWordCount: 0,
                expectedReferenceCount: 0,
                completedWordCountBefore: snapshot.completedWordCount,
                failureReason: .emptyTranscript
            )
            logLiveASRLocatorOutcome(metrics)
            clearAndResetProvisionalInitialHighlightState()
            _ = markFindingPlaceIfNeeded()
            return false
        }

        guard let sampleRange,
              let wordEvidence = try? transcript.wordEvidence(in: sampleRange) else {
            let metrics = liveASRLocatorOutcomeProbe.metrics(
                windowID: windowID,
                recognizedWordCount: recognizedWords.count,
                expectedReferenceCount: 0,
                completedWordCountBefore: snapshot.completedWordCount,
                failureReason: .invalidWordTiming
            )
            logLiveASRLocatorOutcome(metrics)
            clearAndResetProvisionalInitialHighlightState()
            _ = markFindingPlaceIfNeeded()
            return false
        }

        guard let referenceIndex = referenceIndexForSelectedSurah() else {
            let metrics = liveASRLocatorOutcomeProbe.metrics(
                windowID: windowID,
                recognizedWordCount: recognizedWords.count,
                expectedReferenceCount: 0,
                completedWordCountBefore: snapshot.completedWordCount,
                failureReason: .referenceUnavailable
            )
            logLiveASRLocatorOutcome(metrics)
            clearAndResetProvisionalInitialHighlightState()
            return false
        }
        let expectedReferences = referenceIndex.expected
        let completedWordCountBefore = snapshot.completedWordCount
        guard !expectedReferences.isEmpty else {
            let metrics = liveASRLocatorOutcomeProbe.metrics(
                windowID: windowID,
                recognizedWordCount: recognizedWords.count,
                expectedReferenceCount: 0,
                completedWordCountBefore: completedWordCountBefore,
                outcome: .emptyReference
            )
            logLiveASRLocatorOutcome(metrics)
            clearAndResetProvisionalInitialHighlightState()
            _ = markFindingPlaceIfNeeded()
            return false
        }

        var outcome = transcriptLocator.locateWithOutcome(index: referenceIndex, evidence: wordEvidence)
        if case .located(let location) = outcome,
           expectedReferences.indices.contains(location.expectedRange.upperBound) {
            let nextReference = expectedReferences[location.expectedRange.upperBound]
            if nextReference.surah != location.completedThrough.surah
                || nextReference.ayah != location.completedThrough.ayah {
                let successorOutcome = transcriptLocator.locateWithOutcome(
                    index: referenceIndex,
                    evidence: wordEvidence
                )
                if case .located = successorOutcome {
                    outcome = successorOutcome
                }
            }
        }
        let metrics = liveASRLocatorOutcomeProbe.metrics(
            windowID: windowID,
            recognizedWordCount: recognizedWords.count,
            expectedReferenceCount: expectedReferences.count,
            completedWordCountBefore: completedWordCountBefore,
            outcome: outcome
        )
        logLiveASRLocatorOutcome(metrics)

        guard case .located(let location) = outcome else {
            handleProvisionalInitialHighlight(
                windowID: windowID,
                completedWordCountBefore: completedWordCountBefore,
                referenceIndex: referenceIndex,
                references: expectedReferences,
                recognizedWords: recognizedWords
            )
            _ = markFindingPlaceIfNeeded()
            return false
        }

        applyAuthoritativeLocatedProgress(location, references: expectedReferences)
        return true
    }

    private func handleProvisionalInitialHighlight(
        windowID: Int,
        completedWordCountBefore: Int,
        referenceIndex: TranscriptPositionIndex,
        references: [RecitationWordReference],
        recognizedWords: [String]
    ) {
        guard completedWordCountBefore == 0 else {
            clearAndResetProvisionalInitialHighlightState()
            return
        }

        switch provisionalInitialHighlightTracker.evaluate(index: referenceIndex, recognizedWords: recognizedWords) {
        case .candidate(let location, let consecutiveCount):
            logProvisionalInitialHighlight(
                state: "candidate",
                windowID: windowID,
                location: location,
                confirmationCount: consecutiveCount
            )
        case .confirmed(let location, let consecutiveCount):
            logProvisionalInitialHighlight(
                state: "confirmed",
                windowID: windowID,
                location: location,
                confirmationCount: consecutiveCount
            )
            applyProvisionalInitialHighlight(through: location, references: references)
        case .cleared:
            logProvisionalInitialHighlight(
                state: "cleared",
                windowID: windowID,
                location: nil,
                confirmationCount: -1
            )
            clearProvisionalInitialHighlight()
        case .none:
            clearProvisionalInitialHighlight()
        }
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
        lastCompletedReference = completedWord

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

    func applyAuthoritativeLocatedProgress(
        _ location: TranscriptLocation,
        references: [RecitationWordReference]
    ) {
        clearProvisionalInitialHighlight()
        resetProvisionalInitialHighlightTracking()
        snapshot = reducer.reduce(.progressAdvanced(
            ayah: location.completedThrough.ayah,
            completedWordCount: location.completedThrough.wordIndex
        ))
        applyLocatedProgress(through: location.completedThrough, references: references)
        resetProvisionalInitialHighlightTracking()
    }

    func applyProvisionalInitialHighlight(
        through location: TranscriptLocation,
        references: [RecitationWordReference]
    ) {
        guard snapshot.completedWordCount == 0 else { return }
        guard !location.expectedRange.isEmpty,
              location.expectedRange.lowerBound >= 0,
              location.expectedRange.upperBound <= references.count else {
            return
        }

        clearProvisionalInitialHighlight()
        resetSelectedAyahPageStatesToPending()

        let provisionalReferences = references[location.expectedRange]
        var visualLocations: Set<String> = []
        for reference in provisionalReferences {
            wordStatesByLocation[reference.location] = .provisional
            visualLocations.insert(reference.location)
        }

        if references.indices.contains(location.expectedRange.upperBound) {
            let nextReference = references[location.expectedRange.upperBound]
            wordStatesByLocation[nextReference.location] = .current
            visualLocations.insert(nextReference.location)
        }

        syncSelectedAyahProvisionalProgress(through: location, references: references)
        provisionalHighlightLocation = location
        provisionalVisualLocations = visualLocations
    }

    func clearProvisionalInitialHighlight() {
        guard provisionalHighlightLocation != nil || !provisionalVisualLocations.isEmpty else { return }
        guard snapshot.completedWordCount == 0 else {
            self.provisionalHighlightLocation = nil
            provisionalVisualLocations.removeAll()
            return
        }

        let visualLocations = provisionalVisualLocations
        for location in visualLocations {
            wordStatesByLocation[location] = .pending
        }
        resetDisplayedWordStates()
        for location in visualLocations {
            wordStatesByLocation[location] = .pending
        }
        wordStatesByLocation[wordLocation(surah: selectedSurah, ayah: startAyah, wordIndex: 1)] = .current
        wordProgress = wordProgress.map { word in
            WordProgress(
                wordIndex: word.wordIndex,
                text: word.text,
                state: word.wordIndex == 1 ? .current : .pending
            )
        }
        self.provisionalHighlightLocation = nil
        provisionalVisualLocations.removeAll()
        focusedReference = nil
    }

    private func resetSelectedAyahPageStatesToPending() {
        for word in wordProgress {
            wordStatesByLocation[wordLocation(surah: selectedSurah, ayah: startAyah, wordIndex: word.wordIndex)] = .pending
        }
    }

    private func resetProvisionalInitialHighlightTracking() {
        provisionalInitialHighlightTracker.reset()
        provisionalHighlightLocation = nil
        if snapshot.completedWordCount > 0 {
            provisionalVisualLocations.removeAll()
        }
    }

    private func clearAndResetProvisionalInitialHighlightState() {
        clearProvisionalInitialHighlight()
        resetProvisionalInitialHighlightTracking()
    }

    private func handleASRError(_ error: Error) {
        guard isRecording else { return }
        clearAndResetProvisionalInitialHighlightState()
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
        let finalSurah = SurahCatalog.surah(selectedSurah + 1) == nil ? selectedSurah : selectedSurah + 1
        let finalAyah = SurahCatalog.surah(finalSurah)?.ayahCount ?? selectedSurahInfo.ayahCount
        if let referenceScopeCache,
           referenceScopeCache.surah == selectedSurah,
           referenceScopeCache.startAyah == startAyah,
           referenceScopeCache.finalSurah == finalSurah,
           referenceScopeCache.finalAyah == finalAyah {
            return referenceScopeCache.index
        }

        let references = referenceWordsForLiveRecitation(finalSurah: finalSurah, finalAyah: finalAyah)
        let index = TranscriptPositionIndex(expected: references)
        referenceScopeCache = ReferenceScopeCache(
            surah: selectedSurah,
            startAyah: startAyah,
            finalSurah: finalSurah,
            finalAyah: finalAyah,
            index: index
        )
        return index
    }

    private func referenceWordsForLiveRecitation(finalSurah: Int, finalAyah: Int) -> [RecitationWordReference] {
        guard let repository else { return [] }

        var references: [RecitationWordReference] = []
        for surah in selectedSurah...finalSurah {
            guard let surahInfo = SurahCatalog.surah(surah) else { continue }
            let firstAyah = surah == selectedSurah ? startAyah : 1
            let lastAyah = surah == finalSurah ? finalAyah : surahInfo.ayahCount
            guard firstAyah <= lastAyah else { continue }

            for ayah in firstAyah...lastAyah {
                let text = (try? repository.referenceText(surah: surah, ayah: ayah)) ?? ""
                let referenceWords = QuranReferenceWords.wordsForAyah(text, surah: surah, ayah: ayah)
                guard !referenceWords.isEmpty else { continue }

                let glyphWords = (try? repository.words(surah: surah, ayah: ayah)) ?? []
                for (offset, word) in referenceWords.enumerated() {
                    let wordIndex = glyphWords.indices.contains(offset) ? glyphWords[offset].wordIndex : offset + 1
                    references.append(RecitationWordReference(
                        surah: surah,
                        ayah: ayah,
                        wordIndex: wordIndex,
                        text: word
                    ))
                }
            }
        }
        return references
    }

    private func invalidateReferenceScope() {
        clearAndResetProvisionalInitialHighlightState()
        referenceScopeCache = nil
        transcriptLocator.reset()
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
            if completedWord.surah > selectedSurah
                || completedWord.ayah > startAyah
                || word.wordIndex <= completedWord.wordIndex {
                state = .completed
            } else if completedWord.ayah == startAyah, word.wordIndex == completedWord.wordIndex + 1 {
                state = .current
            } else {
                state = .pending
            }
            return WordProgress(wordIndex: word.wordIndex, text: word.text, state: state)
        }
    }

    private func syncSelectedAyahProvisionalProgress(
        through location: TranscriptLocation,
        references: [RecitationWordReference]
    ) {
        let provisionalLocations = Set(references[location.expectedRange].map(\.location))
        let currentLocation = references.indices.contains(location.expectedRange.upperBound)
            ? references[location.expectedRange.upperBound].location
            : nil

        wordProgress = wordProgress.map { word in
            let location = wordLocation(surah: selectedSurah, ayah: startAyah, wordIndex: word.wordIndex)
            let state: WordProgressState
            if provisionalLocations.contains(location) {
                state = .provisional
            } else if location == currentLocation {
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
        displayMushafPage(targetPageNumber)
    }

    private func displayMushafPage(_ pageNumber: Int) {
        guard pageNumber != displayedPageNumber else { return }
        guard Self.mushafPageRange.contains(pageNumber), let repository else { return }

        do {
            let page = try repository.mushafPage(pageNumber: pageNumber)
            displayedPageNumber = pageNumber
            mushafPage = page
        } catch {
            asrLogger.error("page_flip_failed page=\(pageNumber, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
        }
    }

    private func wordLocation(surah: Int, ayah: Int, wordIndex: Int) -> String {
        "\(surah):\(ayah):\(wordIndex)"
    }

    private func isRecitationTextVisible(state: WordProgressState, surah: Int, ayah: Int) -> Bool {
        guard hideRecitationText else { return true }
        guard isInHiddenRecitationScope(surah: surah, ayah: ayah) else { return true }

        switch state {
        case .completed, .provisional, .uncertain, .correctionNeeded:
            return true
        case .pending, .current:
            return false
        }
    }

    private func inheritedAyahMarkerState(for word: QuranWord) -> WordProgressState? {
        guard let realWordCount = referenceWordCount(surah: word.surah, ayah: word.ayah),
              realWordCount > 0,
              word.wordIndex > realWordCount else {
            return nil
        }

        let finalRealWordState = wordStatesByLocation[
            wordLocation(surah: word.surah, ayah: word.ayah, wordIndex: realWordCount)
        ] ?? .pending

        switch finalRealWordState {
        case .completed, .provisional, .uncertain, .correctionNeeded:
            return finalRealWordState
        case .pending, .current:
            return nil
        }
    }

    private func referenceWordCount(surah: Int, ayah: Int) -> Int? {
        let key = "\(surah):\(ayah)"
        if let cached = referenceWordCountByAyah[key] {
            return cached
        }

        guard let text = try? repository?.referenceText(surah: surah, ayah: ayah) else {
            return nil
        }

        let count = QuranReferenceWords.wordsForAyah(text, surah: surah, ayah: ayah).count
        referenceWordCountByAyah[key] = count
        return count
    }

    private func isInHiddenRecitationScope(surah: Int, ayah: Int) -> Bool {
        if surah < selectedSurah { return false }
        if surah == selectedSurah { return ayah >= startAyah }
        return true
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
    var finalSurah: Int
    var finalAyah: Int
    var index: TranscriptPositionIndex
}
