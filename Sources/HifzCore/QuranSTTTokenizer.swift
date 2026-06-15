import Foundation

public struct QuranSTTTokenizer: Sendable {
    private let tokensByID: [Int: String]
    public let blankID: Int

    public var vocabularySize: Int {
        tokensByID.count
    }

    public init(tokensURL: URL) throws {
        let tokenFile = try String(contentsOf: tokensURL, encoding: .utf8)
        try self.init(tokenFile: tokenFile)
    }

    public init(tokenFile: String) throws {
        var parsedTokens: [Int: String] = [:]

        for rawLine in tokenFile.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            guard let separator = line.lastIndex(of: " ") else {
                throw QuranSTTTokenizerError.invalidTokenLine(line)
            }

            let token = String(line[..<separator])
            let idText = line[line.index(after: separator)...]
            guard let id = Int(idText) else {
                throw QuranSTTTokenizerError.invalidTokenLine(line)
            }
            guard parsedTokens[id] == nil else {
                throw QuranSTTTokenizerError.duplicateTokenID(id)
            }

            parsedTokens[id] = token
        }

        guard let blankID = parsedTokens.first(where: { $0.value == "<blk>" })?.key else {
            throw QuranSTTTokenizerError.missingBlankToken
        }

        self.tokensByID = parsedTokens
        self.blankID = blankID
    }

    public func token(for id: Int) -> String? {
        tokensByID[id]
    }

    public func decode(tokenIDs: [Int]) throws -> String {
        var text = ""

        for id in tokenIDs {
            guard let token = tokensByID[id] else {
                throw QuranSTTTokenizerError.unknownTokenID(id)
            }
            guard token != "<blk>" else { continue }

            text += token.replacingOccurrences(of: "▁", with: " ")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum QuranSTTTokenizerError: Error, Equatable {
    case invalidTokenLine(String)
    case duplicateTokenID(Int)
    case missingBlankToken
    case unknownTokenID(Int)
}
