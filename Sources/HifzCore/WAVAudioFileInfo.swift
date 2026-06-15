import Foundation

public struct WAVAudioFileInfo: Equatable, Sendable {
    public var sampleRate: Int
    public var channelCount: Int
    public var bitsPerSample: Int
    public var frameCount: Int

    public init(url: URL) throws {
        let data = try Data(contentsOf: url)
        guard data.count >= 44 else {
            throw WAVAudioFileInfoError.invalidHeader
        }
        guard String(decoding: data[0..<4], as: UTF8.self) == "RIFF",
              String(decoding: data[8..<12], as: UTF8.self) == "WAVE" else {
            throw WAVAudioFileInfoError.invalidHeader
        }

        var offset = 12
        var format: Format?
        var dataByteCount: UInt32?

        while offset + 8 <= data.count {
            let id = String(decoding: data[offset..<offset + 4], as: UTF8.self)
            let size = Int(data.littleEndianUInt32(at: offset + 4))
            let bodyStart = offset + 8
            let bodyEnd = bodyStart + size
            guard bodyEnd <= data.count else {
                throw WAVAudioFileInfoError.invalidChunk
            }

            if id == "fmt " {
                guard size >= 16 else { throw WAVAudioFileInfoError.invalidChunk }
                format = Format(
                    audioFormat: data.littleEndianUInt16(at: bodyStart),
                    channels: data.littleEndianUInt16(at: bodyStart + 2),
                    sampleRate: data.littleEndianUInt32(at: bodyStart + 4),
                    bitsPerSample: data.littleEndianUInt16(at: bodyStart + 14)
                )
            } else if id == "data" {
                dataByteCount = UInt32(size)
            }

            offset = bodyEnd + (size % 2)
        }

        guard let format, let dataByteCount, format.audioFormat == 1 else {
            throw WAVAudioFileInfoError.unsupportedFormat
        }

        let bytesPerFrame = Int(format.channels) * Int(format.bitsPerSample / 8)
        guard bytesPerFrame > 0 else {
            throw WAVAudioFileInfoError.unsupportedFormat
        }

        self.sampleRate = Int(format.sampleRate)
        self.channelCount = Int(format.channels)
        self.bitsPerSample = Int(format.bitsPerSample)
        self.frameCount = Int(dataByteCount) / bytesPerFrame
    }

    private struct Format {
        var audioFormat: UInt16
        var channels: UInt16
        var sampleRate: UInt32
        var bitsPerSample: UInt16
    }
}

public struct WAVAudioFile: Equatable, Sendable {
    public var info: WAVAudioFileInfo
    public var samples: [Float]

    public init(url: URL) throws {
        let data = try Data(contentsOf: url)
        self.info = try WAVAudioFileInfo(url: url)

        guard String(decoding: data[0..<4], as: UTF8.self) == "RIFF",
              String(decoding: data[8..<12], as: UTF8.self) == "WAVE" else {
            throw WAVAudioFileInfoError.invalidHeader
        }

        var offset = 12
        var format: Format?
        var audioDataRange: Range<Int>?

        while offset + 8 <= data.count {
            let id = String(decoding: data[offset..<offset + 4], as: UTF8.self)
            let size = Int(data.littleEndianUInt32(at: offset + 4))
            let bodyStart = offset + 8
            let bodyEnd = bodyStart + size
            guard bodyEnd <= data.count else {
                throw WAVAudioFileInfoError.invalidChunk
            }

            if id == "fmt " {
                guard size >= 16 else { throw WAVAudioFileInfoError.invalidChunk }
                format = Format(
                    audioFormat: data.littleEndianUInt16(at: bodyStart),
                    channels: data.littleEndianUInt16(at: bodyStart + 2),
                    sampleRate: data.littleEndianUInt32(at: bodyStart + 4),
                    bitsPerSample: data.littleEndianUInt16(at: bodyStart + 14)
                )
            } else if id == "data" {
                audioDataRange = bodyStart..<bodyEnd
            }

            offset = bodyEnd + (size % 2)
        }

        guard let format, let audioDataRange, format.audioFormat == 1 else {
            throw WAVAudioFileInfoError.unsupportedFormat
        }
        guard format.bitsPerSample == 16 || format.bitsPerSample == 32 else {
            throw WAVAudioFileInfoError.unsupportedFormat
        }

        let channelCount = Int(format.channels)
        let bytesPerSample = Int(format.bitsPerSample / 8)
        let bytesPerFrame = channelCount * bytesPerSample
        guard channelCount > 0, bytesPerFrame > 0 else {
            throw WAVAudioFileInfoError.unsupportedFormat
        }

        let frameCount = audioDataRange.count / bytesPerFrame
        var samples: [Float] = []
        samples.reserveCapacity(frameCount)

        for frame in 0..<frameCount {
            let frameOffset = audioDataRange.lowerBound + frame * bytesPerFrame
            var mixed = Float(0)
            for channel in 0..<channelCount {
                let sampleOffset = frameOffset + channel * bytesPerSample
                if format.bitsPerSample == 16 {
                    mixed += Float(data.littleEndianInt16(at: sampleOffset)) / 32768.0
                } else {
                    mixed += Float(data.littleEndianInt32(at: sampleOffset)) / 2_147_483_648.0
                }
            }
            samples.append(mixed / Float(channelCount))
        }

        self.samples = samples
    }

    private struct Format {
        var audioFormat: UInt16
        var channels: UInt16
        var sampleRate: UInt32
        var bitsPerSample: UInt16
    }
}

public enum WAVAudioFileInfoError: Error, Equatable {
    case invalidHeader
    case invalidChunk
    case unsupportedFormat
}

private extension Data {
    func littleEndianUInt16(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func littleEndianUInt32(at offset: Int) -> UInt32 {
        UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }

    func littleEndianInt16(at offset: Int) -> Int16 {
        Int16(bitPattern: littleEndianUInt16(at: offset))
    }

    func littleEndianInt32(at offset: Int) -> Int32 {
        Int32(bitPattern: littleEndianUInt32(at: offset))
    }
}
