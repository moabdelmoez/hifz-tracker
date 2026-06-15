import Foundation
import HifzCore

enum AppASRError: Error, LocalizedError {
    case missingBundledResource(String)

    var errorDescription: String? {
        switch self {
        case let .missingBundledResource(name):
            "Missing bundled ASR resource: \(name)."
        }
    }
}

actor LiveQuranTranscriptionService {
    private let transcriber: QuranSTTTranscriber

    init(transcriber: QuranSTTTranscriber) {
        self.transcriber = transcriber
    }

    func transcribe(samples: [Float]) throws -> QuranSTTTranscript {
        try transcriber.transcribe(samples: samples)
    }
}

enum AppASRFactory {
    static func makeLiveService(bundle: Bundle = .main) throws -> LiveQuranTranscriptionService {
        guard let modelURL = bundle.url(forResource: "model_fp32", withExtension: "onnx", subdirectory: "Models") else {
            throw AppASRError.missingBundledResource("Models/model_fp32.onnx")
        }
        guard let tokensURL = bundle.url(forResource: "tokens", withExtension: "txt", subdirectory: "Tokenizer") else {
            throw AppASRError.missingBundledResource("Tokenizer/tokens.txt")
        }

        let tokenizer = try QuranSTTTokenizer(tokensURL: tokensURL)
        let transcriber = try QuranSTTTranscriber(
            session: ONNXRuntimeSession(modelURL: modelURL),
            tokenizer: tokenizer,
            featureExtractor: LogMelFeatureExtractor()
        )
        return LiveQuranTranscriptionService(transcriber: transcriber)
    }
}
