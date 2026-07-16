import Foundation

public struct LiveASRAudioWindow: Equatable, Sendable {
    public var samples: [Float]
    public var sampleRange: Range<Int>

    public init(samples: [Float], sampleRange: Range<Int>) {
        self.samples = samples
        self.sampleRange = sampleRange
    }
}

public struct LiveASRSampleWindow: Sendable {
    public let sampleRate: Int
    public let minimumSampleCount: Int
    public let maximumSampleCount: Int
    public let inferenceIntervalSampleCount: Int

    private var bufferedSamples: [Float]
    private var samplesSinceLastEmission: Int
    private var hasEmitted: Bool
    private var totalSampleCount: Int

    public init(
        sampleRate: Int = 16_000,
        minimumDuration: Double = 1.0,
        maximumDuration: Double = 8.0,
        inferenceInterval: Double = 0.5
    ) {
        let clampedSampleRate = max(1, sampleRate)
        let minimumSamples = max(1, Int((Double(clampedSampleRate) * minimumDuration).rounded()))
        let maximumSamples = max(minimumSamples, Int((Double(clampedSampleRate) * maximumDuration).rounded()))
        let intervalSamples = max(1, Int((Double(clampedSampleRate) * inferenceInterval).rounded()))

        self.sampleRate = clampedSampleRate
        self.minimumSampleCount = minimumSamples
        self.maximumSampleCount = maximumSamples
        self.inferenceIntervalSampleCount = intervalSamples
        self.bufferedSamples = []
        self.samplesSinceLastEmission = 0
        self.hasEmitted = false
        self.totalSampleCount = 0
    }

    public var bufferedSampleCount: Int {
        bufferedSamples.count
    }

    public mutating func append(_ samples: [Float]) -> LiveASRAudioWindow? {
        guard !samples.isEmpty else { return nil }

        bufferedSamples.append(contentsOf: samples)
        samplesSinceLastEmission += samples.count
        totalSampleCount += samples.count

        if bufferedSamples.count > maximumSampleCount {
            bufferedSamples.removeFirst(bufferedSamples.count - maximumSampleCount)
        }

        guard bufferedSamples.count >= minimumSampleCount else {
            return nil
        }

        guard !hasEmitted || samplesSinceLastEmission >= inferenceIntervalSampleCount else {
            return nil
        }

        hasEmitted = true
        samplesSinceLastEmission = 0
        return LiveASRAudioWindow(
            samples: bufferedSamples,
            sampleRange: (totalSampleCount - bufferedSamples.count)..<totalSampleCount
        )
    }

    public mutating func reset() {
        bufferedSamples.removeAll(keepingCapacity: true)
        samplesSinceLastEmission = 0
        hasEmitted = false
        totalSampleCount = 0
    }
}
