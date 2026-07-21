import Foundation

public struct CTCDecodedToken: Equatable, Sendable {
    public var tokenID: Int
    public var timeStepRange: Range<Int>

    public init(tokenID: Int, timeStepRange: Range<Int>) {
        self.tokenID = tokenID
        self.timeStepRange = timeStepRange
    }
}

public struct CTCGreedyDecoder: Sendable {
    public var blankID: Int

    public init(blankID: Int) {
        self.blankID = blankID
    }

    public func decode(tokenIDsByFrame: [Int]) -> [Int] {
        decodeTimed(tokenIDsByFrame: tokenIDsByFrame).map(\.tokenID)
    }

    public func decodeTimed(tokenIDsByFrame: [Int]) -> [CTCDecodedToken] {
        var decoded: [CTCDecodedToken] = []
        var previous = blankID
        var tokenStart = 0

        for (timeStep, token) in tokenIDsByFrame.enumerated() where token != previous {
            if previous != blankID {
                decoded.append(CTCDecodedToken(
                    tokenID: previous,
                    timeStepRange: tokenStart..<timeStep
                ))
            }
            if token != blankID {
                tokenStart = timeStep
            }
            previous = token
        }

        if previous != blankID {
            decoded.append(CTCDecodedToken(
                tokenID: previous,
                timeStepRange: tokenStart..<tokenIDsByFrame.count
            ))
        }

        return decoded
    }
}

public struct CorrectionGate: Sendable {
    public var requiredStableChunks: Int
    private var lastMismatch: AlignmentMismatch?
    private var stableCount: Int

    public init(requiredStableChunks: Int) {
        self.requiredStableChunks = max(1, requiredStableChunks)
        self.lastMismatch = nil
        self.stableCount = 0
    }

    public mutating func observe(mismatch: AlignmentMismatch) -> CorrectionEvent? {
        if mismatch == lastMismatch {
            stableCount += 1
        } else {
            lastMismatch = mismatch
            stableCount = 1
        }

        guard stableCount >= requiredStableChunks else {
            return nil
        }

        return CorrectionEvent(
            expectedWordIndex: mismatch.expectedWordIndex,
            expectedWord: mismatch.expectedWord,
            recognizedWord: mismatch.recognizedWord
        )
    }
}

public struct RecitationStateReducer: Sendable {
    private var snapshot: RecitationSnapshot
    private var correctionGate: CorrectionGate

    public init(snapshot: RecitationSnapshot = RecitationSnapshot(), correctionGate: CorrectionGate = CorrectionGate(requiredStableChunks: 2)) {
        self.snapshot = snapshot
        self.correctionGate = correctionGate
    }

    @discardableResult
    public mutating func reduce(_ action: RecitationAction) -> RecitationSnapshot {
        switch action {
        case let .startRequested(request):
            snapshot = RecitationSnapshot(phase: .requestingPermission, request: request)
        case .permissionGranted:
            snapshot.phase = .listening
        case .permissionDenied:
            snapshot.phase = .failed
            snapshot.message = "Microphone permission was denied."
        case .findingPlace:
            snapshot.phase = .findingPlace
        case let .placeLocked(ayah, word):
            snapshot.phase = .locked
            snapshot.currentAyah = ayah
            snapshot.currentWord = word
        case let .progressAdvanced(ayah, completedWordCount):
            snapshot.phase = .progressing
            snapshot.currentAyah = ayah
            snapshot.completedWordCount = completedWordCount
            snapshot.currentWord = completedWordCount
        case let .strongMismatch(mismatch):
            if let event = correctionGate.observe(mismatch: mismatch) {
                snapshot.phase = .correctionNeeded
                snapshot.correctionEvents.append(event)
            } else {
                snapshot.phase = .uncertain
            }
        case .stop:
            snapshot.phase = .stopped
        case let .fail(message):
            snapshot.phase = .failed
            snapshot.message = message
        }
        return snapshot
    }
}
