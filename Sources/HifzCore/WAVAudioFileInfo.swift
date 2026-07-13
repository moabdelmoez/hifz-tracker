@preconcurrency import AVFAudio
import Foundation

public struct WAVAudioFileInfo: Equatable, Sendable {
    public var sampleRate: Int
    public var channelCount: Int
    public var bitsPerSample: Int
    public var frameCount: Int

    public init(url: URL) throws {
        let file = try AVAudioFile(forReading: url)
        let format = file.fileFormat
        sampleRate = Int(format.sampleRate.rounded())
        channelCount = Int(format.channelCount)
        bitsPerSample = Int(format.streamDescription.pointee.mBitsPerChannel)
        frameCount = Int(file.length)
    }
}

public struct WAVAudioFile: Equatable, Sendable {
    public var info: WAVAudioFileInfo
    public var samples: [Float]

    public init(url: URL) throws {
        let file = try AVAudioFile(forReading: url)
        guard file.length <= AVAudioFramePosition(UInt32.max),
              let input = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
              ) else {
            throw CocoaError(.fileReadTooLarge)
        }
        try file.read(into: input)

        guard let monoFormat = AVAudioFormat(
            standardFormatWithSampleRate: input.format.sampleRate,
            channels: 1
        ),
        let output = AVAudioPCMBuffer(
            pcmFormat: monoFormat,
            frameCapacity: input.frameLength
        ),
        let converter = AVAudioConverter(from: input.format, to: monoFormat) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        converter.downmix = true
        try converter.convert(to: output, from: input)

        guard let channel = output.floatChannelData?[0] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        info = try WAVAudioFileInfo(url: url)
        samples = Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
    }
}
