import XCTest
@testable import HifzCore

final class RecitationEngineFacadeTests: XCTestCase {
    func testRecitationEnginePublishesStartAndStopStates() async {
        let engine = RecitationEngine()
        let request = RecitationSessionRequest(surah: 73, startAyah: 4)

        await engine.start(request)
        await engine.stop()
        let snapshots = await engine.snapshots

        XCTAssertEqual(snapshots.map(\.phase), [.requestingPermission, .listening, .locked, .stopped])
        XCTAssertEqual(snapshots.last?.request, request)
    }
}
