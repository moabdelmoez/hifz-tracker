@preconcurrency import AVFoundation
import OSLog

private let microphoneLogger = Logger(subsystem: "dev.mostafa.HifzTracker", category: "Microphone")
typealias MicrophoneSampleHandler = @Sendable ([Float]) -> Void

enum MicrophoneCaptureError: Error, LocalizedError {
    case permissionDenied
    case inputFormatUnavailable
    case audioConversionFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Microphone permission was denied."
        case .inputFormatUnavailable:
            "No microphone input format is available."
        case .audioConversionFailed:
            "Microphone audio conversion failed."
        }
    }
}

@MainActor
final class MicrophoneCaptureService {
    private let engine = AVAudioEngine()
    private var isRunning = false

    func startStreamingAudio(_ onSamples: @escaping MicrophoneSampleHandler) async throws {
        microphoneLogger.info("Microphone capture start requested")
        guard try await requestPermission() else {
            microphoneLogger.error("Microphone permission denied")
            throw MicrophoneCaptureError.permissionDenied
        }

        if isRunning {
            microphoneLogger.info("Microphone capture already running")
            return
        }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            microphoneLogger.error("Microphone input format unavailable")
            throw MicrophoneCaptureError.inputFormatUnavailable
        }
        let converter = try Mono16kAudioConverter(inputFormat: format)

        input.removeTap(onBus: 0)
        input.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: format,
            block: makeAudioTap(converter: converter, onSamples: onSamples)
        )
        microphoneLogger.info("Microphone audio tap installed at \(format.sampleRate, privacy: .public) Hz, \(format.channelCount, privacy: .public) channels")

        engine.prepare()
        try engine.start()
        isRunning = true
        microphoneLogger.info("Microphone capture started")
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        microphoneLogger.info("Microphone capture stopped")
    }

    private func requestPermission() async throws -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}

private func makeAudioTap(
    converter: Mono16kAudioConverter,
    onSamples: @escaping MicrophoneSampleHandler
) -> AVAudioNodeTapBlock {
    { buffer, _ in
        do {
            let samples = try converter.convert(buffer)
            guard !samples.isEmpty else { return }
            onSamples(samples)
        } catch {
            microphoneLogger.error("Microphone audio conversion failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

final class Mono16kAudioConverter: @unchecked Sendable {
    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat

    init(inputFormat: AVAudioFormat) throws {
        guard let outputFormat = AVAudioFormat(
            standardFormatWithSampleRate: 16_000,
            channels: 1
        ),
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw MicrophoneCaptureError.inputFormatUnavailable
        }
        converter.downmix = true
        converter.sampleRateConverterQuality = AVAudioQuality.max.rawValue
        self.converter = converter
        self.outputFormat = outputFormat
    }

    func convert(_ input: AVAudioPCMBuffer) throws -> [Float] {
        guard input.frameLength > 0 else { return [] }
        let capacity = AVAudioFrameCount(ceil(
            Double(input.frameLength) * outputFormat.sampleRate / input.format.sampleRate
        )) + 32
        guard let output = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: capacity
        ) else {
            throw MicrophoneCaptureError.audioConversionFailed
        }

        let inputProvider = AudioConverterInput(input)
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            guard let input = inputProvider.take() else {
                inputStatus.pointee = .noDataNow
                return nil
            }
            inputStatus.pointee = .haveData
            return input
        }
        if status == .error {
            throw conversionError ?? MicrophoneCaptureError.audioConversionFailed
        }
        guard let channel = output.floatChannelData?[0] else {
            throw MicrophoneCaptureError.audioConversionFailed
        }
        return Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
    }
}

private final class AudioConverterInput: @unchecked Sendable {
    private var buffer: AVAudioPCMBuffer?

    init(_ buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func take() -> AVAudioPCMBuffer? {
        defer { buffer = nil }
        return buffer
    }
}
