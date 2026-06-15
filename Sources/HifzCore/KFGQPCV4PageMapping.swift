import Foundation
import SQLite3

public enum PageMappingError: Error, Equatable {
    case openDatabase(String)
    case prepareStatement(String)
}

extension PageMapping {
    public static func loadKFGQPCV4Layout(layoutDatabaseURL: URL, qpcDatabaseURL: URL) throws -> PageMapping {
        let wordKeys = try loadWordKeys(databaseURL: qpcDatabaseURL)
        var entries: [String: Int] = [:]
        var db: OpaquePointer?
        let result = sqlite3_open_v2(layoutDatabaseURL.path, &db, SQLITE_OPEN_READONLY, nil)
        guard result == SQLITE_OK else {
            let message = db.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "unknown"
            sqlite3_close(db)
            throw PageMappingError.openDatabase(message)
        }
        defer { sqlite3_close(db) }

        let sql = """
        select page_number, first_word_id, last_word_id
        from pages
        where line_type = 'ayah'
          and first_word_id is not null
          and last_word_id is not null
        order by page_number, line_number
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw PageMappingError.prepareStatement(errorMessage(db))
        }
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            let pageNumber = Int(sqlite3_column_int(statement, 0))
            let firstWordID = Int(sqlite3_column_int(statement, 1))
            let lastWordID = Int(sqlite3_column_int(statement, 2))
            guard firstWordID <= lastWordID else { continue }
            for wordID in firstWordID...lastWordID {
                guard let key = wordKeys[wordID] else { continue }
                entries[key] = entries[key] ?? pageNumber
            }
        }

        return PageMapping(entries: entries)
    }

    private static func loadWordKeys(databaseURL: URL) throws -> [Int: String] {
        var db: OpaquePointer?
        let result = sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY, nil)
        guard result == SQLITE_OK else {
            let message = db.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "unknown"
            sqlite3_close(db)
            throw PageMappingError.openDatabase(message)
        }
        defer { sqlite3_close(db) }

        let sql = "select id, surah, ayah from words order by id"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw PageMappingError.prepareStatement(errorMessage(db))
        }
        defer { sqlite3_finalize(statement) }

        var keys: [Int: String] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            let wordID = Int(sqlite3_column_int(statement, 0))
            let surah = Int(sqlite3_column_int(statement, 1))
            let ayah = Int(sqlite3_column_int(statement, 2))
            keys[wordID] = "\(surah):\(ayah)"
        }
        return keys
    }

    private static func errorMessage(_ db: OpaquePointer?) -> String {
        db.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "unknown"
    }
}
