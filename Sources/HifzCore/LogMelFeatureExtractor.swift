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
    private let bitReversedIndices: [Int]
    private let twiddleReal: [Float]
    private let twiddleImaginary: [Float]
    private let melFilters: [MelFilter]

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
        self.bitReversedIndices = Self.makeBitReversedIndices(size: fftSize)
        self.twiddleReal = Self.makeTwiddleReal(size: fftSize)
        self.twiddleImaginary = Self.makeTwiddleImaginary(size: fftSize)
        self.melFilters = Self.makeSlaneyMelFilters(sampleRate: sampleRate, fftSize: fftSize, featureCount: featureCount)
    }

    public func extract(samples: [Float]) -> LogMelFeatures {
        let frameCount = max(1, 1 + max(0, samples.count - 1) / hopLength)
        let frequencyBinCount = fftSize / 2 + 1
        let energyFloor = Float(pow(2.0, -24.0))
        var values = [Float](repeating: 0, count: featureCount * frameCount)
        var power = [Float](repeating: 0, count: frequencyBinCount)
        var real = [Float](repeating: 0, count: fftSize)
        var imaginary = [Float](repeating: 0, count: fftSize)

        for frameIndex in 0..<frameCount {
            let sampleOffset = frameIndex * hopLength
            fillPowerSpectrum(
                samples: samples,
                sampleOffset: sampleOffset,
                real: &real,
                imaginary: &imaginary,
                power: &power
            )

            for featureIndex in 0..<featureCount {
                let filter = melFilters[featureIndex]
                var melEnergy = Float(0)
                for offset in filter.weights.indices {
                    melEnergy += filter.weights[offset] * power[filter.startBin + offset]
                }
                values[featureIndex * frameCount + frameIndex] = log(melEnergy + energyFloor)
            }
        }

        normalizePerFeature(values: &values, frameCount: frameCount)
        return LogMelFeatures(values: values, featureCount: featureCount, frameCount: frameCount)
    }

    private func fillPowerSpectrum(
        samples: [Float],
        sampleOffset: Int,
        real: inout [Float],
        imaginary: inout [Float],
        power: inout [Float]
    ) {
        guard bitReversedIndices.count == fftSize else {
            fillDirectPowerSpectrum(samples: samples, sampleOffset: sampleOffset, power: &power)
            return
        }

        for index in 0..<fftSize {
            let sourceIndex = bitReversedIndices[index]
            if sourceIndex < windowLength {
                let inputIndex = sampleOffset + sourceIndex
                let sample = inputIndex < samples.count ? samples[inputIndex] : 0
                real[index] = sample * hannWindow[sourceIndex]
            } else {
                real[index] = 0
            }
            imaginary[index] = 0
        }

        var length = 2
        while length <= fftSize {
            let halfLength = length / 2
            let tableStep = fftSize / length

            for start in stride(from: 0, to: fftSize, by: length) {
                for offset in 0..<halfLength {
                    let twiddleIndex = offset * tableStep
                    let evenIndex = start + offset
                    let oddIndex = evenIndex + halfLength
                    let rotationReal = twiddleReal[twiddleIndex]
                    let rotationImaginary = twiddleImaginary[twiddleIndex]
                    let oddReal = real[oddIndex]
                    let oddImaginary = imaginary[oddIndex]
                    let transformedReal = rotationReal * oddReal - rotationImaginary * oddImaginary
                    let transformedImaginary = rotationReal * oddImaginary + rotationImaginary * oddReal

                    real[oddIndex] = real[evenIndex] - transformedReal
                    imaginary[oddIndex] = imaginary[evenIndex] - transformedImaginary
                    real[evenIndex] += transformedReal
                    imaginary[evenIndex] += transformedImaginary
                }
            }

            length *= 2
        }

        let frequencyBinCount = fftSize / 2 + 1
        for binIndex in 0..<frequencyBinCount {
            power[binIndex] = real[binIndex] * real[binIndex] + imaginary[binIndex] * imaginary[binIndex]
        }
    }

    private func fillDirectPowerSpectrum(samples: [Float], sampleOffset: Int, power: inout [Float]) {
        let frequencyBinCount = fftSize / 2 + 1
        for binIndex in 0..<frequencyBinCount {
            var real = Float(0)
            var imaginary = Float(0)

            for windowIndex in 0..<windowLength {
                let inputIndex = sampleOffset + windowIndex
                let sample = inputIndex < samples.count ? samples[inputIndex] : 0
                let windowedSample = sample * hannWindow[windowIndex]
                let angle = (2.0 * Double.pi * Double(binIndex) * Double(windowIndex)) / Double(fftSize)
                real += windowedSample * Float(cos(angle))
                imaginary -= windowedSample * Float(sin(angle))
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

    private static func makeBitReversedIndices(size: Int) -> [Int] {
        guard size > 0, size.nonzeroBitCount == 1 else { return [] }
        let bitCount = Int(log2(Double(size)))
        return (0..<size).map { index in
            var value = index
            var reversed = 0
            for _ in 0..<bitCount {
                reversed = (reversed << 1) | (value & 1)
                value >>= 1
            }
            return reversed
        }
    }

    private static func makeTwiddleReal(size: Int) -> [Float] {
        guard size > 0 else { return [] }
        return (0..<size).map { index in
            Float(cos((-2.0 * Double.pi * Double(index)) / Double(size)))
        }
    }

    private static func makeTwiddleImaginary(size: Int) -> [Float] {
        guard size > 0 else { return [] }
        return (0..<size).map { index in
            Float(sin((-2.0 * Double.pi * Double(index)) / Double(size)))
        }
    }

    private static func makeSlaneyMelFilters(sampleRate: Int, fftSize: Int, featureCount: Int) -> [MelFilter] {
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

        return (0..<featureCount).map { featureIndex in
            let low = hertzPoints[featureIndex]
            let center = hertzPoints[featureIndex + 1]
            let high = hertzPoints[featureIndex + 2]
            let enorm = 2.0 / (high - low + 1e-12)
            var startBin: Int?
            var weights: [Float] = []

            for binIndex in 0..<frequencyBinCount {
                let frequency = binFrequencies[binIndex]
                let left = (frequency - low) / (center - low + 1e-12)
                let right = (high - frequency) / (high - center + 1e-12)
                let weight = Float(max(0, min(left, right)) * enorm)
                if weight > 0 {
                    if startBin == nil {
                        startBin = binIndex
                    }
                    weights.append(weight)
                } else if startBin != nil {
                    break
                }
            }
            return MelFilter(startBin: startBin ?? 0, weights: weights)
        }
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

private struct MelFilter: Sendable {
    var startBin: Int
    var weights: [Float]
}
