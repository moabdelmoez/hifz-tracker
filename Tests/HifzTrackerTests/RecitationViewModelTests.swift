import XCTest
@testable import HifzTracker

final class RecitationViewModelTests: XCTestCase {
    @MainActor
    func testDefaultsToBeginningOfSelectedSurah() {
        let viewModel = RecitationViewModel(repository: nil)

        XCTAssertEqual(viewModel.selectedSurah, 73)
        XCTAssertEqual(viewModel.startAyah, 1)
    }

    func testAudioLevelMeterKeepsSilenceAtZero() {
        var meter = AudioLevelMeter()

        let level = meter.update(with: Array(repeating: Float(0), count: 128))

        XCTAssertEqual(level, 0, accuracy: 0.001)
        XCTAssertEqual(meter.level, 0, accuracy: 0.001)
    }

    func testAudioLevelMeterRaisesLevelForLoudSamples() {
        var meter = AudioLevelMeter()

        let level = meter.update(with: Array(repeating: Float(0.75), count: 128))

        XCTAssertGreaterThan(level, 0.45)
        XCTAssertLessThanOrEqual(level, 1)
    }

    func testAudioLevelMeterDecaysSmoothlyForQuietSamplesAndResets() {
        var meter = AudioLevelMeter()
        let loudLevel = meter.update(with: Array(repeating: Float(0.85), count: 128))

        let quietLevel = meter.update(with: Array(repeating: Float(0), count: 128))

        XCTAssertGreaterThan(quietLevel, 0)
        XCTAssertLessThan(quietLevel, loudLevel)

        meter.reset()

        XCTAssertEqual(meter.level, 0, accuracy: 0.001)
    }
}
