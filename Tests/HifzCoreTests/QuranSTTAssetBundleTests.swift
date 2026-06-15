import XCTest
@testable import HifzCore

final class QuranSTTAssetBundleTests: XCTestCase {
    func testDiscoversLocalFp32ModelAndTokenizerAssets() throws {
        let bundle = QuranSTTAssetBundle(sourceRoot: localModelRoot())

        let validation = bundle.validateRequiredFiles()

        XCTAssertTrue(validation.missingFiles.isEmpty)
        XCTAssertEqual(bundle.modelURL.lastPathComponent, "model_fp32.onnx")
        XCTAssertEqual(bundle.tokenizerFiles.map(\.lastPathComponent).sorted(), [
            "model_config.yaml",
            "tokenizer.json",
            "tokenizer.model",
            "tokenizer_config.json",
            "tokens.txt"
        ])
        XCTAssertGreaterThan(try bundle.modelByteCount(), 400_000_000)
    }

    func testParsesModelConfigForAudioPreprocessingConstants() throws {
        let bundle = QuranSTTAssetBundle(sourceRoot: localModelRoot())

        let config = try bundle.loadModelConfiguration()

        XCTAssertEqual(config.sampleRate, 16_000)
        XCTAssertEqual(config.featureCount, 80)
        XCTAssertEqual(config.fftSize, 512)
        XCTAssertEqual(config.vocabularySize, 1_024)
        XCTAssertEqual(config.tokenCount, 1_025)
        XCTAssertEqual(config.windowSize, 0.025, accuracy: 0.0001)
        XCTAssertEqual(config.windowStride, 0.01, accuracy: 0.0001)
    }

    func testLoadsTokenizerVocabularyAndDecodesSentencePieceTokens() throws {
        let bundle = QuranSTTAssetBundle(sourceRoot: localModelRoot())

        let tokenizer = try bundle.loadTokenizer()

        XCTAssertEqual(tokenizer.vocabularySize, 1_025)
        XCTAssertEqual(tokenizer.blankID, 1_024)
        XCTAssertEqual(tokenizer.token(for: 6), "ا")
        XCTAssertEqual(try tokenizer.decode(tokenIDs: [1_009, 9, 1_003]), "اللَّهِ و اللَّهُ")
        XCTAssertThrowsError(try tokenizer.decode(tokenIDs: [1_999]))
    }

    private func localModelRoot() -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appending(path: "quran-stt-onnx")
    }
}
