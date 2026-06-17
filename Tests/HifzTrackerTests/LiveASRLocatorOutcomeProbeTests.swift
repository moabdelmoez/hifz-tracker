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

        XCTAssertEqual(metrics.windowID, 12)
        XCTAssertEqual(metrics.reason, "progress_applied")
        XCTAssertEqual(metrics.recognizedWordCount, 8)
        XCTAssertEqual(metrics.expectedReferenceCount, 286)
        XCTAssertEqual(metrics.completedWordCountBefore, 2)
        XCTAssertEqual(metrics.matchedWordCount, 5)
        XCTAssertEqual(metrics.completedSurah, 73)
        XCTAssertEqual(metrics.completedAyah, 4)
        XCTAssertEqual(metrics.completedWord, 3)
        XCTAssertNil(metrics.requiredWordCount)
        XCTAssertNil(metrics.completedOffset)
        XCTAssertNil(metrics.acceptedOffset)
    }

    func testBuildsMetricsForRejectedLocatorOutcomes() {
        let probe = LiveASRLocatorOutcomeProbe()

        let short = probe.metrics(
            windowID: 3,
            recognizedWordCount: 2,
            expectedReferenceCount: 120,
            completedWordCountBefore: 0,
            outcome: .initialMatchTooShort(matchedWordCount: 2, requiredWordCount: 4)
        )
        let repeated = probe.metrics(
            windowID: 4,
            recognizedWordCount: 5,
            expectedReferenceCount: 120,
            completedWordCountBefore: 4,
            outcome: .notAdvancing(completedOffset: 3, acceptedOffset: 3)
        )
        let far = probe.metrics(
            windowID: 5,
            recognizedWordCount: 8,
            expectedReferenceCount: 120,
            completedWordCountBefore: 0,
            outcome: .initialMatchTooFar(matchedWordCount: 8, startOffset: 48, allowedStartOffset: 31)
        )

        XCTAssertEqual(short.reason, "initial_match_too_short")
        XCTAssertEqual(short.matchedWordCount, 2)
        XCTAssertEqual(short.requiredWordCount, 4)
        XCTAssertEqual(repeated.reason, "not_advancing")
        XCTAssertEqual(repeated.completedOffset, 3)
        XCTAssertEqual(repeated.acceptedOffset, 3)
        XCTAssertEqual(far.reason, "initial_match_too_far")
        XCTAssertEqual(far.matchedWordCount, 8)
        XCTAssertEqual(far.completedOffset, 48)
        XCTAssertEqual(far.acceptedOffset, 31)
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

        XCTAssertEqual(metrics.reason, "empty_transcript")
        XCTAssertNil(metrics.matchedWordCount)
        XCTAssertNil(metrics.completedSurah)
        XCTAssertNil(metrics.completedAyah)
        XCTAssertNil(metrics.completedWord)
    }
}
