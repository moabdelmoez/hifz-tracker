import XCTest
@testable import HifzTracker

final class RecitationViewModelTests: XCTestCase {
    @MainActor
    func testDefaultsToBeginningOfSelectedSurah() {
        let viewModel = RecitationViewModel(repository: nil)

        XCTAssertEqual(viewModel.selectedSurah, 73)
        XCTAssertEqual(viewModel.startAyah, 1)
    }
}
