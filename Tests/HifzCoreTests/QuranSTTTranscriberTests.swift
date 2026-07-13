import XCTest
@testable import HifzCore

final class QuranSTTTranscriberTests: XCTestCase {
    func testTranscribesBasfarIkhlasDemoFixture() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let modelURL = root.appending(path: "assets/models/model_fp32.onnx")
        let tokenizer = try QuranSTTTokenizer(
            tokensURL: root.appending(path: "quran-stt-onnx/tokens.txt")
        )
        let transcriber = try QuranSTTTranscriber(
            session: ONNXRuntimeSession(modelURL: modelURL),
            tokenizer: tokenizer,
            featureExtractor: LogMelFeatureExtractor()
        )

        let transcript = try transcriber.transcribe(wavURL: root.appending(path: "quran-stt-onnx/demo/02_basfar_ikhlas.wav"))

        XCTAssertFalse(transcript.tokenIDs.isEmpty)
        XCTAssertEqual(transcript.logProbabilities.vocabularySize, 1_025)
        XCTAssertTrue(
            QuranTextNormalizer.asrComparable(transcript.text).contains("قل هو الله احد"),
            transcript.text
        )
    }
}
