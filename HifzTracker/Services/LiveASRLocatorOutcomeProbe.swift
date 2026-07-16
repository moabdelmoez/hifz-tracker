import HifzCore

struct LiveASRLocatorOutcomeProbe {
    enum FailureReason: String, Equatable {
        case notRecording = "not_recording"
        case emptyTranscript = "empty_transcript"
        case referenceUnavailable = "reference_unavailable"
        case invalidWordTiming = "invalid_word_timing"
    }

    struct Metrics: Equatable {
        var windowID: Int
        var reason: String
        var recognizedWordCount: Int
        var expectedReferenceCount: Int
        var completedWordCountBefore: Int
        var matchedWordCount: Int? = nil
        var requiredWordCount: Int? = nil
        var completedOffset: Int? = nil
        var acceptedOffset: Int? = nil
        var completedSurah: Int? = nil
        var completedAyah: Int? = nil
        var completedWord: Int? = nil
    }

    func metrics(
        windowID: Int,
        recognizedWordCount: Int,
        expectedReferenceCount: Int,
        completedWordCountBefore: Int,
        outcome: ProgressiveTranscriptLocatorOutcome
    ) -> Metrics {
        switch outcome {
        case .located(let location):
            return Metrics(
                windowID: windowID,
                reason: outcome.reason,
                recognizedWordCount: recognizedWordCount,
                expectedReferenceCount: expectedReferenceCount,
                completedWordCountBefore: completedWordCountBefore,
                matchedWordCount: location.matchedWordCount,
                completedSurah: location.completedThrough.surah,
                completedAyah: location.completedThrough.ayah,
                completedWord: location.completedThrough.wordIndex
            )
        case .emptyReference, .noMatch, .freshEvidenceRequired:
            return metrics(
                windowID: windowID,
                reason: outcome.reason,
                recognizedWordCount: recognizedWordCount,
                expectedReferenceCount: expectedReferenceCount,
                completedWordCountBefore: completedWordCountBefore
            )
        case .initialMatchTooShort(let matchedWordCount, let requiredWordCount):
            return Metrics(
                windowID: windowID,
                reason: outcome.reason,
                recognizedWordCount: recognizedWordCount,
                expectedReferenceCount: expectedReferenceCount,
                completedWordCountBefore: completedWordCountBefore,
                matchedWordCount: matchedWordCount,
                requiredWordCount: requiredWordCount
            )
        case .initialMatchTooFar(let matchedWordCount, let startOffset, let allowedStartOffset):
            return Metrics(
                windowID: windowID,
                reason: outcome.reason,
                recognizedWordCount: recognizedWordCount,
                expectedReferenceCount: expectedReferenceCount,
                completedWordCountBefore: completedWordCountBefore,
                matchedWordCount: matchedWordCount,
                completedOffset: startOffset,
                acceptedOffset: allowedStartOffset
            )
        case .notAdvancing(let completedOffset, let acceptedOffset):
            return Metrics(
                windowID: windowID,
                reason: outcome.reason,
                recognizedWordCount: recognizedWordCount,
                expectedReferenceCount: expectedReferenceCount,
                completedWordCountBefore: completedWordCountBefore,
                completedOffset: completedOffset,
                acceptedOffset: acceptedOffset
            )
        }
    }

    func metrics(
        windowID: Int,
        recognizedWordCount: Int,
        expectedReferenceCount: Int,
        completedWordCountBefore: Int,
        failureReason: FailureReason
    ) -> Metrics {
        metrics(
            windowID: windowID,
            reason: failureReason.rawValue,
            recognizedWordCount: recognizedWordCount,
            expectedReferenceCount: expectedReferenceCount,
            completedWordCountBefore: completedWordCountBefore
        )
    }

    private func metrics(
        windowID: Int,
        reason: String,
        recognizedWordCount: Int,
        expectedReferenceCount: Int,
        completedWordCountBefore: Int
    ) -> Metrics {
        Metrics(
            windowID: windowID,
            reason: reason,
            recognizedWordCount: recognizedWordCount,
            expectedReferenceCount: expectedReferenceCount,
            completedWordCountBefore: completedWordCountBefore
        )
    }
}
