import SwiftUI
import HifzCore

struct RecitationWaveformView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var visualState: RecitationVisualState
    var level: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || !visualState.animates)) { timeline in
            Canvas { context, size in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let baseline = baselinePath(size: size)
                let wave = wavePath(size: size, time: time)

                context.stroke(
                    baseline,
                    with: .color(.secondary.opacity(0.14)),
                    lineWidth: 1
                )
                context.stroke(
                    wave,
                    with: .color(visualState.tint.opacity(visualState.waveOpacity)),
                    lineWidth: visualState.lineWidth
                )
            }
        }
        .frame(height: 68)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.quaternary, lineWidth: 0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recitation activity")
        .accessibilityValue(visualState.accessibilityValue)
    }

    private func baselinePath(size: CGSize) -> Path {
        var path = Path()
        let y = size.height * 0.54
        path.move(to: CGPoint(x: 12, y: y))
        path.addLine(to: CGPoint(x: max(12, size.width - 12), y: y))
        return path
    }

    private func wavePath(size: CGSize, time: TimeInterval) -> Path {
        var path = Path()
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let centerY = height * 0.54
        let sampleCount = 72
        let clampedLevel = min(1, max(0, level))
        let amplitude = visualState.amplitude(for: clampedLevel, height: height)

        for index in 0...sampleCount {
            let progress = Double(index) / Double(sampleCount)
            let x = CGFloat(progress) * width
            let primary = sin((progress * visualState.frequency + time * visualState.speed) * Double.pi * 2)
            let secondary = sin((progress * visualState.frequency * 0.48 - time * visualState.speed * 0.62) * Double.pi * 2)
            let y = centerY + CGFloat((primary * 0.74 + secondary * 0.26) * amplitude)
            let point = CGPoint(x: x, y: y)

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }
}

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

    var animates: Bool {
        switch self {
        case .listening, .reciting, .attention:
            true
        case .idle, .paused, .completed, .failed:
            false
        }
    }

    var speed: Double {
        switch self {
        case .listening:
            0.16
        case .reciting:
            0.28
        case .attention:
            0.20
        case .idle, .paused, .completed, .failed:
            0.0
        }
    }

    var frequency: Double {
        switch self {
        case .listening:
            1.45
        case .reciting:
            1.85
        case .attention:
            1.35
        case .idle, .paused, .completed, .failed:
            1.2
        }
    }

    var waveOpacity: Double {
        switch self {
        case .idle, .paused, .failed:
            0.34
        case .listening:
            0.52
        case .reciting:
            0.66
        case .attention:
            0.58
        case .completed:
            0.48
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .idle, .paused, .failed:
            1.4
        case .listening, .completed:
            1.7
        case .reciting, .attention:
            2.0
        }
    }

    var accessibilityValue: String {
        switch self {
        case .idle:
            "Idle"
        case .listening:
            "Listening"
        case .reciting:
            "Actively reciting"
        case .attention:
            "Needs attention"
        case .paused:
            "Paused"
        case .completed:
            "Completed"
        case .failed:
            "Failed"
        }
    }

    func amplitude(for level: Double, height: CGFloat) -> Double {
        switch self {
        case .idle, .failed:
            1.0
        case .listening:
            3.5
        case .reciting:
            4.0 + (Double(height) * 0.18 * level)
        case .attention:
            5.0 + (Double(height) * 0.08 * max(level, 0.25))
        case .paused:
            1.8
        case .completed:
            2.4
        }
    }
}

private extension Array where Element == WordProgress {
    var isVisibleAyahComplete: Bool {
        !isEmpty && allSatisfy { $0.state == .completed }
    }
}
