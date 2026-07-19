import Foundation
import HifzCore
import OSLog

private let asrFactoryLogger = Logger(subsystem: "dev.mostafa.HifzTracker", category: "ASR")

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
    static let warmedLiveService = Task.detached(priority: .utility) {
        let startedAt = DispatchTime.now().uptimeNanoseconds
        do {
            let service = try makeLiveService()
            _ = try await service.transcribe(samples: Array(repeating: 0, count: 16_000))
            let elapsedMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - startedAt) / 1_000_000
            asrFactoryLogger.info("live_asr_timing event=warmup_ready processing_ms=\(elapsedMilliseconds, privacy: .public)")
            return service
        } catch {
            asrFactoryLogger.error("live_asr_timing event=warmup_failed")
            throw error
        }
    }

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
