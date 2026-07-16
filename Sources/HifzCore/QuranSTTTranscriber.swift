import Foundation

public struct QuranSTTTimedWord: Equatable, Sendable {
    public var text: String
    public var timeStepRange: Range<Int>

    public init(text: String, timeStepRange: Range<Int>) {
        self.text = text
        self.timeStepRange = timeStepRange
    }
}

public struct QuranSTTTranscript: Equatable, Sendable {
    public var text: String
    public var tokenIDs: [Int]
    public var timedWords: [QuranSTTTimedWord]
    public var logProbabilities: ONNXLogProbabilities

    public init(
        text: String,
        tokenIDs: [Int],
        timedWords: [QuranSTTTimedWord] = [],
        logProbabilities: ONNXLogProbabilities
    ) {
        self.text = text
        self.tokenIDs = tokenIDs
        self.timedWords = timedWords
        self.logProbabilities = logProbabilities
    }

    public func wordEvidence(in sampleRange: Range<Int>) throws -> [TranscriptWordEvidence] {
        let timeStepCount = logProbabilities.timeStepCount
        guard timeStepCount > 0, !sampleRange.isEmpty, !timedWords.isEmpty else {
            throw QuranSTTWordTimingError.missingTiming
        }

        let normalizedTranscript = QuranTextNormalizer.asrComparable(text)
        let normalizedWords = timedWords.map { QuranTextNormalizer.asrComparable($0.text) }
        guard normalizedWords.allSatisfy({ !$0.isEmpty && !$0.contains(" ") }),
              normalizedWords.joined(separator: " ") == normalizedTranscript else {
            throw QuranSTTWordTimingError.inconsistentTiming
        }

        var previousUpperBound = 0
        let sampleCount = sampleRange.count
        return try zip(timedWords, normalizedWords).map { timedWord, normalizedWord in
            let range = timedWord.timeStepRange
            guard !range.isEmpty,
                  range.lowerBound >= previousUpperBound,
                  range.upperBound <= timeStepCount else {
                throw QuranSTTWordTimingError.inconsistentTiming
            }
            previousUpperBound = range.upperBound

            let lowerBound = sampleRange.lowerBound + (range.lowerBound * sampleCount / timeStepCount)
            let upperOffset = (range.upperBound * sampleCount + timeStepCount - 1) / timeStepCount
            let upperBound = sampleRange.lowerBound + upperOffset
            return TranscriptWordEvidence(
                text: normalizedWord,
                sampleRange: lowerBound..<upperBound
            )
        }
    }
}

public enum QuranSTTWordTimingError: Error, Equatable {
    case missingTiming
    case inconsistentTiming
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
        let decodedTokens = CTCGreedyDecoder(blankID: tokenizer.blankID).decodeTimed(
            tokenIDsByFrame: tokenIDsByFrame
        )
        let tokenIDs = decodedTokens.map(\.tokenID)
        return QuranSTTTranscript(
            text: try tokenizer.decode(tokenIDs: tokenIDs),
            tokenIDs: tokenIDs,
            timedWords: try tokenizer.decodeTimedWords(tokens: decodedTokens),
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
