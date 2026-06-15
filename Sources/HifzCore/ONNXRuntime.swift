import COnnxRuntimeShim
import Foundation

public enum ONNXRuntime {
    public static func versionString() -> String {
        String(cString: HifzORTVersionString())
    }
}

public final class ONNXRuntimeSession {
    public let inputNames: [String]
    public let outputNames: [String]

    private let handle: OpaquePointer

    public init(modelURL: URL) throws {
        var handle: OpaquePointer?
        var errorPointer: UnsafeMutablePointer<CChar>?
        let status = modelURL.path.withCString { path in
            HifzORTCreateSession(path, &handle, &errorPointer)
        }
        try Self.check(status, errorPointer: errorPointer)

        guard let handle else {
            throw ONNXRuntimeError.sessionCreationFailed("ONNX Runtime did not return a session handle.")
        }

        do {
            self.inputNames = try Self.names(
                handle: handle,
                count: HifzORTSessionInputCount,
                name: HifzORTSessionInputName
            )
            self.outputNames = try Self.names(
                handle: handle,
                count: HifzORTSessionOutputCount,
                name: HifzORTSessionOutputName
            )
            self.handle = handle
        } catch {
            HifzORTDestroySession(handle)
            throw error
        }
    }

    deinit {
        HifzORTDestroySession(handle)
    }

    public func runLogProbabilities(features: [Float], featureCount: Int, frameCount: Int) throws -> ONNXLogProbabilities {
        guard featureCount > 0, frameCount > 0 else {
            throw ONNXRuntimeError.inferenceFailed("Feature and frame counts must be positive.")
        }
        guard features.count == featureCount * frameCount else {
            throw ONNXRuntimeError.inferenceFailed(
                "Expected \(featureCount * frameCount) feature values, received \(features.count)."
            )
        }

        var output = HifzORTLogProbabilities()
        var errorPointer: UnsafeMutablePointer<CChar>?
        let status = features.withUnsafeBufferPointer { buffer in
            HifzORTRunLogProbabilities(
                handle,
                buffer.baseAddress,
                CInt(featureCount),
                CInt(frameCount),
                &output,
                &errorPointer
            )
        }
        try Self.check(status, errorPointer: errorPointer, error: ONNXRuntimeError.inferenceFailed)

        guard let valuesPointer = output.values else {
            throw ONNXRuntimeError.inferenceFailed("ONNX Runtime returned an empty log probability buffer.")
        }
        defer { HifzORTFreeFloatBuffer(valuesPointer) }

        let values = Array(UnsafeBufferPointer(start: valuesPointer, count: Int(output.value_count)))
        return ONNXLogProbabilities(
            values: values,
            timeStepCount: Int(output.time_step_count),
            vocabularySize: Int(output.vocabulary_size)
        )
    }

    private static func names(
        handle: OpaquePointer,
        count: (OpaquePointer?, UnsafeMutablePointer<CInt>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> CInt,
        name: (OpaquePointer?, CInt, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> CInt
    ) throws -> [String] {
        var countValue: CInt = 0
        var errorPointer: UnsafeMutablePointer<CChar>?
        try check(count(handle, &countValue, &errorPointer), errorPointer: errorPointer, error: ONNXRuntimeError.metadataReadFailed)

        return try (0..<countValue).map { index in
            var namePointer: UnsafeMutablePointer<CChar>?
            var errorPointer: UnsafeMutablePointer<CChar>?
            try check(name(handle, index, &namePointer, &errorPointer), errorPointer: errorPointer, error: ONNXRuntimeError.metadataReadFailed)
            guard let namePointer else {
                throw ONNXRuntimeError.metadataReadFailed("ONNX Runtime returned an empty metadata name.")
            }
            defer { HifzORTFreeString(namePointer) }
            return String(cString: namePointer)
        }
    }

    private static func check(
        _ status: CInt,
        errorPointer: UnsafeMutablePointer<CChar>?,
        error: (String) -> ONNXRuntimeError = ONNXRuntimeError.sessionCreationFailed
    ) throws {
        guard status == 0 else {
            defer {
                if let errorPointer {
                    HifzORTFreeString(errorPointer)
                }
            }
            let message = errorPointer.map { String(cString: $0) } ?? "Unknown ONNX Runtime error."
            throw error(message)
        }

        if let errorPointer {
            HifzORTFreeString(errorPointer)
        }
    }
}

public struct ONNXLogProbabilities: Equatable, Sendable {
    public var values: [Float]
    public var timeStepCount: Int
    public var vocabularySize: Int

    public init(values: [Float], timeStepCount: Int, vocabularySize: Int) {
        self.values = values
        self.timeStepCount = timeStepCount
        self.vocabularySize = vocabularySize
    }
}

public enum ONNXRuntimeError: Error, Equatable, CustomStringConvertible {
    case sessionCreationFailed(String)
    case metadataReadFailed(String)
    case inferenceFailed(String)

    public var description: String {
        switch self {
        case let .sessionCreationFailed(message), let .metadataReadFailed(message), let .inferenceFailed(message):
            message
        }
    }
}
