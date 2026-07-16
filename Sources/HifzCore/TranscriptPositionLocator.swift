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

public struct TranscriptWordEvidence: Equatable, Sendable {
    public var text: String
    public var sampleRange: Range<Int>

    public init(text: String, sampleRange: Range<Int>) {
        self.text = text
        self.sampleRange = sampleRange
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

    fileprivate func ayahRange(containing offset: Int) -> Range<Int>? {
        guard expected.indices.contains(offset) else { return nil }
        let word = expected[offset]
        let lowerBound = expected[..<offset].lastIndex {
            $0.surah != word.surah || $0.ayah != word.ayah
        }.map { $0 + 1 } ?? 0
        let upperBound = expected[(offset + 1)...].firstIndex {
            $0.surah != word.surah || $0.ayah != word.ayah
        } ?? count
        return lowerBound..<upperBound
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
        let searchUpperBound = min(index.ayahRange(containing: 0)?.upperBound ?? 0, initialStartLimit + 2)
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
    case initialMatchTooFar(matchedWordCount: Int, startOffset: Int, allowedStartOffset: Int)
    case notAdvancing(completedOffset: Int, acceptedOffset: Int)
    case freshEvidenceRequired

    public var reason: String {
        switch self {
        case .located: "progress_applied"
        case .emptyReference: "empty_reference"
        case .noMatch: "no_match"
        case .initialMatchTooShort: "initial_match_too_short"
        case .initialMatchTooFar: "initial_match_too_far"
        case .notAdvancing: "not_advancing"
        case .freshEvidenceRequired: "fresh_evidence_required"
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
    private static let completeShortAyahInitialStartLimit = 16
    private static let initialMatchStartLimit = 32

    public var locator: TranscriptPositionLocator
    public var minimumInitialMatchLength: Int
    public var lookBehindWordCount: Int
    public var lookAheadWordCount: Int

    private var acceptedOffset: Int?
    private var freshEvidenceBoundary: Int?

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
        self.freshEvidenceBoundary = nil
    }

    public mutating func reset() {
        acceptedOffset = nil
        freshEvidenceBoundary = nil
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

    public mutating func locate(
        expected: [RecitationWordReference],
        evidence: [TranscriptWordEvidence]
    ) -> TranscriptLocation? {
        locateWithOutcome(expected: expected, evidence: evidence).location
    }

    public mutating func locate(
        index: TranscriptPositionIndex,
        evidence: [TranscriptWordEvidence]
    ) -> TranscriptLocation? {
        locateWithOutcome(index: index, evidence: evidence).location
    }

    public mutating func locateWithOutcome(
        expected: [RecitationWordReference],
        evidence: [TranscriptWordEvidence]
    ) -> ProgressiveTranscriptLocatorOutcome {
        locateWithOutcome(index: TranscriptPositionIndex(expected: expected), evidence: evidence)
    }

    public mutating func locateWithOutcome(
        index: TranscriptPositionIndex,
        evidence: [TranscriptWordEvidence]
    ) -> ProgressiveTranscriptLocatorOutcome {
        let eligibleEvidence: [TranscriptWordEvidence]
        if let freshEvidenceBoundary {
            eligibleEvidence = evidence.filter { $0.sampleRange.lowerBound >= freshEvidenceBoundary }
            guard !eligibleEvidence.isEmpty else { return .freshEvidenceRequired }
        } else {
            eligibleEvidence = evidence
        }

        let outcome = locateWithOutcome(
            index: index,
            recognizedWords: eligibleEvidence.map(\.text)
        )
        guard case .located(let location) = outcome,
              let ayahRange = index.ayahRange(containing: location.expectedRange.upperBound - 1),
              location.expectedRange.upperBound == ayahRange.upperBound,
              eligibleEvidence.indices.contains(location.recognizedRange.upperBound - 1) else {
            return outcome
        }

        freshEvidenceBoundary = eligibleEvidence[location.recognizedRange.upperBound - 1].sampleRange.upperBound
        return outcome
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

        let searchRange = expectedSearchRange(index: index)
        if acceptedOffset == nil,
           searchRange.upperBound < index.count,
           let unrestrictedLocation = locator.locate(index: index, recognizedWords: recognizedWords),
           unrestrictedLocation.expectedRange.lowerBound >= searchRange.upperBound {
            return .initialMatchTooFar(
                matchedWordCount: unrestrictedLocation.matchedWordCount,
                startOffset: unrestrictedLocation.expectedRange.lowerBound,
                allowedStartOffset: searchRange.upperBound - 1
            )
        }

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

        if let acceptedOffset,
           let gappedLocation = locateAdvancingAcrossSingleGap(
            index: index,
            recognizedWords: recognizedWords,
            searchRange: searchRange,
            acceptedOffset: acceptedOffset
           ) {
            self.acceptedOffset = gappedLocation.expectedRange.upperBound - 1
            return .located(gappedLocation)
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
           location.expectedRange.lowerBound >= Self.initialMatchStartLimit {
            return .initialMatchTooFar(
                matchedWordCount: location.matchedWordCount,
                startOffset: location.expectedRange.lowerBound,
                allowedStartOffset: Self.initialMatchStartLimit - 1
            )
        }

        if acceptedOffset == nil,
           location.matchedWordCount < minimumInitialMatchLength,
           !isAllowedShortInitialMatch(location: location, index: index) {
            return .initialMatchTooShort(
                matchedWordCount: location.matchedWordCount,
                requiredWordCount: minimumInitialMatchLength
            )
        }

        if let acceptedOffset, completedOffset <= acceptedOffset {
            return .notAdvancing(completedOffset: completedOffset, acceptedOffset: acceptedOffset)
        }

        acceptedOffset = completedOffset
        return .located(location)
    }

    private func isAllowedShortInitialMatch(
        location: TranscriptLocation,
        index: TranscriptPositionIndex
    ) -> Bool {
        if coversCompleteAyah(location: location, expected: index.expected) {
            return location.expectedRange.lowerBound < Self.completeShortAyahInitialStartLimit
        }

        return isGuardedRelaxedInitialMatch(location: location, index: index)
    }

    private func expectedSearchRange(index: TranscriptPositionIndex) -> Range<Int> {
        guard let acceptedOffset else {
            return index.ayahRange(containing: 0) ?? 0..<0
        }
        guard let currentAyah = index.ayahRange(containing: acceptedOffset) else { return 0..<0 }
        if acceptedOffset < currentAyah.upperBound - 1 {
            let lowerBound = max(currentAyah.lowerBound, acceptedOffset - lookBehindWordCount)
            let upperBound = min(currentAyah.upperBound, acceptedOffset + lookAheadWordCount + 1)
            return lowerBound..<upperBound
        }
        guard let nextAyah = index.ayahRange(containing: currentAyah.upperBound) else {
            return index.count..<index.count
        }
        return nextAyah.lowerBound..<min(nextAyah.upperBound, acceptedOffset + lookAheadWordCount + 1)
    }

    private func locateAdvancingAcrossSingleGap(
        index: TranscriptPositionIndex,
        recognizedWords: [String],
        searchRange: Range<Int>,
        acceptedOffset: Int
    ) -> TranscriptLocation? {
        let normalizedRecognized = recognizedWords.map(QuranTextNormalizer.asrComparable)
        var best: GappedCandidate?

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

                let prefixLength = matchingRunLength(
                    expected: index.normalizedExpected,
                    recognized: normalizedRecognized,
                    expectedStart: expectedStart,
                    recognizedStart: recognizedStart,
                    expectedUpperBound: searchRange.upperBound
                )
                guard prefixLength >= locator.minimumRunLength else { continue }

                let expectedGap = expectedStart + prefixLength
                let recognizedGap = recognizedStart + prefixLength
                guard expectedGap == acceptedOffset + 1,
                      expectedGap < searchRange.upperBound,
                      recognizedGap < normalizedRecognized.count else {
                    continue
                }

                let suffixExpectedStart = expectedGap + 1
                let suffixRecognizedStart = recognizedGap + 1
                guard suffixExpectedStart < searchRange.upperBound,
                      suffixRecognizedStart < normalizedRecognized.count else {
                    continue
                }

                let suffixLength = matchingRunLength(
                    expected: index.normalizedExpected,
                    recognized: normalizedRecognized,
                    expectedStart: suffixExpectedStart,
                    recognizedStart: suffixRecognizedStart,
                    expectedUpperBound: searchRange.upperBound
                )
                guard suffixLength > 0 else { continue }

                let expectedEnd = suffixExpectedStart + suffixLength
                guard isSingleGapWithinSameAyah(
                    index: index,
                    gapOffset: expectedGap,
                    completedOffset: expectedEnd - 1,
                    acceptedOffset: acceptedOffset
                ) else {
                    continue
                }

                let candidate = GappedCandidate(
                    expectedStart: expectedStart,
                    recognizedStart: recognizedStart,
                    expectedEnd: expectedEnd,
                    recognizedEnd: suffixRecognizedStart + suffixLength,
                    matchedWordCount: prefixLength + suffixLength
                )
                if candidate.isBetter(than: best) {
                    best = candidate
                }
            }
        }

        guard let best else { return nil }
        return TranscriptLocation(
            completedThrough: index.expected[best.expectedEnd - 1],
            matchedWordCount: best.matchedWordCount,
            expectedRange: best.expectedStart..<best.expectedEnd,
            recognizedRange: best.recognizedStart..<best.recognizedEnd
        )
    }

    private func isSingleGapWithinSameAyah(
        index: TranscriptPositionIndex,
        gapOffset: Int,
        completedOffset: Int,
        acceptedOffset: Int
    ) -> Bool {
        guard index.expected.indices.contains(acceptedOffset),
              index.expected.indices.contains(gapOffset),
              index.expected.indices.contains(completedOffset) else {
            return false
        }

        let accepted = index.expected[acceptedOffset]
        let gap = index.expected[gapOffset]
        let completed = index.expected[completedOffset]
        return accepted.surah == gap.surah
            && accepted.ayah == gap.ayah
            && gap.surah == completed.surah
            && gap.ayah == completed.ayah
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

private struct GappedCandidate {
    var expectedStart: Int
    var recognizedStart: Int
    var expectedEnd: Int
    var recognizedEnd: Int
    var matchedWordCount: Int

    func isBetter(than other: GappedCandidate?) -> Bool {
        guard let other else { return true }
        if expectedEnd != other.expectedEnd {
            return expectedEnd > other.expectedEnd
        }
        if matchedWordCount != other.matchedWordCount {
            return matchedWordCount > other.matchedWordCount
        }
        if expectedStart != other.expectedStart {
            return expectedStart < other.expectedStart
        }
        return recognizedEnd > other.recognizedEnd
    }
}
