import Foundation

public struct LogMelFeatures: Equatable, Sendable {
    public var values: [Float]
    public var featureCount: Int
    public var frameCount: Int

    public init(values: [Float], featureCount: Int, frameCount: Int) {
        self.values = values
        self.featureCount = featureCount
        self.frameCount = frameCount
    }
}

public struct LogMelFeatureExtractor: Sendable {
    public var sampleRate: Int
    public var windowLength: Int
    public var hopLength: Int
    public var fftSize: Int
    public var featureCount: Int

    private let hannWindow: [Float]
    private let cosineTable: [Float]
    private let sineTable: [Float]
    private let melFilterBank: [Float]

    public init(
        sampleRate: Int = 16_000,
        windowSize: Double = 0.025,
        windowStride: Double = 0.010,
        fftSize: Int = 512,
        featureCount: Int = 80
    ) {
        self.sampleRate = sampleRate
        self.windowLength = Int((Double(sampleRate) * windowSize).rounded())
        self.hopLength = Int((Double(sampleRate) * windowStride).rounded())
        self.fftSize = fftSize
        self.featureCount = featureCount
        self.hannWindow = Self.makeHannWindow(length: Int((Double(sampleRate) * windowSize).rounded()))
        self.cosineTable = Self.makeCosineTable(fftSize: fftSize, sampleCount: Int((Double(sampleRate) * windowSize).rounded()))
        self.sineTable = Self.makeSineTable(fftSize: fftSize, sampleCount: Int((Double(sampleRate) * windowSize).rounded()))
        self.melFilterBank = Self.makeSlaneyMelFilterBank(sampleRate: sampleRate, fftSize: fftSize, featureCount: featureCount)
    }

    public func extract(samples: [Float]) -> LogMelFeatures {
        let frameCount = max(1, 1 + max(0, samples.count - 1) / hopLength)
        let frequencyBinCount = fftSize / 2 + 1
        var values = [Float](repeating: 0, count: featureCount * frameCount)
        var power = [Float](repeating: 0, count: frequencyBinCount)

        for frameIndex in 0..<frameCount {
            let sampleOffset = frameIndex * hopLength
            fillPowerSpectrum(samples: samples, sampleOffset: sampleOffset, power: &power)

            for featureIndex in 0..<featureCount {
                let filterOffset = featureIndex * frequencyBinCount
                var melEnergy = Float(0)
                for binIndex in 0..<frequencyBinCount {
                    melEnergy += melFilterBank[filterOffset + binIndex] * power[binIndex]
                }
                values[featureIndex * frameCount + frameIndex] = log(melEnergy + pow(2.0, -24.0))
            }
        }

        normalizePerFeature(values: &values, frameCount: frameCount)
        return LogMelFeatures(values: values, featureCount: featureCount, frameCount: frameCount)
    }

    private func fillPowerSpectrum(samples: [Float], sampleOffset: Int, power: inout [Float]) {
        let frequencyBinCount = fftSize / 2 + 1

        for binIndex in 0..<frequencyBinCount {
            var real = Float(0)
            var imaginary = Float(0)
            let tableOffset = binIndex * windowLength

            for windowIndex in 0..<windowLength {
                let inputIndex = sampleOffset + windowIndex
                let sample = inputIndex < samples.count ? samples[inputIndex] : 0
                let windowedSample = sample * hannWindow[windowIndex]
                real += windowedSample * cosineTable[tableOffset + windowIndex]
                imaginary -= windowedSample * sineTable[tableOffset + windowIndex]
            }

            power[binIndex] = real * real + imaginary * imaginary
        }
    }

    private func normalizePerFeature(values: inout [Float], frameCount: Int) {
        guard frameCount > 0 else { return }

        for featureIndex in 0..<featureCount {
            let start = featureIndex * frameCount
            let end = start + frameCount
            var mean = Float(0)
            for index in start..<end {
                mean += values[index]
            }
            mean /= Float(frameCount)

            var variance = Float(0)
            for index in start..<end {
                let delta = values[index] - mean
                variance += delta * delta
            }
            let standardDeviation = sqrt(variance / Float(frameCount)) + 1e-5

            for index in start..<end {
                values[index] = (values[index] - mean) / standardDeviation
            }
        }
    }

    private static func makeHannWindow(length: Int) -> [Float] {
        guard length > 1 else { return Array(repeating: 1, count: max(0, length)) }
        return (0..<length).map { index in
            Float(0.5 - 0.5 * cos((2.0 * Double.pi * Double(index)) / Double(length - 1)))
        }
    }

    private static func makeCosineTable(fftSize: Int, sampleCount: Int) -> [Float] {
        let frequencyBinCount = fftSize / 2 + 1
        var table = [Float](repeating: 0, count: frequencyBinCount * sampleCount)
        for binIndex in 0..<frequencyBinCount {
            for sampleIndex in 0..<sampleCount {
                let angle = (2.0 * Double.pi * Double(binIndex) * Double(sampleIndex)) / Double(fftSize)
                table[binIndex * sampleCount + sampleIndex] = Float(cos(angle))
            }
        }
        return table
    }

    private static func makeSineTable(fftSize: Int, sampleCount: Int) -> [Float] {
        let frequencyBinCount = fftSize / 2 + 1
        var table = [Float](repeating: 0, count: frequencyBinCount * sampleCount)
        for binIndex in 0..<frequencyBinCount {
            for sampleIndex in 0..<sampleCount {
                let angle = (2.0 * Double.pi * Double(binIndex) * Double(sampleIndex)) / Double(fftSize)
                table[binIndex * sampleCount + sampleIndex] = Float(sin(angle))
            }
        }
        return table
    }

    private static func makeSlaneyMelFilterBank(sampleRate: Int, fftSize: Int, featureCount: Int) -> [Float] {
        let frequencyBinCount = fftSize / 2 + 1
        let melMinimum = hertzToSlaneyMel(0)
        let melMaximum = hertzToSlaneyMel(Double(sampleRate) / 2.0)
        let melStep = (melMaximum - melMinimum) / Double(featureCount + 1)
        let hertzPoints = (0..<(featureCount + 2)).map { index in
            slaneyMelToHertz(melMinimum + Double(index) * melStep)
        }
        let binFrequencies = (0..<frequencyBinCount).map { index in
            (Double(sampleRate) / 2.0) * Double(index) / Double(frequencyBinCount - 1)
        }

        var filterBank = [Float](repeating: 0, count: featureCount * frequencyBinCount)
        for featureIndex in 0..<featureCount {
            let low = hertzPoints[featureIndex]
            let center = hertzPoints[featureIndex + 1]
            let high = hertzPoints[featureIndex + 2]
            let enorm = 2.0 / (high - low + 1e-12)

            for binIndex in 0..<frequencyBinCount {
                let frequency = binFrequencies[binIndex]
                let left = (frequency - low) / (center - low + 1e-12)
                let right = (high - frequency) / (high - center + 1e-12)
                filterBank[featureIndex * frequencyBinCount + binIndex] = Float(max(0, min(left, right)) * enorm)
            }
        }
        return filterBank
    }

    private static func hertzToSlaneyMel(_ frequency: Double) -> Double {
        let minimumLogHertz = 1_000.0
        let minimumLogMel = minimumLogHertz / (200.0 / 3.0)
        let logStep = log(6.4) / 27.0
        let safeFrequency = max(frequency, 1e-3)

        if safeFrequency < minimumLogHertz {
            return safeFrequency / (200.0 / 3.0)
        }
        return minimumLogMel + log(safeFrequency / minimumLogHertz) / logStep
    }

    private static func slaneyMelToHertz(_ mel: Double) -> Double {
        let minimumLogHertz = 1_000.0
        let minimumLogMel = minimumLogHertz / (200.0 / 3.0)
        let logStep = log(6.4) / 27.0

        if mel < minimumLogMel {
            return (200.0 / 3.0) * mel
        }
        return minimumLogHertz * exp(logStep * (mel - minimumLogMel))
    }
}
