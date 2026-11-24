import SwiftUI
import XCTest
@testable import HifzTracker

final class RecognitionTranscriptPreferenceTests: XCTestCase {
    func testRecognitionTranscriptIsOptInForFreshProfile() throws {
        let name = UUID().uuidString
        let store = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { store.removePersistentDomain(forName: name) }

        XCTAssertFalse(RecognitionTranscriptPreference.storage(in: store).wrappedValue)
    }

    func testPreviouslySavedOptInStillShowsTheRecognitionTranscript() throws {
        let name = UUID().uuidString
        let store = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { store.removePersistentDomain(forName: name) }
        store.set(true, forKey: "showDebugTranscript")

        XCTAssertTrue(RecognitionTranscriptPreference.storage(in: store).wrappedValue)
    }
}
