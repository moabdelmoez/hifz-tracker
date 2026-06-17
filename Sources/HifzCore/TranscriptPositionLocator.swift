import Foundation

public struct RecitationWordReference: Equatable, Sendable {
    public var surah: Int
    public var ayah: Int
    public var wordIndex: Int
    public var text: String

    public init(surah: Int, ayah: Int, wordIndex: Int, text: String) {
        self.surah = surah
        self.ayah = ayah
        self.wordIndex = wordIndex
        self.text = text
    }

    public var location: String {
        "\(surah):\(ayah):\(wordIndex)"
    }

    public var normalizedText: String {
        QuranTextNormalizer.asrComparable(text)
    }
}

public struct TranscriptLocation: Equatable, Sendable {
    public var completedThrough: RecitationWordReference
    public var matchedWordCount: Int
    public var expectedRange: Range<Int>
    public var recognizedRange: Range<Int>

    public init(
        completedThrough: RecitationWordReference,
        matchedWordCount: Int,
        expectedRange: Range<Int>,
        recognizedRange: Range<Int>
    ) {
        self.completedThrough = completedThrough
        self.matchedWordCount = matchedWordCount
        self.expectedRange = expectedRange
        self.recognizedRange = recognizedRange
    }
}

public struct TranscriptPositionIndex: Sendable {
    public let expected: [RecitationWordReference]
    fileprivate let normalizedExpected: [String]
    fileprivate let expectedPositionsByWord: [String: [Int]]

    public init(expected: [RecitationWordReference]) {
        self.expected = expected
        self.normalizedExpected = expected.map(\.normalizedText)

        var positions: [String: [Int]] = [:]
        for (index, word) in normalizedExpected.enumerated() where !word.isEmpty {
            positions[word, default: []].append(index)
        }
        self.expectedPositionsByWord = positions
    }

    public var count: Int {
        expected.count
    }
}

public struct TranscriptPositionLocator: Sendable {
    public var minimumRunLength: Int

    public init(minimumRunLength: Int = 2) {
        self.minimumRunLength = max(1, minimumRunLength)
    }

    public func locate(expected: [RecitationWordReference], recognizedWords: [String]) -> TranscriptLocation? {
        locate(index: TranscriptPositionIndex(expected: expected), recognizedWords: recognizedWords)
    }

    public func locate(
        index: TranscriptPositionIndex,
        recognizedWords: [String],
        expectedRange: Range<Int>? = nil,
        completingAfter minimumCompletedOffset: Int? = nil
    ) -> TranscriptLocation? {
        guard !index.expected.isEmpty, !recognizedWords.isEmpty else { return nil }

        let searchRange = expectedRange ?? 0..<index.count
        guard searchRange.lowerBound >= 0,
              searchRange.upperBound <= index.count,
              !searchRange.isEmpty else {
            return nil
        }

        let normalizedRecognized = recognizedWords.map(QuranTextNormalizer.asrComparable)
        var best: Candidate?

        for recognizedStart in normalizedRecognized.indices {
            let recognizedWord = normalizedRecognized[recognizedStart]
            guard !recognizedWord.isEmpty,
                  let expectedStarts = index.expectedPositionsByWord[recognizedWord] else {
                continue
            }

            for expectedStart in expectedStarts {
                if expectedStart < searchRange.lowerBound {
                    continue
                }
                if expectedStart >= searchRange.upperBound {
                    break
                }

                let length = matchingRunLength(
                    expected: index.normalizedExpected,
                    recognized: normalizedRecognized,
                    expectedStart: expectedStart,
                    recognizedStart: recognizedStart,
                    expectedUpperBound: searchRange.upperBound
                )
                guard length >= minimumRunLength else { continue }
                if let minimumCompletedOffset, expectedStart + length - 1 <= minimumCompletedOffset {
                    continue
                }

                let candidate = Candidate(
                    expectedStart: expectedStart,
                    recognizedStart: recognizedStart,
                    length: length
                )
                if candidate.isBetter(than: best) {
                    best = candidate
                }
            }
        }

        guard let best else { return nil }
        let expectedEnd = best.expectedStart + best.length
        let recognizedEnd = best.recognizedStart + best.length
        return TranscriptLocation(
            completedThrough: index.expected[expectedEnd - 1],
            matchedWordCount: best.length,
            expectedRange: best.expectedStart..<expectedEnd,
            recognizedRange: best.recognizedStart..<recognizedEnd
        )
    }

    private func matchingRunLength(
        expected: [String],
        recognized: [String],
        expectedStart: Int,
        recognizedStart: Int,
        expectedUpperBound: Int
    ) -> Int {
        var length = 0
        while expectedStart + length < expectedUpperBound,
              recognizedStart + length < recognized.count,
              expected[expectedStart + length] == recognized[recognizedStart + length] {
            length += 1
        }
        return length
    }
}

public enum ProvisionalInitialHighlightOutcome: Equatable, Sendable {
    case none
    case candidate(location: TranscriptLocation, consecutiveCount: Int)
    case confirmed(location: TranscriptLocation, consecutiveCount: Int)
    case cleared
}

public struct ProvisionalInitialHighlightTracker: Sendable {
    public var requiredConsecutiveMatches: Int
    public var initialStartLimit: Int
    public var locator: TranscriptPositionLocator

    private var pendingCandidate: CandidateKey?
    private var consecutiveCount: Int

    public init(
        requiredConsecutiveMatches: Int = 2,
        initialStartLimit: Int = 16,
        locator: TranscriptPositionLocator = TranscriptPositionLocator(minimumRunLength: 2)
    ) {
        self.requiredConsecutiveMatches = max(2, requiredConsecutiveMatches)
        self.initialStartLimit = max(1, initialStartLimit)
        self.locator = locator
        self.pendingCandidate = nil
        self.consecutiveCount = 0
    }

    public mutating func evaluate(
        index: TranscriptPositionIndex,
        recognizedWords: [String]
    ) -> ProvisionalInitialHighlightOutcome {
        guard index.count > 0, !recognizedWords.isEmpty else {
            return clearPendingIfNeeded()
        }

        guard let candidate = validCandidate(index: index, recognizedWords: recognizedWords) else {
            return clearPendingIfNeeded()
        }

        if pendingCandidate == candidate.key {
            consecutiveCount += 1
        } else {
            let hadPendingCandidate = pendingCandidate != nil
            pendingCandidate = candidate.key
            consecutiveCount = 1
            if hadPendingCandidate {
                return .cleared
            }
            return .candidate(location: candidate.location, consecutiveCount: consecutiveCount)
        }

        if consecutiveCount >= requiredConsecutiveMatches {
            return .confirmed(location: candidate.location, consecutiveCount: consecutiveCount)
        }
        return .candidate(location: candidate.location, consecutiveCount: consecutiveCount)
    }

    public mutating func reset() {
        pendingCandidate = nil
        consecutiveCount = 0
    }

    private mutating func clearPendingIfNeeded() -> ProvisionalInitialHighlightOutcome {
        guard pendingCandidate != nil else { return .none }
        reset()
        return .cleared
    }

    private func validCandidate(
        index: TranscriptPositionIndex,
        recognizedWords: [String]
    ) -> (location: TranscriptLocation, key: CandidateKey)? {
        let searchUpperBound = min(index.count, initialStartLimit + 2)
        guard searchUpperBound > 0,
              let location = locator.locate(
                index: index,
                recognizedWords: recognizedWords,
                expectedRange: 0..<searchUpperBound
              ),
              location.expectedRange.lowerBound < initialStartLimit,
              location.matchedWordCount == 2,
              location.expectedRange.count == 2 else {
            return nil
        }

        let phrase = Array(index.normalizedExpected[location.expectedRange])
        guard phrase.allSatisfy({ !$0.isEmpty }),
              occurrenceCount(of: phrase, in: index.normalizedExpected) == 1 else {
            return nil
        }

        return (location, CandidateKey(location: location))
    }

    private func occurrenceCount(
        of phrase: [String],
        in expected: [String]
    ) -> Int {
        guard !phrase.isEmpty, phrase.count <= expected.count else { return 0 }

        var count = 0
        for start in 0...(expected.count - phrase.count) {
            var matches = true
            for offset in phrase.indices where expected[start + offset] != phrase[offset] {
                matches = false
                break
            }
            if matches {
                count += 1
                if count > 1 { return count }
            }
        }
        return count
    }

    private struct CandidateKey: Equatable, Sendable {
        var expectedRange: Range<Int>
        var completedSurah: Int
        var completedAyah: Int
        var completedWordIndex: Int
        var completedText: String

        init(location: TranscriptLocation) {
            self.expectedRange = location.expectedRange
            self.completedSurah = location.completedThrough.surah
            self.completedAyah = location.completedThrough.ayah
            self.completedWordIndex = location.completedThrough.wordIndex
            self.completedText = location.completedThrough.text
        }
    }
}

public enum ProgressiveTranscriptLocatorOutcome: Equatable, Sendable {
    case located(TranscriptLocation)
    case emptyReference
    case noMatch
    case initialMatchTooShort(matchedWordCount: Int, requiredWordCount: Int)
    case notAdvancing(completedOffset: Int, acceptedOffset: Int)

    public var reason: String {
        switch self {
        case .located: "progress_applied"
        case .emptyReference: "empty_reference"
        case .noMatch: "no_match"
        case .initialMatchTooShort: "initial_match_too_short"
        case .notAdvancing: "not_advancing"
        }
    }

    public var location: TranscriptLocation? {
        guard case .located(let location) = self else { return nil }
        return location
    }
}

public struct ProgressiveTranscriptLocator: Sendable {
    private static let relaxedInitialMatchLength = 3
    private static let relaxedInitialStartLimit = 32

    public var locator: TranscriptPositionLocator
    public var minimumInitialMatchLength: Int
    public var lookBehindWordCount: Int
    public var lookAheadWordCount: Int

    private var acceptedOffset: Int?

    public init(
        locator: TranscriptPositionLocator = TranscriptPositionLocator(minimumRunLength: 2),
        minimumInitialMatchLength: Int = 4,
        lookBehindWordCount: Int = 12,
        lookAheadWordCount: Int = 96
    ) {
        self.locator = locator
        self.minimumInitialMatchLength = max(locator.minimumRunLength, minimumInitialMatchLength)
        self.lookBehindWordCount = max(0, lookBehindWordCount)
        self.lookAheadWordCount = max(1, lookAheadWordCount)
        self.acceptedOffset = nil
    }

    public mutating func reset() {
        acceptedOffset = nil
    }

    public mutating func locate(
        expected: [RecitationWordReference],
        recognizedWords: [String]
    ) -> TranscriptLocation? {
        locateWithOutcome(expected: expected, recognizedWords: recognizedWords).location
    }

    public mutating func locate(
        index: TranscriptPositionIndex,
        recognizedWords: [String]
    ) -> TranscriptLocation? {
        locateWithOutcome(index: index, recognizedWords: recognizedWords).location
    }

    public mutating func locateWithOutcome(
        expected: [RecitationWordReference],
        recognizedWords: [String]
    ) -> ProgressiveTranscriptLocatorOutcome {
        locateWithOutcome(index: TranscriptPositionIndex(expected: expected), recognizedWords: recognizedWords)
    }

    public mutating func locateWithOutcome(
        index: TranscriptPositionIndex,
        recognizedWords: [String]
    ) -> ProgressiveTranscriptLocatorOutcome {
        guard index.count > 0 else { return .emptyReference }

        let searchRange = expectedSearchRange(totalCount: index.count)
        if let acceptedOffset,
           let advancingLocation = locator.locate(
            index: index,
            recognizedWords: recognizedWords,
            expectedRange: searchRange,
            completingAfter: acceptedOffset
           ) {
            self.acceptedOffset = advancingLocation.expectedRange.upperBound - 1
            return .located(advancingLocation)
        }

        guard let location = locator.locate(
            index: index,
            recognizedWords: recognizedWords,
            expectedRange: searchRange
        ) else {
            return .noMatch
        }

        let completedOffset = location.expectedRange.upperBound - 1

        if acceptedOffset == nil,
           location.matchedWordCount < minimumInitialMatchLength,
           !coversCompleteAyah(location: location, expected: index.expected) {
            guard isGuardedRelaxedInitialMatch(location: location, index: index) else {
                return .initialMatchTooShort(
                    matchedWordCount: location.matchedWordCount,
                    requiredWordCount: minimumInitialMatchLength
                )
            }
        }

        if let acceptedOffset, completedOffset <= acceptedOffset {
            return .notAdvancing(completedOffset: completedOffset, acceptedOffset: acceptedOffset)
        }

        acceptedOffset = completedOffset
        return .located(location)
    }

    private func expectedSearchRange(totalCount: Int) -> Range<Int> {
        guard let acceptedOffset else {
            return 0..<totalCount
        }

        let lowerBound = max(0, acceptedOffset - lookBehindWordCount)
        let upperBound = min(totalCount, acceptedOffset + lookAheadWordCount + 1)
        return lowerBound..<upperBound
    }

    private func coversCompleteAyah(location: TranscriptLocation, expected: [RecitationWordReference]) -> Bool {
        let completed = location.completedThrough
        let matchingIndices = expected.indices.filter { index in
            expected[index].surah == completed.surah && expected[index].ayah == completed.ayah
        }
        guard let firstIndex = matchingIndices.first, let lastIndex = matchingIndices.last else {
            return false
        }

        let ayahRange = firstIndex..<(lastIndex + 1)
        return location.expectedRange.lowerBound <= ayahRange.lowerBound
            && location.expectedRange.upperBound >= ayahRange.upperBound
    }

    private func isGuardedRelaxedInitialMatch(
        location: TranscriptLocation,
        index: TranscriptPositionIndex
    ) -> Bool {
        guard location.matchedWordCount == Self.relaxedInitialMatchLength,
              location.expectedRange.count == Self.relaxedInitialMatchLength,
              location.expectedRange.lowerBound < Self.relaxedInitialStartLimit else {
            return false
        }

        let phrase = Array(index.normalizedExpected[location.expectedRange])
        guard phrase.allSatisfy({ !$0.isEmpty }) else { return false }
        return occurrenceCount(of: phrase, in: index.normalizedExpected) == 1
    }

    private func occurrenceCount(of phrase: [String], in expected: [String]) -> Int {
        guard !phrase.isEmpty, phrase.count <= expected.count else { return 0 }

        var count = 0
        for start in 0...(expected.count - phrase.count) {
            var matches = true
            for offset in phrase.indices where expected[start + offset] != phrase[offset] {
                matches = false
                break
            }
            if matches {
                count += 1
                if count > 1 { return count }
            }
        }
        return count
    }
}

private struct Candidate {
    var expectedStart: Int
    var recognizedStart: Int
    var length: Int

    var expectedEnd: Int {
        expectedStart + length
    }

    var recognizedEnd: Int {
        recognizedStart + length
    }

    func isBetter(than other: Candidate?) -> Bool {
        guard let other else { return true }
        if length != other.length {
            return length > other.length
        }
        if expectedStart != other.expectedStart {
            return expectedStart < other.expectedStart
        }
        return recognizedEnd > other.recognizedEnd
    }
}
