import SQLite3
import XCTest
@testable import HifzCore

final class PageMappingTests: XCTestCase {
    func testLoadsAyahPagesFromKFGQPCV4LayoutRanges() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let qpcURL = root.appending(path: "qpc-v4.db")
        let layoutURL = try makeLayoutDatabase()

        let mapping = try PageMapping.loadKFGQPCV4Layout(layoutDatabaseURL: layoutURL, qpcDatabaseURL: qpcURL)

        XCTAssertEqual(mapping.pageNumber(surah: 1, ayah: 1), 1)
        XCTAssertEqual(mapping.pageNumber(surah: 73, ayah: 4), 574)
    }

    func testLoadsDownloadedKFGQPCV4LayoutAssetWhenPresent() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let qpcURL = root.appending(path: "qpc-v4.db")
        let layoutURL = root.appending(path: "assets/layout/qpc-v4-tajweed-15-lines.db")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: layoutURL.path), "QUL layout DB is not installed locally.")

        let mapping = try PageMapping.loadKFGQPCV4Layout(layoutDatabaseURL: layoutURL, qpcDatabaseURL: qpcURL)

        XCTAssertEqual(mapping.pageNumber(surah: 1, ayah: 1), 1)
        XCTAssertEqual(mapping.pageNumber(surah: 2, ayah: 1), 2)
        XCTAssertEqual(mapping.pageNumber(surah: 73, ayah: 4), 574)
        XCTAssertEqual(mapping.pageNumber(surah: 114, ayah: 6), 604)
    }

    private func makeLayoutDatabase() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "HifzTrackerTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "kfgqpc-v4-layout.sqlite")

        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(url.path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil), SQLITE_OK)
        defer { sqlite3_close(db) }

        try execute(
            """
            create table pages (
              page_number integer,
              line_number integer,
              line_type text,
              is_centered integer,
              first_word_id integer,
              last_word_id integer,
              surah_number integer
            );
            """,
            db: db
        )
        try execute("insert into pages values (1, 1, 'ayah', 0, 1, 4, 1);", db: db)
        try execute("insert into pages values (574, 4, 'ayah', 0, 79572, 79578, 73);", db: db)
        return url
    }

    private func execute(_ sql: String, db: OpaquePointer?) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "unknown sqlite error"
            sqlite3_free(error)
            XCTFail(message)
            return
        }
    }
}
