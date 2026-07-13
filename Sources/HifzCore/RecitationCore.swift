import Foundation

public struct CTCGreedyDecoder: Sendable {
    public var blankID: Int

    public init(blankID: Int) {
        self.blankID = blankID
    }

    public func decode(tokenIDsByFrame: [Int]) -> [Int] {
        var decoded: [Int] = []
        var previous = blankID

        for token in tokenIDsByFrame {
            if token != previous && token != blankID {
                decoded.append(token)
            }
            previous = token
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
            snapshot.currentWord = completedWordCount + 1
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
