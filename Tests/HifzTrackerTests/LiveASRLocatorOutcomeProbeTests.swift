import XCTest
import HifzCore
@testable import HifzTracker

final class LiveASRLocatorOutcomeProbeTests: XCTestCase {
    func testBuildsMetricsForLocatedProgress() {
        let probe = LiveASRLocatorOutcomeProbe()
        let location = TranscriptLocation(
            completedThrough: RecitationWordReference(surah: 73, ayah: 4, wordIndex: 3, text: "ورتل"),
            matchedWordCount: 5,
            expectedRange: 10..<15,
            recognizedRange: 1..<6
        )

        let metrics = probe.metrics(
            windowID: 12,
            recognizedWordCount: 8,
            expectedReferenceCount: 286,
            completedWordCountBefore: 2,
            outcome: .located(location)
        )

        XCTAssertEqual(metrics, .init(
            windowID: 12,
            reason: "progress_applied",
            recognizedWordCount: 8,
            expectedReferenceCount: 286,
            completedWordCountBefore: 2,
            matchedWordCount: 5,
            completedSurah: 73,
            completedAyah: 4,
            completedWord: 3
        ))
    }

    func testBuildsMetricsForRejectedLocatorOutcomes() {
        let probe = LiveASRLocatorOutcomeProbe()

        let cases: [(Int, Int, Int, ProgressiveTranscriptLocatorOutcome, LiveASRLocatorOutcomeProbe.Metrics)] = [
            (3, 2, 0, .initialMatchTooShort(matchedWordCount: 2, requiredWordCount: 4), .init(
                windowID: 3,
                reason: "initial_match_too_short",
                recognizedWordCount: 2,
                expectedReferenceCount: 120,
                completedWordCountBefore: 0,
                matchedWordCount: 2,
                requiredWordCount: 4
            )),
            (4, 5, 4, .notAdvancing(completedOffset: 3, acceptedOffset: 3), .init(
                windowID: 4,
                reason: "not_advancing",
                recognizedWordCount: 5,
                expectedReferenceCount: 120,
                completedWordCountBefore: 4,
                completedOffset: 3,
                acceptedOffset: 3
            )),
            (5, 8, 0, .initialMatchTooFar(matchedWordCount: 8, startOffset: 48, allowedStartOffset: 31), .init(
                windowID: 5,
                reason: "initial_match_too_far",
                recognizedWordCount: 8,
                expectedReferenceCount: 120,
                completedWordCountBefore: 0,
                matchedWordCount: 8,
                completedOffset: 48,
                acceptedOffset: 31
            ))
        ]

        for (windowID, recognizedWordCount, completedWordCountBefore, outcome, expected) in cases {
            XCTAssertEqual(probe.metrics(
                windowID: windowID,
                recognizedWordCount: recognizedWordCount,
                expectedReferenceCount: 120,
                completedWordCountBefore: completedWordCountBefore,
                outcome: outcome
            ), expected)
        }
    }

    func testBuildsMetricsForViewModelFailureReasons() {
        let probe = LiveASRLocatorOutcomeProbe()

        let metrics = probe.metrics(
            windowID: 1,
            recognizedWordCount: 0,
            expectedReferenceCount: 0,
            completedWordCountBefore: 0,
            failureReason: .emptyTranscript
        )

        XCTAssertEqual(metrics, .init(
            windowID: 1,
            reason: "empty_transcript",
            recognizedWordCount: 0,
            expectedReferenceCount: 0,
            completedWordCountBefore: 0
        ))
    }
}
