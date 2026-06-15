import Foundation

public enum SessionHistoryExporter {
    public static func exportJSON(records: [SessionRecord]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(records)
    }
}
