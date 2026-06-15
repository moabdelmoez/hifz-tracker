import Foundation

public struct QuranSTTTranscript: Equatable, Sendable {
    public var text: String
    public var tokenIDs: [Int]
    public var logProbabilities: ONNXLogProbabilities

    public init(text: String, tokenIDs: [Int], logProbabilities: ONNXLogProbabilities) {
        self.text = text
        self.tokenIDs = tokenIDs
        self.logProbabilities = logProbabilities
    }
}

public struct QuranSTTTranscriber {
    private let session: ONNXRuntimeSession
    private let tokenizer: QuranSTTTokenizer
    private let featureExtractor: LogMelFeatureExtractor

    public init(
        session: ONNXRuntimeSession,
        tokenizer: QuranSTTTokenizer,
        featureExtractor: LogMelFeatureExtractor
    ) throws {
        self.session = session
        self.tokenizer = tokenizer
        self.featureExtractor = featureExtractor
    }

    public func transcribe(wavURL: URL) throws -> QuranSTTTranscript {
        let audio = try WAVAudioFile(url: wavURL)
        return try transcribe(samples: audio.samples)
    }

    public func transcribe(samples: [Float]) throws -> QuranSTTTranscript {
        let features = featureExtractor.extract(samples: samples)
        let logProbabilities = try session.runLogProbabilities(
            features: features.values,
            featureCount: features.featureCount,
            frameCount: features.frameCount
        )
        let tokenIDsByFrame = logProbabilities.argmaxTokenIDs()
        let tokenIDs = CTCGreedyDecoder(blankID: tokenizer.blankID).decode(tokenIDsByFrame: tokenIDsByFrame)
        return QuranSTTTranscript(
            text: try tokenizer.decode(tokenIDs: tokenIDs),
            tokenIDs: tokenIDs,
            logProbabilities: logProbabilities
        )
    }
}

public extension ONNXLogProbabilities {
    func argmaxTokenIDs() -> [Int] {
        guard vocabularySize > 0, timeStepCount > 0 else { return [] }

        return (0..<timeStepCount).map { timeStep in
            let start = timeStep * vocabularySize
            let end = min(values.count, start + vocabularySize)
            guard start < end else { return 0 }

            var bestIndex = start
            var bestValue = values[start]
            for index in (start + 1)..<end where values[index] > bestValue {
                bestIndex = index
                bestValue = values[index]
            }
            return bestIndex - start
        }
    }
}
