import XCTest
@testable import HifzCore

final class QuranRepositoryTests: XCTestCase {
    func testLoadsWordGlyphsFromBundledQpcDatabase() throws {
        let repo = try makeRepository()

        let words = try repo.words(surah: 73, ayah: 4)

        XCTAssertEqual(words.count, 7)
        XCTAssertEqual(words.first?.location, "73:4:1")
        XCTAssertEqual(words.first?.text, "ﱏ")
        XCTAssertEqual(words.last?.location, "73:4:7")
        XCTAssertEqual(words.last?.text, "ﱕ")
    }

    func testLoadsCanonicalReferenceTextFromTanzil() throws {
        let repo = try makeRepository()

        let text = try repo.referenceText(surah: 1, ayah: 1)

        XCTAssertEqual(text, "بسم الله الرحمن الرحيم")
    }

    func testSurahCatalogHasArabicAndEnglishLabels() {
        let fatihah = SurahCatalog.all.first { $0.number == 1 }
        let muzzammil = SurahCatalog.all.first { $0.number == 73 }

        XCTAssertEqual(fatihah?.arabicName, "الفاتحة")
        XCTAssertEqual(fatihah?.englishName, "Al-Fatihah")
        XCTAssertEqual(muzzammil?.arabicName, "المزمل")
        XCTAssertEqual(muzzammil?.englishName, "Al-Muzzammil")
    }

    private func makeRepository() throws -> SQLiteQuranRepository {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return try SQLiteQuranRepository(
            databaseURL: root.appending(path: "qpc-v4.db"),
            tanzilURL: root.appending(path: "tanzil/quran-simple-clean.txt"),
            pageMapping: .fallback
        )
    }
}
