import XCTest
@testable import HifzCore

final class WAVAudioFileInfoTests: XCTestCase {
    func testReadsDemoFixtureFormat() throws {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appending(path: "quran-stt-onnx/demo/01_alafasy_fatihah.wav")

        let info = try WAVAudioFileInfo(url: url)

        XCTAssertEqual(info.sampleRate, 16_000)
        XCTAssertEqual(info.channelCount, 1)
        XCTAssertEqual(info.bitsPerSample, 16)
        XCTAssertEqual(info.frameCount, 74_815)
    }

    func testLoadsDemoFixtureAsNormalizedMonoSamples() throws {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appending(path: "quran-stt-onnx/demo/01_alafasy_fatihah.wav")

        let audio = try WAVAudioFile(url: url)

        XCTAssertEqual(audio.info.sampleRate, 16_000)
        XCTAssertEqual(audio.info.channelCount, 1)
        XCTAssertEqual(audio.samples.count, 74_815)
        XCTAssertLessThanOrEqual(audio.samples.map(abs).max() ?? 0, 1)
        XCTAssertNotEqual(audio.samples.prefix(1_000).reduce(Float(0), +), 0)
    }
}
