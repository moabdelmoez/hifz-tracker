import Foundation

public struct QuranWord: Equatable, Sendable, Identifiable {
    public var id: Int
    public var location: String
    public var surah: Int
    public var ayah: Int
    public var wordIndex: Int
    public var text: String

    public init(id: Int, location: String, surah: Int, ayah: Int, wordIndex: Int, text: String) {
        self.id = id
        self.location = location
        self.surah = surah
        self.ayah = ayah
        self.wordIndex = wordIndex
        self.text = text
    }
}

public struct SurahInfo: Equatable, Sendable, Identifiable {
    public var id: Int { number }
    public var number: Int
    public var arabicName: String
    public var englishName: String
    public var ayahCount: Int

    public init(number: Int, arabicName: String, englishName: String, ayahCount: Int) {
        self.number = number
        self.arabicName = arabicName
        self.englishName = englishName
        self.ayahCount = ayahCount
    }
}

public struct PageMapping: Equatable, Sendable {
    public var entries: [String: Int]
    public var wordEntries: [String: Int]

    public init(entries: [String: Int], wordEntries: [String: Int] = [:]) {
        self.entries = entries
        self.wordEntries = wordEntries
    }

    public static let fallback = PageMapping(entries: [:])

    public func pageNumber(surah: Int, ayah: Int) -> Int {
        entries["\(surah):\(ayah)"] ?? max(1, min(604, surah))
    }

    public func pageNumber(surah: Int, ayah: Int, wordIndex: Int) -> Int? {
        wordEntries["\(surah):\(ayah):\(wordIndex)"]
    }
}

public enum MushafPageLineType: String, Codable, Equatable, Sendable {
    case ayah
    case surahName = "surah_name"
    case basmallah
    case unknown

    public init(layoutValue: String) {
        self = MushafPageLineType(rawValue: layoutValue) ?? .unknown
    }
}

public struct MushafPageLine: Equatable, Sendable, Identifiable {
    public var id: Int { lineNumber }
    public var pageNumber: Int
    public var lineNumber: Int
    public var lineType: MushafPageLineType
    public var isCentered: Bool
    public var firstWordID: Int?
    public var lastWordID: Int?
    public var surahNumber: Int?
    public var words: [QuranWord]

    public init(
        pageNumber: Int,
        lineNumber: Int,
        lineType: MushafPageLineType,
        isCentered: Bool,
        firstWordID: Int?,
        lastWordID: Int?,
        surahNumber: Int?,
        words: [QuranWord]
    ) {
        self.pageNumber = pageNumber
        self.lineNumber = lineNumber
        self.lineType = lineType
        self.isCentered = isCentered
        self.firstWordID = firstWordID
        self.lastWordID = lastWordID
        self.surahNumber = surahNumber
        self.words = words
    }
}

public struct MushafPage: Equatable, Sendable, Identifiable {
    public var id: Int { pageNumber }
    public var pageNumber: Int
    public var lines: [MushafPageLine]

    public init(pageNumber: Int, lines: [MushafPageLine]) {
        self.pageNumber = pageNumber
        self.lines = lines
    }
}

public struct RecitationSessionRequest: Equatable, Sendable {
    public var surah: Int
    public var startAyah: Int

    public init(surah: Int, startAyah: Int) {
        self.surah = surah
        self.startAyah = startAyah
    }
}

public enum RecitationPhase: String, Codable, Equatable, Sendable, CaseIterable {
    case idle
    case requestingPermission
    case listening
    case findingPlace
    case locked
    case progressing
    case correctionNeeded
    case uncertain
    case stopped
    case failed
}

public enum WordProgressState: String, Codable, Equatable, Sendable {
    case pending
    case current
    case provisional
    case completed
    case uncertain
    case correctionNeeded
}

public struct WordProgress: Codable, Equatable, Sendable, Identifiable {
    public var id: Int { wordIndex }
    public var wordIndex: Int
    public var text: String
    public var state: WordProgressState

    public init(wordIndex: Int, text: String, state: WordProgressState) {
        self.wordIndex = wordIndex
        self.text = text
        self.state = state
    }
}

public struct AlignmentMismatch: Codable, Equatable, Sendable {
    public var expectedWordIndex: Int
    public var expectedWord: String
    public var recognizedWord: String

    public init(expectedWordIndex: Int, expectedWord: String, recognizedWord: String) {
        self.expectedWordIndex = expectedWordIndex
        self.expectedWord = expectedWord
        self.recognizedWord = recognizedWord
    }
}

public struct CorrectionEvent: Codable, Equatable, Sendable {
    public var expectedWordIndex: Int
    public var expectedWord: String
    public var recognizedWord: String

    public init(expectedWordIndex: Int, expectedWord: String, recognizedWord: String) {
        self.expectedWordIndex = expectedWordIndex
        self.expectedWord = expectedWord
        self.recognizedWord = recognizedWord
    }
}

public struct RecitationSnapshot: Equatable, Sendable {
    public var phase: RecitationPhase
    public var request: RecitationSessionRequest?
    public var currentAyah: Int?
    public var currentWord: Int?
    public var completedWordCount: Int
    public var correctionEvents: [CorrectionEvent]
    public var message: String?

    public init(
        phase: RecitationPhase = .idle,
        request: RecitationSessionRequest? = nil,
        currentAyah: Int? = nil,
        currentWord: Int? = nil,
        completedWordCount: Int = 0,
        correctionEvents: [CorrectionEvent] = [],
        message: String? = nil
    ) {
        self.phase = phase
        self.request = request
        self.currentAyah = currentAyah
        self.currentWord = currentWord
        self.completedWordCount = completedWordCount
        self.correctionEvents = correctionEvents
        self.message = message
    }
}

public enum RecitationAction: Equatable, Sendable {
    case startRequested(RecitationSessionRequest)
    case permissionGranted
    case permissionDenied
    case findingPlace
    case placeLocked(ayah: Int, word: Int)
    case progressAdvanced(ayah: Int, completedWordCount: Int)
    case strongMismatch(AlignmentMismatch)
    case stop
    case fail(String)
}

public struct SessionRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var surah: Int
    public var startAyah: Int
    public var lastSurah: Int
    public var lastAyah: Int
    public var lastWord: Int
    public var completedWordCount: Int
    public var correctionEvents: [CorrectionEvent]

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date?,
        surah: Int,
        startAyah: Int,
        lastSurah: Int? = nil,
        lastAyah: Int,
        lastWord: Int,
        completedWordCount: Int,
        correctionEvents: [CorrectionEvent]
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.surah = surah
        self.startAyah = startAyah
        self.lastSurah = lastSurah ?? surah
        self.lastAyah = lastAyah
        self.lastWord = lastWord
        self.completedWordCount = completedWordCount
        self.correctionEvents = correctionEvents
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case startedAt
        case endedAt
        case surah
        case startAyah
        case lastSurah
        case lastAyah
        case lastWord
        case completedWordCount
        case correctionEvents
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        self.surah = try container.decode(Int.self, forKey: .surah)
        self.startAyah = try container.decode(Int.self, forKey: .startAyah)
        self.lastSurah = try container.decodeIfPresent(Int.self, forKey: .lastSurah) ?? surah
        self.lastAyah = try container.decode(Int.self, forKey: .lastAyah)
        self.lastWord = try container.decode(Int.self, forKey: .lastWord)
        self.completedWordCount = try container.decode(Int.self, forKey: .completedWordCount)
        self.correctionEvents = try container.decode([CorrectionEvent].self, forKey: .correctionEvents)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(endedAt, forKey: .endedAt)
        try container.encode(surah, forKey: .surah)
        try container.encode(startAyah, forKey: .startAyah)
        try container.encode(lastSurah, forKey: .lastSurah)
        try container.encode(lastAyah, forKey: .lastAyah)
        try container.encode(lastWord, forKey: .lastWord)
        try container.encode(completedWordCount, forKey: .completedWordCount)
        try container.encode(correctionEvents, forKey: .correctionEvents)
    }
}
