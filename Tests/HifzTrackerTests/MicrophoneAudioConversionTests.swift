import AVFAudio
import XCTest
@testable import HifzTracker

final class MicrophoneAudioConversionTests: XCTestCase {
    func testConversionAttenuatesFrequenciesAboveTargetNyquistLimit() throws {
        let inputFormat = try XCTUnwrap(AVAudioFormat(
            standardFormatWithSampleRate: 48_000,
            channels: 1
        ))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(
            pcmFormat: inputFormat,
            frameCapacity: 48_000
        ))
        buffer.frameLength = 48_000
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        for index in 0..<Int(buffer.frameLength) {
            samples[index] = Float(sin(2 * Double.pi * 12_000 * Double(index) / 48_000))
        }

        let converted = try Mono16kAudioConverter(inputFormat: inputFormat).convert(buffer)
        let rms = sqrt(converted.reduce(0) { $0 + $1 * $1 } / Float(converted.count))

        XCTAssertLessThan(rms, 0.1)
    }
}
