import Foundation

struct AudioLevelMeter: Sendable {
    private(set) var level = 0.0

    mutating func update(with samples: [Float]) -> Double {
        let target = Self.normalizedRMS(samples)
        let coefficient = target > level ? 0.72 : 0.18
        level += (target - level) * coefficient

        if level < 0.001 {
            level = 0
        }
        return level
    }

    mutating func reset() {
        level = 0
    }

    private static func normalizedRMS(_ samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 0 }

        let squareSum = samples.reduce(0.0) { partialResult, sample in
            let clamped = min(1.0, max(-1.0, Double(sample)))
            return partialResult + (clamped * clamped)
        }
        let rms = sqrt(squareSum / Double(samples.count))
        return min(1, rms * 1.35)
    }
}
