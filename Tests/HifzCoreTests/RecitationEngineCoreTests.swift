import XCTest
@testable import HifzCore

final class RecitationEngineCoreTests: XCTestCase {
    func testGreedyCtcDecodeCollapsesRepeatsAndKeepsBlankSeparatedRepeats() {
        let decoder = CTCGreedyDecoder(blankID: 0)

        let decoded = decoder.decode(tokenIDsByFrame: [0, 4, 4, 0, 5, 0, 5, 6, 6, 0])

        XCTAssertEqual(decoded, [4, 5, 5, 6])
    }

    func testCorrectionGateRequiresTwoStableStrongMismatches() {
        var gate = CorrectionGate(requiredStableChunks: 2)
        let mismatch = AlignmentMismatch(expectedWordIndex: 3, expectedWord: "الرحمن", recognizedWord: "العالمين")

        XCTAssertNil(gate.observe(mismatch: mismatch))

        let event = gate.observe(mismatch: mismatch)

        XCTAssertEqual(event?.expectedWordIndex, 3)
        XCTAssertEqual(event?.expectedWord, "الرحمن")
        XCTAssertEqual(event?.recognizedWord, "العالمين")
    }

    func testRecitationStateMachineProgressesAndFlagsCorrectionAfterGrace() {
        var reducer = RecitationStateReducer()
        let request = RecitationSessionRequest(surah: 73, startAyah: 4)

        XCTAssertEqual(reducer.reduce(.startRequested(request)).phase, .requestingPermission)
        XCTAssertEqual(reducer.reduce(.permissionGranted).phase, .listening)
        XCTAssertEqual(reducer.reduce(.placeLocked(ayah: 4, word: 1)).phase, .locked)
        XCTAssertEqual(reducer.reduce(.progressAdvanced(ayah: 4, completedWordCount: 3)).phase, .progressing)

        let mismatch = AlignmentMismatch(expectedWordIndex: 4, expectedWord: "ورتل", recognizedWord: "وزد")
        XCTAssertEqual(reducer.reduce(.strongMismatch(mismatch)).phase, .uncertain)
        XCTAssertEqual(reducer.reduce(.strongMismatch(mismatch)).phase, .correctionNeeded)
    }
}
