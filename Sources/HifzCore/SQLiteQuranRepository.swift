import Foundation
import SQLite3

public protocol QuranRepository {
    func words(surah: Int, ayah: Int) throws -> [QuranWord]
    func referenceText(surah: Int, ayah: Int) throws -> String
    func pageNumber(surah: Int, ayah: Int) -> Int
    func pageNumber(surah: Int, ayah: Int, wordIndex: Int) -> Int?
    func mushafPage(pageNumber: Int) throws -> MushafPage
}

public extension QuranRepository {
    func pageNumber(surah: Int, ayah: Int, wordIndex: Int) -> Int? {
        nil
    }
}

public enum QuranRepositoryError: Error, Equatable {
    case openDatabase(String)
    case prepareStatement(String)
    case missingReference(surah: Int, ayah: Int)
    case missingLayoutDatabase
}

public final class SQLiteQuranRepository: QuranRepository {
    private var db: OpaquePointer?
    private var layoutDB: OpaquePointer?
    private let referenceTextByKey: [String: String]
    private let pageMapping: PageMapping

    public init(databaseURL: URL, tanzilURL: URL, pageMapping: PageMapping, layoutDatabaseURL: URL? = nil) throws {
        self.referenceTextByKey = try Self.loadTanzil(url: tanzilURL)
        self.pageMapping = pageMapping

        let result = sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY, nil)
        guard result == SQLITE_OK else {
            let message = db.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "unknown"
            throw QuranRepositoryError.openDatabase(message)
        }

        if let layoutDatabaseURL {
            let layoutResult = sqlite3_open_v2(layoutDatabaseURL.path, &layoutDB, SQLITE_OPEN_READONLY, nil)
            guard layoutResult == SQLITE_OK else {
                let message = layoutDB.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "unknown"
                throw QuranRepositoryError.openDatabase(message)
            }
        }
    }

    deinit {
        sqlite3_close(db)
        sqlite3_close(layoutDB)
    }

    public func words(surah: Int, ayah: Int) throws -> [QuranWord] {
        let sql = "select id, location, surah, ayah, word, text from words where surah = ? and ayah = ? order by word"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw QuranRepositoryError.prepareStatement(errorMessage)
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(surah))
        sqlite3_bind_int(statement, 2, Int32(ayah))

        var rows: [QuranWord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            let location = String(cString: sqlite3_column_text(statement, 1))
            let rowSurah = Int(sqlite3_column_int(statement, 2))
            let rowAyah = Int(sqlite3_column_int(statement, 3))
            let word = Int(sqlite3_column_int(statement, 4))
            let text = String(cString: sqlite3_column_text(statement, 5))
            rows.append(QuranWord(id: id, location: location, surah: rowSurah, ayah: rowAyah, wordIndex: word, text: text))
        }
        return rows
    }

    public func referenceText(surah: Int, ayah: Int) throws -> String {
        guard let text = referenceTextByKey["\(surah):\(ayah)"] else {
            throw QuranRepositoryError.missingReference(surah: surah, ayah: ayah)
        }
        return text
    }

    public func pageNumber(surah: Int, ayah: Int) -> Int {
        pageMapping.pageNumber(surah: surah, ayah: ayah)
    }

    public func pageNumber(surah: Int, ayah: Int, wordIndex: Int) -> Int? {
        pageMapping.pageNumber(surah: surah, ayah: ayah, wordIndex: wordIndex)
    }

    public func mushafPage(pageNumber: Int) throws -> MushafPage {
        guard let layoutDB else {
            throw QuranRepositoryError.missingLayoutDatabase
        }

        let sql = """
        select page_number, line_number, line_type, is_centered, first_word_id, last_word_id, surah_number
        from pages
        where page_number = ?
        order by line_number
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(layoutDB, sql, -1, &statement, nil) == SQLITE_OK else {
            throw QuranRepositoryError.prepareStatement(layoutErrorMessage)
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(pageNumber))

        var lines: [MushafPageLine] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let rowPageNumber = Int(sqlite3_column_int(statement, 0))
            let lineNumber = Int(sqlite3_column_int(statement, 1))
            let lineTypeText = String(cString: sqlite3_column_text(statement, 2))
            let firstWordID = optionalInt(statement, 4)
            let lastWordID = optionalInt(statement, 5)
            let lineType = MushafPageLineType(layoutValue: lineTypeText)
            let lineWords: [QuranWord]
            if lineType == .ayah, let firstWordID, let lastWordID {
                lineWords = try words(firstWordID: firstWordID, lastWordID: lastWordID)
            } else {
                lineWords = []
            }

            lines.append(MushafPageLine(
                pageNumber: rowPageNumber,
                lineNumber: lineNumber,
                lineType: lineType,
                isCentered: sqlite3_column_int(statement, 3) != 0,
                firstWordID: firstWordID,
                lastWordID: lastWordID,
                surahNumber: optionalInt(statement, 6),
                words: lineWords
            ))
        }

        return MushafPage(pageNumber: pageNumber, lines: lines)
    }

    private var errorMessage: String {
        db.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "unknown"
    }

    private var layoutErrorMessage: String {
        layoutDB.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "unknown"
    }

    private func words(firstWordID: Int, lastWordID: Int) throws -> [QuranWord] {
        let sql = "select id, location, surah, ayah, word, text from words where id between ? and ? order by id"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw QuranRepositoryError.prepareStatement(errorMessage)
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(firstWordID))
        sqlite3_bind_int(statement, 2, Int32(lastWordID))

        var rows: [QuranWord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            let location = String(cString: sqlite3_column_text(statement, 1))
            let rowSurah = Int(sqlite3_column_int(statement, 2))
            let rowAyah = Int(sqlite3_column_int(statement, 3))
            let word = Int(sqlite3_column_int(statement, 4))
            let text = String(cString: sqlite3_column_text(statement, 5))
            rows.append(QuranWord(id: id, location: location, surah: rowSurah, ayah: rowAyah, wordIndex: word, text: text))
        }
        return rows
    }

    private func optionalInt(_ statement: OpaquePointer?, _ column: Int32) -> Int? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int(statement, column))
    }

    private static func loadTanzil(url: URL) throws -> [String: String] {
        let data = try String(contentsOf: url, encoding: .utf8)
        var result: [String: String] = [:]
        for line in data.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count == 3 else { continue }
            result["\(parts[0]):\(parts[1])"] = String(parts[2])
        }
        return result
    }
}
