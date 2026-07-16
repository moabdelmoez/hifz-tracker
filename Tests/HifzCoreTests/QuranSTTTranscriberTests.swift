import XCTest
@testable import HifzCore

final class QuranSTTTranscriberTests: XCTestCase {
    func testMapsWordTimeStepsIntoAbsoluteSampleRanges() throws {
        let transcript = QuranSTTTranscript(
            text: "one two",
            tokenIDs: [1, 2],
            timedWords: [
                QuranSTTTimedWord(text: "one", timeStepRange: 1..<3),
                QuranSTTTimedWord(text: "two", timeStepRange: 5..<7)
            ],
            logProbabilities: ONNXLogProbabilities(values: [], timeStepCount: 10, vocabularySize: 0)
        )

        XCTAssertEqual(try transcript.wordEvidence(in: 100..<200), [
            TranscriptWordEvidence(text: "one", sampleRange: 110..<130),
            TranscriptWordEvidence(text: "two", sampleRange: 150..<170)
        ])
    }

    func testRejectsWordTimingThatDoesNotMatchTranscript() {
        let transcript = QuranSTTTranscript(
            text: "one two",
            tokenIDs: [1],
            timedWords: [QuranSTTTimedWord(text: "one", timeStepRange: 1..<3)],
            logProbabilities: ONNXLogProbabilities(values: [], timeStepCount: 10, vocabularySize: 0)
        )

        XCTAssertThrowsError(try transcript.wordEvidence(in: 100..<200)) { error in
            XCTAssertEqual(error as? QuranSTTWordTimingError, .inconsistentTiming)
        }
    }

    func testTokenizerGroupsTimedPiecesIntoWords() throws {
        let tokenizer = try QuranSTTTokenizer(tokenFile: """
        <blk> 0
        ▁قل 1
        ه 2
        ▁هو 3
        """)

        let words = try tokenizer.decodeTimedWords(tokens: [
            CTCDecodedToken(tokenID: 1, timeStepRange: 1..<3),
            CTCDecodedToken(tokenID: 2, timeStepRange: 3..<4),
            CTCDecodedToken(tokenID: 3, timeStepRange: 5..<7)
        ])

        XCTAssertEqual(words, [
            QuranSTTTimedWord(text: "قله", timeStepRange: 1..<4),
            QuranSTTTimedWord(text: "هو", timeStepRange: 5..<7)
        ])
    }

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
        XCTAssertFalse(transcript.timedWords.isEmpty)
        XCTAssertFalse(try transcript.wordEvidence(in: 0..<16_000).isEmpty)
        XCTAssertEqual(transcript.logProbabilities.vocabularySize, 1_025)
        XCTAssertTrue(
            QuranTextNormalizer.asrComparable(transcript.text).contains("قل هو الله احد"),
            transcript.text
        )
    }
}
