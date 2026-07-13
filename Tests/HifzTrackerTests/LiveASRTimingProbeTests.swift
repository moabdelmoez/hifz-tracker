import XCTest
@testable import HifzTracker

final class LiveASRTimingProbeTests: XCTestCase {
    func testReportsFirstTranscriptLatencyProcessingAndAverageIntervals() {
        var probe = LiveASRTimingProbe()
        probe.recordingStarted(atNanoseconds: 1_000_000_000)

        let firstToken = probe.transcriptionStarted(
            sampleCount: 16_000,
            sampleRate: 16_000,
            atNanoseconds: 2_000_000_000
        )
        let firstMetrics = probe.transcriptionFinished(
            firstToken,
            atNanoseconds: 2_250_000_000
        )

        XCTAssertEqual(firstMetrics.windowID, 1)
        XCTAssertEqual(firstMetrics.audioMilliseconds, 1_000, accuracy: 0.001)
        XCTAssertEqual(firstMetrics.processingMilliseconds, 250, accuracy: 0.001)
        XCTAssertEqual(firstMetrics.firstTranscriptLatencyMilliseconds ?? -1, 1_250, accuracy: 0.001)
        XCTAssertNil(firstMetrics.transcriptIntervalMilliseconds)
        XCTAssertNil(firstMetrics.averageTranscriptIntervalMilliseconds)

        let secondToken = probe.transcriptionStarted(
            sampleCount: 24_000,
            sampleRate: 16_000,
            atNanoseconds: 2_500_000_000
        )
        let secondMetrics = probe.transcriptionFinished(
            secondToken,
            atNanoseconds: 2_700_000_000
        )

        XCTAssertEqual(secondMetrics.windowID, 2)
        XCTAssertEqual(secondMetrics.audioMilliseconds, 1_500, accuracy: 0.001)
        XCTAssertEqual(secondMetrics.processingMilliseconds, 200, accuracy: 0.001)
        XCTAssertNil(secondMetrics.firstTranscriptLatencyMilliseconds)
        XCTAssertEqual(secondMetrics.transcriptIntervalMilliseconds ?? -1, 450, accuracy: 0.001)
        XCTAssertEqual(secondMetrics.averageTranscriptIntervalMilliseconds ?? -1, 450, accuracy: 0.001)
    }

    func testCountsPendingWindowStoresAndHandoffs() {
        var probe = LiveASRTimingProbe()
        probe.recordingStarted(atNanoseconds: 10_000_000_000)

        let first = probe.pendingWindow(
            .stored,
            sampleCount: 32_000,
            sampleRate: 16_000,
            atNanoseconds: 10_750_000_000
        )
        let second = probe.pendingWindow(
            .stored,
            sampleCount: 40_000,
            sampleRate: 16_000,
            atNanoseconds: 11_250_000_000
        )
        let handoff = probe.pendingWindow(
            .handoffStarted,
            sampleCount: 40_000,
            sampleRate: 16_000,
            atNanoseconds: 11_500_000_000
        )

        XCTAssertEqual(first.event, .stored)
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(first.audioMilliseconds, 2_000, accuracy: 0.001)
        XCTAssertEqual(first.elapsedSinceRecordingStartMilliseconds ?? -1, 750, accuracy: 0.001)
        XCTAssertEqual(second.event, .stored)
        XCTAssertEqual(second.count, 2)
        XCTAssertEqual(second.audioMilliseconds, 2_500, accuracy: 0.001)
        XCTAssertEqual(second.elapsedSinceRecordingStartMilliseconds ?? -1, 1_250, accuracy: 0.001)
        XCTAssertEqual(handoff.event, .handoffStarted)
        XCTAssertEqual(handoff.count, 1)
        XCTAssertEqual(handoff.audioMilliseconds, 2_500, accuracy: 0.001)
        XCTAssertEqual(handoff.elapsedSinceRecordingStartMilliseconds ?? -1, 1_500, accuracy: 0.001)
    }

    func testResetClearsMeasurements() {
        var probe = LiveASRTimingProbe()
        probe.recordingStarted(atNanoseconds: 1_000_000_000)
        _ = probe.pendingWindow(
            .stored,
            sampleCount: 16_000,
            sampleRate: 16_000,
            atNanoseconds: 1_500_000_000
        )
        let token = probe.transcriptionStarted(
            sampleCount: 16_000,
            sampleRate: 16_000,
            atNanoseconds: 2_000_000_000
        )
        _ = probe.transcriptionFinished(token, atNanoseconds: 2_500_000_000)

        probe.reset()
        probe.recordingStarted(atNanoseconds: 5_000_000_000)
        let nextToken = probe.transcriptionStarted(
            sampleCount: 8_000,
            sampleRate: 16_000,
            atNanoseconds: 5_250_000_000
        )
        let nextMetrics = probe.transcriptionFinished(
            nextToken,
            atNanoseconds: 5_500_000_000
        )

        XCTAssertEqual(nextMetrics.windowID, 1)
        XCTAssertEqual(nextMetrics.firstTranscriptLatencyMilliseconds ?? -1, 500, accuracy: 0.001)
        XCTAssertNil(nextMetrics.transcriptIntervalMilliseconds)
        XCTAssertNil(nextMetrics.averageTranscriptIntervalMilliseconds)
    }
}
