import Foundation

public struct QuranSTTAssetBundle: Sendable {
    public struct Validation: Equatable, Sendable {
        public var missingFiles: [String]
    }

    public let sourceRoot: URL

    public init(sourceRoot: URL) {
        self.sourceRoot = sourceRoot
    }

    public var modelURL: URL {
        sourceRoot.appending(path: "onnx/model_fp32.onnx")
    }

    public var modelConfigurationURL: URL {
        sourceRoot.appending(path: "model_config.yaml")
    }

    public var tokensURL: URL {
        sourceRoot.appending(path: "tokens.txt")
    }

    public var tokenizerFiles: [URL] {
        [
            sourceRoot.appending(path: "tokenizer.json"),
            sourceRoot.appending(path: "tokenizer.model"),
            sourceRoot.appending(path: "tokenizer_config.json"),
            sourceRoot.appending(path: "tokens.txt"),
            sourceRoot.appending(path: "model_config.yaml")
        ]
    }

    public func validateRequiredFiles(fileManager: FileManager = .default) -> Validation {
        let files = [modelURL] + tokenizerFiles
        let missing = files
            .filter { !fileManager.fileExists(atPath: $0.path) }
            .map { $0.path.replacingOccurrences(of: sourceRoot.path + "/", with: "") }
        return Validation(missingFiles: missing)
    }

    public func modelByteCount(fileManager: FileManager = .default) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: modelURL.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    public func loadModelConfiguration() throws -> QuranSTTModelConfiguration {
        let yaml = try String(contentsOf: modelConfigurationURL, encoding: .utf8)
        let tokens = try String(contentsOf: tokensURL, encoding: .utf8)
        return try QuranSTTModelConfiguration(yaml: yaml, tokenFile: tokens)
    }

    public func loadTokenizer() throws -> QuranSTTTokenizer {
        try QuranSTTTokenizer(tokensURL: tokensURL)
    }
}

public struct QuranSTTModelConfiguration: Equatable, Sendable {
    public var sampleRate: Int
    public var featureCount: Int
    public var fftSize: Int
    public var vocabularySize: Int
    public var tokenCount: Int
    public var windowSize: Double
    public var windowStride: Double

    public init(
        sampleRate: Int,
        featureCount: Int,
        fftSize: Int,
        vocabularySize: Int,
        tokenCount: Int,
        windowSize: Double,
        windowStride: Double
    ) {
        self.sampleRate = sampleRate
        self.featureCount = featureCount
        self.fftSize = fftSize
        self.vocabularySize = vocabularySize
        self.tokenCount = tokenCount
        self.windowSize = windowSize
        self.windowStride = windowStride
    }

    public init(yaml: String, tokenFile: String) throws {
        self.init(
            sampleRate: try Self.intValue(for: "sample_rate", in: yaml),
            featureCount: try Self.intValue(for: "features", in: yaml),
            fftSize: try Self.intValue(for: "n_fft", in: yaml),
            vocabularySize: try Self.intValue(for: "vocab_size", in: yaml),
            tokenCount: tokenFile.split(whereSeparator: \.isNewline).count,
            windowSize: try Self.doubleValue(for: "window_size", in: yaml),
            windowStride: try Self.doubleValue(for: "window_stride", in: yaml)
        )
    }

    private static func intValue(for key: String, in yaml: String) throws -> Int {
        guard let value = scalarValue(for: key, in: yaml), let int = Int(value) else {
            throw QuranSTTAssetError.missingConfigValue(key)
        }
        return int
    }

    private static func doubleValue(for key: String, in yaml: String) throws -> Double {
        guard let value = scalarValue(for: key, in: yaml), let double = Double(value) else {
            throw QuranSTTAssetError.missingConfigValue(key)
        }
        return double
    }

    private static func scalarValue(for key: String, in yaml: String) -> String? {
        for line in yaml.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\(key):") else { continue }
            return trimmed
                .dropFirst(key.count + 1)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}

public enum QuranSTTAssetError: Error, Equatable {
    case missingConfigValue(String)
}
