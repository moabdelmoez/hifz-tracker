import Accelerate
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
    private let melFilters: [MelFilter]

    public init(
        sampleRate: Int = 16_000,
        windowSize: Double = 0.025,
        windowStride: Double = 0.010,
        fftSize: Int = 512,
        featureCount: Int = 80
    ) {
        let windowLength = Int((Double(sampleRate) * windowSize).rounded())
        precondition(fftSize > 0 && fftSize.nonzeroBitCount == 1)
        precondition(windowLength <= fftSize)

        self.sampleRate = sampleRate
        self.windowLength = windowLength
        self.hopLength = Int((Double(sampleRate) * windowStride).rounded())
        self.fftSize = fftSize
        self.featureCount = featureCount
        self.hannWindow = vDSP.window(
            ofType: Float.self,
            usingSequence: .hanningDenormalized,
            count: windowLength,
            isHalfWindow: false
        )
        self.melFilters = Self.makeSlaneyMelFilters(sampleRate: sampleRate, fftSize: fftSize, featureCount: featureCount)
    }

    public func extract(samples: [Float]) -> LogMelFeatures {
        let frameCount = max(1, 1 + max(0, samples.count - 1) / hopLength)
        let frequencyBinCount = fftSize / 2 + 1
        let energyFloor = Float(pow(2.0, -24.0))
        var values = [Float](repeating: 0, count: featureCount * frameCount)
        var power = [Float](repeating: 0, count: frequencyBinCount)
        var inputReal = [Float](repeating: 0, count: fftSize)
        let inputImaginary = [Float](repeating: 0, count: fftSize)
        var outputReal = [Float](repeating: 0, count: fftSize)
        var outputImaginary = [Float](repeating: 0, count: fftSize)
        let transform = try! vDSP.DiscreteFourierTransform(
            count: fftSize,
            direction: .forward,
            transformType: .complexComplex,
            ofType: Float.self
        )

        for frameIndex in 0..<frameCount {
            let sampleOffset = frameIndex * hopLength
            vDSP.clear(&inputReal)
            let availableSampleCount = min(windowLength, max(0, samples.count - sampleOffset))
            if availableSampleCount > 0 {
                let windowed = vDSP.multiply(
                    samples[sampleOffset..<(sampleOffset + availableSampleCount)],
                    hannWindow.prefix(availableSampleCount)
                )
                inputReal.replaceSubrange(0..<availableSampleCount, with: windowed)
            }

            transform.transform(
                inputReal: inputReal,
                inputImaginary: inputImaginary,
                outputReal: &outputReal,
                outputImaginary: &outputImaginary
            )
            outputReal.withUnsafeMutableBufferPointer { real in
                outputImaginary.withUnsafeMutableBufferPointer { imaginary in
                    let spectrum = DSPSplitComplex(
                        realp: real.baseAddress!,
                        imagp: imaginary.baseAddress!
                    )
                    vDSP.squareMagnitudes(spectrum, result: &power)
                }
            }

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
