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

public struct TranscriptPositionLocator: Sendable {
    public var minimumRunLength: Int

    public init(minimumRunLength: Int = 2) {
        self.minimumRunLength = max(1, minimumRunLength)
    }

    public func locate(expected: [RecitationWordReference], recognizedWords: [String]) -> TranscriptLocation? {
        let normalizedExpected = expected.map(\.normalizedText)
        let normalizedRecognized = recognizedWords.map(QuranTextNormalizer.asrComparable)
        var best: Candidate?

        for expectedStart in normalizedExpected.indices {
            for recognizedStart in normalizedRecognized.indices {
                let length = matchingRunLength(
                    expected: normalizedExpected,
                    recognized: normalizedRecognized,
                    expectedStart: expectedStart,
                    recognizedStart: recognizedStart
                )
                guard length >= minimumRunLength else { continue }

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
            completedThrough: expected[expectedEnd - 1],
            matchedWordCount: best.length,
            expectedRange: best.expectedStart..<expectedEnd,
            recognizedRange: best.recognizedStart..<recognizedEnd
        )
    }

    private func matchingRunLength(
        expected: [String],
        recognized: [String],
        expectedStart: Int,
        recognizedStart: Int
    ) -> Int {
        var length = 0
        while expectedStart + length < expected.count,
              recognizedStart + length < recognized.count,
              expected[expectedStart + length] == recognized[recognizedStart + length] {
            length += 1
        }
        return length
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
        if expectedEnd != other.expectedEnd {
            return expectedEnd > other.expectedEnd
        }
        return recognizedEnd > other.recognizedEnd
    }
}
