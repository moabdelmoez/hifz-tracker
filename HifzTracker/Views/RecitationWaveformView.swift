import SwiftUI
import HifzCore

enum RecitationVisualState: Equatable {
    case idle
    case listening
    case reciting
    case attention
    case paused
    case completed
    case failed

    init(phase: RecitationPhase, wordProgress: [WordProgress]) {
        switch phase {
        case .idle:
            self = .idle
        case .requestingPermission, .listening, .findingPlace:
            self = .listening
        case .locked, .progressing:
            self = .reciting
        case .uncertain, .correctionNeeded:
            self = .attention
        case .stopped:
            self = wordProgress.isVisibleAyahComplete ? .completed : .paused
        case .failed:
            self = .failed
        }
    }

    var tint: Color {
        switch self {
        case .idle, .paused:
            .secondary
        case .listening:
            .blue
        case .reciting:
            .green
        case .attention:
            .orange
        case .completed:
            .mint
        case .failed:
            .red
        }
    }

}

private extension Array where Element == WordProgress {
    var isVisibleAyahComplete: Bool {
        !isEmpty && allSatisfy { $0.state == .completed }
    }
}
