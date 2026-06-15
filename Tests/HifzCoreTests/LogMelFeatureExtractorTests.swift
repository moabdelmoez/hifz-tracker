import XCTest
@testable import HifzCore

final class LogMelFeatureExtractorTests: XCTestCase {
    func testExtractsNormalizedLogMelFeaturesForDemoFixture() throws {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appending(path: "quran-stt-onnx/demo/01_alafasy_fatihah.wav")
        let audio = try WAVAudioFile(url: url)
        let extractor = LogMelFeatureExtractor()

        let features = extractor.extract(samples: audio.samples)

        XCTAssertEqual(features.featureCount, 80)
        XCTAssertEqual(features.frameCount, 468)
        XCTAssertEqual(features.values.count, 80 * 468)
        XCTAssertTrue(features.values.allSatisfy { $0.isFinite })

        for featureIndex in 0..<features.featureCount {
            let start = featureIndex * features.frameCount
            let row = features.values[start..<start + features.frameCount]
            let mean = row.reduce(Float(0), +) / Float(row.count)
            let variance = row.reduce(Float(0)) { partial, value in
                let delta = value - mean
                return partial + delta * delta
            } / Float(row.count)
            XCTAssertEqual(mean, 0, accuracy: 0.02)
            XCTAssertEqual(sqrt(variance), 1, accuracy: 0.02)
        }
    }

    func testExtractsEightSecondLiveWindowWithinRealtimeBudget() {
        let extractor = LogMelFeatureExtractor()
        let samples = (0..<(8 * extractor.sampleRate)).map { index in
            Float(sin(2.0 * Double.pi * 440.0 * Double(index) / Double(extractor.sampleRate)))
        }

        let startedAt = DispatchTime.now().uptimeNanoseconds
        let features = extractor.extract(samples: samples)
        let elapsedMS = Double(DispatchTime.now().uptimeNanoseconds - startedAt) / 1_000_000.0

        XCTAssertEqual(features.featureCount, 80)
        XCTAssertEqual(features.frameCount, 800)
        XCTAssertLessThan(elapsedMS, 1_000, "8-second live-window feature extraction took \(elapsedMS) ms")
    }
}
