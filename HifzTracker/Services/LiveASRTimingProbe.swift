struct LiveASRTimingProbe {
    struct EventMetrics: Equatable {
        var elapsedSinceStartRequestMilliseconds: Double?
        var elapsedSinceRecordingStartMilliseconds: Double?
        var elapsedSinceVoiceOnsetMilliseconds: Double?
    }

    struct TranscriptionToken: Equatable {
        var windowID: Int
        var sampleCount: Int
        var audioMilliseconds: Double
        var startedAtNanoseconds: UInt64
    }

    struct TranscriptionFinishedMetrics: Equatable {
        var windowID: Int
        var sampleCount: Int
        var audioMilliseconds: Double
        var processingMilliseconds: Double
        var firstTranscriptLatencyMilliseconds: Double?
        var firstTranscriptEventMetrics: EventMetrics?
        var transcriptIntervalMilliseconds: Double?
        var averageTranscriptIntervalMilliseconds: Double?
    }

    enum PendingWindowEvent: Equatable {
        case stored
        case handoffStarted
    }

    struct PendingWindowMetrics: Equatable {
        var event: PendingWindowEvent
        var count: Int
        var sampleCount: Int
        var audioMilliseconds: Double
        var elapsedSinceRecordingStartMilliseconds: Double?
    }

    private var startRequestedAtNanoseconds: UInt64?
    private var recordingStartedAtNanoseconds: UInt64?
    private var voiceOnsetAtNanoseconds: UInt64?
    private var nextWindowID = 1
    private var hasReportedFirstTranscript = false
    private var hasReportedFirstHighlight = false
    private var lastTranscriptFinishedAtNanoseconds: UInt64?
    private var transcriptIntervalTotalMilliseconds = 0.0
    private var transcriptIntervalCount = 0
    private var pendingWindowStoreCount = 0
    private var pendingHandoffCount = 0

    mutating func startRequested(atNanoseconds timestamp: UInt64) {
        reset()
        startRequestedAtNanoseconds = timestamp
    }

    func eventMetrics(atNanoseconds timestamp: UInt64) -> EventMetrics {
        EventMetrics(
            elapsedSinceStartRequestMilliseconds: startRequestedAtNanoseconds.map {
                milliseconds(from: $0, to: timestamp)
            },
            elapsedSinceRecordingStartMilliseconds: recordingStartedAtNanoseconds.map {
                milliseconds(from: $0, to: timestamp)
            },
            elapsedSinceVoiceOnsetMilliseconds: voiceOnsetAtNanoseconds.map {
                milliseconds(from: $0, to: timestamp)
            }
        )
    }

    @discardableResult
    mutating func recordingStarted(atNanoseconds timestamp: UInt64) -> EventMetrics {
        resetRecordingMetrics()
        recordingStartedAtNanoseconds = timestamp
        return eventMetrics(atNanoseconds: timestamp)
    }

    mutating func voiceOnset(atNanoseconds timestamp: UInt64) -> EventMetrics? {
        guard recordingStartedAtNanoseconds != nil, voiceOnsetAtNanoseconds == nil else { return nil }
        voiceOnsetAtNanoseconds = timestamp
        return eventMetrics(atNanoseconds: timestamp)
    }

    mutating func highlightApplied(atNanoseconds timestamp: UInt64) -> EventMetrics? {
        guard !hasReportedFirstHighlight else { return nil }
        hasReportedFirstHighlight = true
        return eventMetrics(atNanoseconds: timestamp)
    }

    mutating func transcriptionStarted(
        sampleCount: Int,
        sampleRate: Int,
        atNanoseconds timestamp: UInt64
    ) -> TranscriptionToken {
        let token = TranscriptionToken(
            windowID: nextWindowID,
            sampleCount: sampleCount,
            audioMilliseconds: audioMilliseconds(sampleCount: sampleCount, sampleRate: sampleRate),
            startedAtNanoseconds: timestamp
        )
        nextWindowID += 1
        return token
    }

    mutating func transcriptionFinished(
        _ token: TranscriptionToken,
        atNanoseconds timestamp: UInt64
    ) -> TranscriptionFinishedMetrics {
        let processingMilliseconds = milliseconds(from: token.startedAtNanoseconds, to: timestamp)
        let firstTranscriptLatencyMilliseconds: Double?
        let firstTranscriptEventMetrics: EventMetrics?
        if !hasReportedFirstTranscript, let recordingStartedAtNanoseconds {
            firstTranscriptLatencyMilliseconds = milliseconds(from: recordingStartedAtNanoseconds, to: timestamp)
            firstTranscriptEventMetrics = eventMetrics(atNanoseconds: timestamp)
            hasReportedFirstTranscript = true
        } else {
            firstTranscriptLatencyMilliseconds = nil
            firstTranscriptEventMetrics = nil
        }

        let transcriptIntervalMilliseconds: Double?
        let averageTranscriptIntervalMilliseconds: Double?
        if let lastTranscriptFinishedAtNanoseconds {
            let interval = milliseconds(from: lastTranscriptFinishedAtNanoseconds, to: timestamp)
            transcriptIntervalTotalMilliseconds += interval
            transcriptIntervalCount += 1
            transcriptIntervalMilliseconds = interval
            averageTranscriptIntervalMilliseconds = transcriptIntervalTotalMilliseconds / Double(transcriptIntervalCount)
        } else {
            transcriptIntervalMilliseconds = nil
            averageTranscriptIntervalMilliseconds = nil
        }

        lastTranscriptFinishedAtNanoseconds = timestamp
        return TranscriptionFinishedMetrics(
            windowID: token.windowID,
            sampleCount: token.sampleCount,
            audioMilliseconds: token.audioMilliseconds,
            processingMilliseconds: processingMilliseconds,
            firstTranscriptLatencyMilliseconds: firstTranscriptLatencyMilliseconds,
            firstTranscriptEventMetrics: firstTranscriptEventMetrics,
            transcriptIntervalMilliseconds: transcriptIntervalMilliseconds,
            averageTranscriptIntervalMilliseconds: averageTranscriptIntervalMilliseconds
        )
    }

    mutating func pendingWindow(
        _ event: PendingWindowEvent,
        sampleCount: Int,
        sampleRate: Int,
        atNanoseconds timestamp: UInt64
    ) -> PendingWindowMetrics {
        let count: Int
        switch event {
        case .stored:
            pendingWindowStoreCount += 1
            count = pendingWindowStoreCount
        case .handoffStarted:
            pendingHandoffCount += 1
            count = pendingHandoffCount
        }
        let elapsedSinceRecordingStartMilliseconds = recordingStartedAtNanoseconds.map {
            milliseconds(from: $0, to: timestamp)
        }
        return PendingWindowMetrics(
            event: event,
            count: count,
            sampleCount: sampleCount,
            audioMilliseconds: audioMilliseconds(sampleCount: sampleCount, sampleRate: sampleRate),
            elapsedSinceRecordingStartMilliseconds: elapsedSinceRecordingStartMilliseconds
        )
    }

    mutating func reset() {
        startRequestedAtNanoseconds = nil
        resetRecordingMetrics()
    }

    private mutating func resetRecordingMetrics() {
        recordingStartedAtNanoseconds = nil
        voiceOnsetAtNanoseconds = nil
        nextWindowID = 1
        hasReportedFirstTranscript = false
        hasReportedFirstHighlight = false
        lastTranscriptFinishedAtNanoseconds = nil
        transcriptIntervalTotalMilliseconds = 0
        transcriptIntervalCount = 0
        pendingWindowStoreCount = 0
        pendingHandoffCount = 0
    }

    private func audioMilliseconds(sampleCount: Int, sampleRate: Int) -> Double {
        Double(sampleCount) / Double(max(1, sampleRate)) * 1_000
    }

    private func milliseconds(from start: UInt64, to end: UInt64) -> Double {
        guard end >= start else { return 0 }
        return Double(end - start) / 1_000_000
    }
}
