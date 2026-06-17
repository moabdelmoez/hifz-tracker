import HifzCore

struct LiveASRLocatorOutcomeProbe {
    enum FailureReason: String, Equatable {
        case notRecording = "not_recording"
        case emptyTranscript = "empty_transcript"
        case referenceUnavailable = "reference_unavailable"
    }

    struct Metrics: Equatable {
        var windowID: Int
        var reason: String
        var recognizedWordCount: Int
        var expectedReferenceCount: Int
        var completedWordCountBefore: Int
        var matchedWordCount: Int?
        var requiredWordCount: Int?
        var completedOffset: Int?
        var acceptedOffset: Int?
        var completedSurah: Int?
        var completedAyah: Int?
        var completedWord: Int?
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
                requiredWordCount: nil,
                completedOffset: nil,
                acceptedOffset: nil,
                completedSurah: location.completedThrough.surah,
                completedAyah: location.completedThrough.ayah,
                completedWord: location.completedThrough.wordIndex
            )
        case .emptyReference, .noMatch:
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
                requiredWordCount: requiredWordCount,
                completedOffset: nil,
                acceptedOffset: nil,
                completedSurah: nil,
                completedAyah: nil,
                completedWord: nil
            )
        case .notAdvancing(let completedOffset, let acceptedOffset):
            return Metrics(
                windowID: windowID,
                reason: outcome.reason,
                recognizedWordCount: recognizedWordCount,
                expectedReferenceCount: expectedReferenceCount,
                completedWordCountBefore: completedWordCountBefore,
                matchedWordCount: nil,
                requiredWordCount: nil,
                completedOffset: completedOffset,
                acceptedOffset: acceptedOffset,
                completedSurah: nil,
                completedAyah: nil,
                completedWord: nil
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
            completedWordCountBefore: completedWordCountBefore,
            matchedWordCount: nil,
            requiredWordCount: nil,
            completedOffset: nil,
            acceptedOffset: nil,
            completedSurah: nil,
            completedAyah: nil,
            completedWord: nil
        )
    }
}
