@preconcurrency import AVFoundation
import OSLog

private let microphoneLogger = Logger(subsystem: "dev.mostafa.HifzTracker", category: "Microphone")
typealias MicrophoneSampleHandler = @Sendable ([Float]) -> Void

enum MicrophoneCaptureError: Error, LocalizedError {
    case permissionDenied
    case inputFormatUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Microphone permission was denied."
        case .inputFormatUnavailable:
            "No microphone input format is available."
        }
    }
}

@MainActor
final class MicrophoneCaptureService {
    private let engine = AVAudioEngine()
    private var isRunning = false

    func startDiscardingAudio() async throws {
        try await startStreamingAudio { _ in }
    }

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

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format, block: makeAudioTap(onSamples: onSamples))
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

private func makeAudioTap(onSamples: @escaping MicrophoneSampleHandler) -> AVAudioNodeTapBlock {
    { buffer, _ in
        let samples = makeMono16kSamples(from: buffer)
        guard !samples.isEmpty else { return }
        onSamples(samples)
    }
}

private func makeMono16kSamples(from buffer: AVAudioPCMBuffer) -> [Float] {
    guard
        let channelData = buffer.floatChannelData,
        buffer.frameLength > 0,
        buffer.format.channelCount > 0
    else {
        return []
    }

    let frameCount = Int(buffer.frameLength)
    let channelCount = Int(buffer.format.channelCount)
    var mono = [Float](repeating: 0, count: frameCount)

    if buffer.format.isInterleaved {
        let interleaved = channelData[0]
        for frameIndex in 0..<frameCount {
            var value = Float(0)
            for channelIndex in 0..<channelCount {
                value += interleaved[frameIndex * channelCount + channelIndex]
            }
            mono[frameIndex] = value / Float(channelCount)
        }
    } else {
        for frameIndex in 0..<frameCount {
            var value = Float(0)
            for channelIndex in 0..<channelCount {
                value += channelData[channelIndex][frameIndex]
            }
            mono[frameIndex] = value / Float(channelCount)
        }
    }

    return resample(samples: mono, sourceSampleRate: buffer.format.sampleRate, targetSampleRate: 16_000)
}

private func resample(samples: [Float], sourceSampleRate: Double, targetSampleRate: Double) -> [Float] {
    guard !samples.isEmpty, sourceSampleRate > 0, targetSampleRate > 0 else {
        return []
    }

    guard abs(sourceSampleRate - targetSampleRate) > 0.5 else {
        return samples
    }

    let outputCount = max(1, Int((Double(samples.count) * targetSampleRate / sourceSampleRate).rounded(.down)))
    let sourceStep = sourceSampleRate / targetSampleRate
    var output = [Float](repeating: 0, count: outputCount)

    for outputIndex in 0..<outputCount {
        let sourcePosition = Double(outputIndex) * sourceStep
        let lowerIndex = min(samples.count - 1, Int(sourcePosition.rounded(.down)))
        let upperIndex = min(samples.count - 1, lowerIndex + 1)
        let fraction = Float(sourcePosition - Double(lowerIndex))
        output[outputIndex] = samples[lowerIndex] + (samples[upperIndex] - samples[lowerIndex]) * fraction
    }

    return output
}
