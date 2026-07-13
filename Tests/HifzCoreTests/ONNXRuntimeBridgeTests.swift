import XCTest
@testable import HifzCore

final class ONNXRuntimeBridgeTests: XCTestCase {
    func testReportsPinnedONNXRuntimeVersion() {
        XCTAssertEqual(ONNXRuntime.versionString(), "1.26.0")
    }

    func testRunsFp32QuranSTTModelForFeatureWindow() throws {
        let modelURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appending(path: "assets/models/model_fp32.onnx")
        let session = try ONNXRuntimeSession(modelURL: modelURL)
        let frameCount = 128
        let featureCount = 80
        let features = Array(repeating: Float(0), count: featureCount * frameCount)

        let logProbabilities = try session.runLogProbabilities(features: features, featureCount: featureCount, frameCount: frameCount)

        XCTAssertEqual(logProbabilities.vocabularySize, 1_025)
        XCTAssertEqual(logProbabilities.timeStepCount, (frameCount + 7) / 8)
        XCTAssertEqual(logProbabilities.values.count, logProbabilities.timeStepCount * logProbabilities.vocabularySize)
        XCTAssertTrue(logProbabilities.values.allSatisfy { $0.isFinite })
    }
}
