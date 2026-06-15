import XCTest
@testable import HifzCore

final class LiveASRSampleWindowTests: XCTestCase {
    func testEmitsOnlyAfterMinimumWindowAndThenAtInferenceInterval() {
        var window = LiveASRSampleWindow(
            sampleRate: 16_000,
            minimumDuration: 1.0,
            maximumDuration: 4.0,
            inferenceInterval: 0.5
        )

        XCTAssertNil(window.append(Array(repeating: Float(0.1), count: 8_000)))

        let firstEmission = window.append(Array(repeating: Float(0.2), count: 8_000))
        XCTAssertEqual(firstEmission?.count, 16_000)

        XCTAssertNil(window.append(Array(repeating: Float(0.3), count: 4_000)))

        let secondEmission = window.append(Array(repeating: Float(0.4), count: 4_000))
        XCTAssertEqual(secondEmission?.count, 24_000)
    }

    func testTrimsBufferedAudioToMaximumWindow() {
        var window = LiveASRSampleWindow(
            sampleRate: 4,
            minimumDuration: 1.0,
            maximumDuration: 2.0,
            inferenceInterval: 1.0
        )

        _ = window.append([1, 1, 1, 1])
        _ = window.append([2, 2, 2, 2])

        let emission = window.append([3, 3, 3, 3])

        XCTAssertEqual(emission, [2, 2, 2, 2, 3, 3, 3, 3])
        XCTAssertEqual(window.bufferedSampleCount, 8)
    }

    func testResetClearsBufferAndEmissionThrottle() {
        var window = LiveASRSampleWindow(
            sampleRate: 4,
            minimumDuration: 1.0,
            maximumDuration: 2.0,
            inferenceInterval: 1.0
        )

        XCTAssertNotNil(window.append([1, 1, 1, 1]))
        window.reset()

        XCTAssertEqual(window.bufferedSampleCount, 0)
        XCTAssertNil(window.append([2, 2]))
        XCTAssertEqual(window.append([2, 2]), [2, 2, 2, 2])
    }
}
