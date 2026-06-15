import XCTest
@testable import HifzCore

final class LocalAudioAuditTests: XCTestCase {
    func testRollingAuditWindowsCoverLongAudioIncludingTail() {
        let sampleRate = 10
        let samples = Array(repeating: Float(0), count: 22 * sampleRate)

        let windows = makeRollingAuditWindows(
            samples: samples,
            sampleRate: sampleRate,
            windowSeconds: 8,
            hopSeconds: 4
        )

        XCTAssertEqual(windows.map(\.startSample), [0, 40, 80, 120, 140])
        XCTAssertEqual(windows.map(\.endSample), [80, 120, 160, 200, 220])
        XCTAssertEqual(windows.last?.durationSeconds, 8)

        let coveredSamples = Set(windows.flatMap { $0.startSample..<$0.endSample })
        XCTAssertEqual(coveredSamples.count, samples.count)
    }

    func testLocalAudioASRAudit() throws {
        guard ProcessInfo.processInfo.environment["HIFZ_RUN_LOCAL_AUDIO_AUDIT"] == "1" else {
            throw XCTSkip("Set HIFZ_RUN_LOCAL_AUDIO_AUDIT=1 to run the local audio ASR audit.")
        }

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let audioDirectory = root.appending(path: "local audio")
        let outputURL = root.appending(path: "artifacts/local-audio-audit.json")
        let audioURLs = try FileManager.default
            .contentsOfDirectory(at: audioDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "wav" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        XCTAssertFalse(audioURLs.isEmpty, "No WAV files found in \(audioDirectory.path)")

        let qpcURL = root.appending(path: "HifzTracker/Resources/qpc-v4.db")
        let layoutURL = root.appending(path: "HifzTracker/Resources/Layout/kfgqpc-v4-layout.sqlite")
        let mapping = try PageMapping.loadKFGQPCV4Layout(layoutDatabaseURL: layoutURL, qpcDatabaseURL: qpcURL)
        let repository = try SQLiteQuranRepository(
            databaseURL: qpcURL,
            tanzilURL: root.appending(path: "HifzTracker/Resources/quran-simple-clean.txt"),
            pageMapping: mapping,
            layoutDatabaseURL: layoutURL
        )
        let tokenizer = try QuranSTTTokenizer(tokensURL: root.appending(path: "assets/tokenizer/tokens.txt"))
        let session = try ONNXRuntimeSession(modelURL: root.appending(path: "assets/models/model_fp32.onnx"))
        let extractor = LogMelFeatureExtractor()
        let decoder = CTCGreedyDecoder(blankID: tokenizer.blankID)
        let auditWindowSeconds = 8.0
        let auditHopSeconds = 4.0

        var results: [LocalAudioAuditResult] = []
        for url in audioURLs {
            var locator = ProgressiveTranscriptLocator()
            let target = try targetFromFilename(url)
            let (audio, loadMS) = try timed { try WAVAudioFile(url: url) }
            let sourceDuration = Double(audio.info.frameCount) / Double(audio.info.sampleRate)
            let (samples16k, resampleMS) = timed {
                resample(samples: audio.samples, sourceSampleRate: audio.info.sampleRate, targetSampleRate: extractor.sampleRate)
            }
            let auditWindows = makeRollingAuditWindows(
                samples: samples16k,
                sampleRate: extractor.sampleRate,
                windowSeconds: auditWindowSeconds,
                hopSeconds: auditHopSeconds
            )
            XCTAssertFalse(auditWindows.isEmpty, "No rolling audit windows for \(url.lastPathComponent)")

            let expectedWords = try QuranReferenceWords.wordsForAyah(
                repository.referenceText(surah: target.surah, ayah: target.ayah),
                surah: target.surah,
                ayah: target.ayah
            )
            let expectedReferences = try references(for: target.surah, startAyah: 1, repository: repository)
            let pageNumber = repository.pageNumber(surah: target.surah, ayah: target.ayah)
            let page = try repository.mushafPage(pageNumber: pageNumber)
            let pageWords = page.lines.flatMap { $0.words }
            let pageLocations = Set(pageWords.map { $0.location })
            let targetReferences = expectedReferences.filter { $0.ayah == target.ayah }
            let targetWordsMappable = targetReferences.allSatisfy { pageLocations.contains($0.location) }

            var windowResults: [LocalAudioWindowResult] = []
            var mergedRecognizedWords: [String] = []
            var matchedReferencesByLocation: [String: RecitationWordReference] = [:]
            var totalFeatureMS = 0.0
            var totalInferenceMS = 0.0
            var totalDecodeMS = 0.0
            var totalWindowMS = 0.0
            var totalTokenCount = 0
            var totalFrameCount = 0

            for auditWindow in auditWindows {
                let auditSamples = Array(samples16k[auditWindow.startSample..<auditWindow.endSample])
                let (features, featureMS) = timed { extractor.extract(samples: auditSamples) }
                let (logProbabilities, inferenceMS) = try timed {
                    try session.runLogProbabilities(
                        features: features.values,
                        featureCount: features.featureCount,
                        frameCount: features.frameCount
                    )
                }
                let ((tokenIDs, transcript), decodeMS) = try timed {
                    let tokenIDsByFrame = logProbabilities.argmaxTokenIDs()
                    let tokenIDs = decoder.decode(tokenIDsByFrame: tokenIDsByFrame)
                    return (tokenIDs, try tokenizer.decode(tokenIDs: tokenIDs))
                }

                let recognizedWords = QuranTextNormalizer
                    .asrComparable(transcript)
                    .split(separator: " ")
                    .map(String.init)
                mergedRecognizedWords = mergeRecognizedWords(mergedRecognizedWords, with: recognizedWords)

                let location = locator.locate(expected: expectedReferences, recognizedWords: recognizedWords)
                let matchedReferences = location.map { Array(expectedReferences[$0.expectedRange]) } ?? []
                for reference in matchedReferences {
                    matchedReferencesByLocation[reference.location] = reference
                }

                let locatedAyahs = Set(matchedReferences.map { $0.ayah }).sorted()
                let highlightedLocations = Set(matchedReferences.map { $0.location })
                let matchedTargetHighlightCount = targetReferences.filter { highlightedLocations.contains($0.location) }.count
                let matchedLocationsMappable = matchedReferences.allSatisfy { pageLocations.contains($0.location) }
                let windowLCS = longestCommonSubsequenceLength(expectedWords, recognizedWords)
                let windowEditDistance = levenshteinDistance(expectedWords, recognizedWords)
                let windowTotalMS = featureMS + inferenceMS + decodeMS

                totalFeatureMS += featureMS
                totalInferenceMS += inferenceMS
                totalDecodeMS += decodeMS
                totalWindowMS += windowTotalMS
                totalTokenCount += tokenIDs.count
                totalFrameCount += features.frameCount

                windowResults.append(
                    LocalAudioWindowResult(
                        windowIndex: auditWindow.index,
                        startSeconds: auditWindow.startSeconds,
                        durationSeconds: auditWindow.durationSeconds,
                        transcript: transcript,
                        normalizedTranscript: recognizedWords.joined(separator: " "),
                        recognizedWords: recognizedWords,
                        tokenCount: tokenIDs.count,
                        frameCount: features.frameCount,
                        wordAccuracy: WordAccuracySummary(
                            expectedWordCount: expectedWords.count,
                            recognizedWordCount: recognizedWords.count,
                            lcsWordCount: windowLCS,
                            wordRecall: expectedWords.isEmpty ? 0 : Double(windowLCS) / Double(expectedWords.count),
                            wordPrecision: recognizedWords.isEmpty ? 0 : Double(windowLCS) / Double(recognizedWords.count),
                            wordErrorRate: expectedWords.isEmpty ? 0 : Double(windowEditDistance) / Double(expectedWords.count)
                        ),
                        locator: LocatorSummary(
                            found: location != nil,
                            correctTargetAyahOnly: !matchedReferences.isEmpty && locatedAyahs == [target.ayah],
                            completedThrough: location.map {
                                "\($0.completedThrough.surah):\($0.completedThrough.ayah):\($0.completedThrough.wordIndex)"
                            },
                            matchedWordCount: location?.matchedWordCount ?? 0,
                            locatedAyahs: locatedAyahs
                        ),
                        highlight: HighlightSummary(
                            pageNumber: pageNumber,
                            targetWordCount: targetReferences.count,
                            matchedTargetWordCount: matchedTargetHighlightCount,
                            targetWordsMappableToPage: targetWordsMappable,
                            matchedLocationsMappableToPage: matchedLocationsMappable
                        ),
                        timing: TimingSummary(
                            loadMS: 0,
                            resampleMS: 0,
                            featureMS: featureMS,
                            inferenceMS: inferenceMS,
                            decodeMS: decodeMS,
                            totalMS: windowTotalMS,
                            realtimeFactor: windowTotalMS / max(1, auditWindow.durationSeconds * 1_000),
                            windowCount: 1
                        )
                    )
                )
            }

            let matchedReferences = matchedReferencesByLocation.values.sorted(by: precedes)
            let matchedTargetReferences = matchedReferences.filter { $0.ayah == target.ayah }
            let locatedAyahs = Set(matchedReferences.map { $0.ayah }).sorted()
            let locationCorrect = !matchedReferences.isEmpty && locatedAyahs == [target.ayah]
            let highlightedLocations = Set(matchedReferences.map { $0.location })
            let matchedTargetHighlightCount = targetReferences.filter { highlightedLocations.contains($0.location) }.count
            let matchedLocationsMappable = matchedReferences.allSatisfy { pageLocations.contains($0.location) }
            let completedThrough = matchedTargetReferences.last.map { "\($0.surah):\($0.ayah):\($0.wordIndex)" }

            let lcs = longestCommonSubsequenceLength(expectedWords, mergedRecognizedWords)
            let editDistance = levenshteinDistance(expectedWords, mergedRecognizedWords)
            let totalMS = loadMS + resampleMS + totalWindowMS
            let audioSummary = AudioSummary(
                sampleRate: audio.info.sampleRate,
                channelCount: audio.info.channelCount,
                durationSeconds: sourceDuration,
                originalSampleCount: audio.samples.count,
                resampledSampleCount: samples16k.count,
                auditedDurationSeconds: sourceDuration,
                auditedSampleCount: samples16k.count,
                auditWindowCount: auditWindows.count
            )
            let wordAccuracy = WordAccuracySummary(
                expectedWordCount: expectedWords.count,
                recognizedWordCount: mergedRecognizedWords.count,
                lcsWordCount: lcs,
                wordRecall: expectedWords.isEmpty ? 0 : Double(lcs) / Double(expectedWords.count),
                wordPrecision: mergedRecognizedWords.isEmpty ? 0 : Double(lcs) / Double(mergedRecognizedWords.count),
                wordErrorRate: expectedWords.isEmpty ? 0 : Double(editDistance) / Double(expectedWords.count)
            )
            let locatorSummary = LocatorSummary(
                found: !matchedReferences.isEmpty,
                correctTargetAyahOnly: locationCorrect,
                completedThrough: completedThrough,
                matchedWordCount: matchedTargetReferences.count,
                locatedAyahs: locatedAyahs
            )
            let highlightSummary = HighlightSummary(
                pageNumber: pageNumber,
                targetWordCount: targetReferences.count,
                matchedTargetWordCount: matchedTargetHighlightCount,
                targetWordsMappableToPage: targetWordsMappable,
                matchedLocationsMappableToPage: matchedLocationsMappable
            )
            let timingSummary = TimingSummary(
                loadMS: loadMS,
                resampleMS: resampleMS,
                featureMS: totalFeatureMS,
                inferenceMS: totalInferenceMS,
                decodeMS: totalDecodeMS,
                totalMS: totalMS,
                realtimeFactor: totalMS / max(1, sourceDuration * 1_000),
                windowCount: auditWindows.count
            )
            let result = LocalAudioAuditResult(
                file: url.lastPathComponent,
                target: "\(target.surah):\(target.ayah)",
                audio: audioSummary,
                transcript: windowResults.map(\.transcript).joined(separator: " | "),
                normalizedTranscript: mergedRecognizedWords.joined(separator: " "),
                expectedWords: expectedWords,
                recognizedWords: mergedRecognizedWords,
                tokenCount: totalTokenCount,
                frameCount: totalFrameCount,
                wordAccuracy: wordAccuracy,
                locator: locatorSummary,
                highlight: highlightSummary,
                timing: timingSummary,
                windows: windowResults
            )
            results.append(result)
        }

        let report = LocalAudioAuditReport(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            onnxRuntimeVersion: ONNXRuntime.versionString(),
            model: "assets/models/model_fp32.onnx",
            tokenizer: "assets/tokenizer/tokens.txt",
            audioDirectory: "local audio",
            results: results
        )
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: outputURL)
        print("LOCAL_AUDIO_AUDIT_REPORT=\(outputURL.path)")
    }

    private func targetFromFilename(_ url: URL) throws -> (surah: Int, ayah: Int) {
        let stem = url.deletingPathExtension().lastPathComponent
        guard stem.count == 6,
              let surah = Int(stem.prefix(3)),
              let ayah = Int(stem.suffix(3)) else {
            throw LocalAudioAuditError.invalidFilename(stem)
        }
        return (surah, ayah)
    }

    private func references(
        for surah: Int,
        startAyah: Int,
        repository: QuranRepository
    ) throws -> [RecitationWordReference] {
        guard let surahInfo = SurahCatalog.surah(surah) else { return [] }

        var references: [RecitationWordReference] = []
        for ayah in startAyah...surahInfo.ayahCount {
            let referenceWords = QuranReferenceWords.wordsForAyah(
                try repository.referenceText(surah: surah, ayah: ayah),
                surah: surah,
                ayah: ayah
            )
            let glyphWords = try repository.words(surah: surah, ayah: ayah)
            for (offset, word) in referenceWords.enumerated() {
                let wordIndex = glyphWords.indices.contains(offset) ? glyphWords[offset].wordIndex : offset + 1
                references.append(RecitationWordReference(surah: surah, ayah: ayah, wordIndex: wordIndex, text: word))
            }
        }
        return references
    }
}

private enum LocalAudioAuditError: Error {
    case invalidFilename(String)
}

private struct LocalAudioAuditReport: Codable {
    var generatedAt: String
    var onnxRuntimeVersion: String
    var model: String
    var tokenizer: String
    var audioDirectory: String
    var results: [LocalAudioAuditResult]
}

private struct LocalAudioAuditResult: Codable {
    var file: String
    var target: String
    var audio: AudioSummary
    var transcript: String
    var normalizedTranscript: String
    var expectedWords: [String]
    var recognizedWords: [String]
    var tokenCount: Int
    var frameCount: Int
    var wordAccuracy: WordAccuracySummary
    var locator: LocatorSummary
    var highlight: HighlightSummary
    var timing: TimingSummary
    var windows: [LocalAudioWindowResult]
}

private struct LocalAudioWindowResult: Codable {
    var windowIndex: Int
    var startSeconds: Double
    var durationSeconds: Double
    var transcript: String
    var normalizedTranscript: String
    var recognizedWords: [String]
    var tokenCount: Int
    var frameCount: Int
    var wordAccuracy: WordAccuracySummary
    var locator: LocatorSummary
    var highlight: HighlightSummary
    var timing: TimingSummary
}

private struct AudioSummary: Codable {
    var sampleRate: Int
    var channelCount: Int
    var durationSeconds: Double
    var originalSampleCount: Int
    var resampledSampleCount: Int
    var auditedDurationSeconds: Double
    var auditedSampleCount: Int
    var auditWindowCount: Int
}

private struct WordAccuracySummary: Codable {
    var expectedWordCount: Int
    var recognizedWordCount: Int
    var lcsWordCount: Int
    var wordRecall: Double
    var wordPrecision: Double
    var wordErrorRate: Double
}

private struct LocatorSummary: Codable {
    var found: Bool
    var correctTargetAyahOnly: Bool
    var completedThrough: String?
    var matchedWordCount: Int
    var locatedAyahs: [Int]
}

private struct HighlightSummary: Codable {
    var pageNumber: Int
    var targetWordCount: Int
    var matchedTargetWordCount: Int
    var targetWordsMappableToPage: Bool
    var matchedLocationsMappableToPage: Bool
}

private struct TimingSummary: Codable {
    var loadMS: Double
    var resampleMS: Double
    var featureMS: Double
    var inferenceMS: Double
    var decodeMS: Double
    var totalMS: Double
    var realtimeFactor: Double
    var windowCount: Int
}

private struct RollingAuditWindow {
    var index: Int
    var startSample: Int
    var endSample: Int
    var sampleRate: Int

    var startSeconds: Double {
        Double(startSample) / Double(sampleRate)
    }

    var durationSeconds: Double {
        Double(endSample - startSample) / Double(sampleRate)
    }
}

private func makeRollingAuditWindows(
    samples: [Float],
    sampleRate: Int,
    windowSeconds: Double,
    hopSeconds: Double
) -> [RollingAuditWindow] {
    guard !samples.isEmpty, sampleRate > 0 else { return [] }

    let windowSampleCount = max(1, Int((Double(sampleRate) * windowSeconds).rounded()))
    let hopSampleCount = max(1, Int((Double(sampleRate) * hopSeconds).rounded()))

    guard samples.count > windowSampleCount else {
        return [
            RollingAuditWindow(index: 0, startSample: 0, endSample: samples.count, sampleRate: sampleRate)
        ]
    }

    var starts: [Int] = []
    var startSample = 0
    while startSample + windowSampleCount < samples.count {
        starts.append(startSample)
        startSample += hopSampleCount
    }

    let finalStart = max(0, samples.count - windowSampleCount)
    if starts.last != finalStart {
        starts.append(finalStart)
    }

    return starts.enumerated().map { index, startSample in
        RollingAuditWindow(
            index: index,
            startSample: startSample,
            endSample: min(samples.count, startSample + windowSampleCount),
            sampleRate: sampleRate
        )
    }
}

private func mergeRecognizedWords(_ accumulated: [String], with next: [String]) -> [String] {
    guard !accumulated.isEmpty else { return next }
    guard !next.isEmpty else { return accumulated }

    let maximumOverlap = min(accumulated.count, next.count)
    for overlap in stride(from: maximumOverlap, through: 1, by: -1) {
        if Array(accumulated.suffix(overlap)) == Array(next.prefix(overlap)) {
            return accumulated + next.dropFirst(overlap)
        }
    }
    return accumulated + next
}

private func precedes(_ left: RecitationWordReference, _ right: RecitationWordReference) -> Bool {
    if left.surah != right.surah {
        return left.surah < right.surah
    }
    if left.ayah != right.ayah {
        return left.ayah < right.ayah
    }
    return left.wordIndex < right.wordIndex
}

private func timed<T>(_ work: () throws -> T) rethrows -> (T, Double) {
    let start = DispatchTime.now().uptimeNanoseconds
    let result = try work()
    let elapsed = DispatchTime.now().uptimeNanoseconds - start
    return (result, Double(elapsed) / 1_000_000.0)
}

private func resample(samples: [Float], sourceSampleRate: Int, targetSampleRate: Int) -> [Float] {
    guard !samples.isEmpty, sourceSampleRate > 0, targetSampleRate > 0 else {
        return []
    }
    guard sourceSampleRate != targetSampleRate else {
        return samples
    }

    let outputCount = max(1, Int((Double(samples.count) * Double(targetSampleRate) / Double(sourceSampleRate)).rounded(.down)))
    let sourceStep = Double(sourceSampleRate) / Double(targetSampleRate)
    var output = [Float](repeating: 0, count: outputCount)

    for outputIndex in 0..<outputCount {
        let sourcePosition = Double(outputIndex) * sourceStep
        let lowerIndex = min(samples.count - 1, Int(sourcePosition.rounded(.down)))
        let upperIndex = min(samples.count - 1, lowerIndex + 1)
        let fraction = Float(sourcePosition - Double(lowerIndex))
        output[outputIndex] = samples[lowerIndex] + (samples[upperIndex] - samples[lowerIndex]) * fraction
    }
    return output
}

private func longestCommonSubsequenceLength(_ left: [String], _ right: [String]) -> Int {
    let normalizedLeft = left.map(QuranTextNormalizer.asrComparable)
    let normalizedRight = right.map(QuranTextNormalizer.asrComparable)
    var previous = [Int](repeating: 0, count: normalizedRight.count + 1)
    var current = previous

    for leftWord in normalizedLeft {
        for (rightOffset, rightWord) in normalizedRight.enumerated() {
            if leftWord == rightWord {
                current[rightOffset + 1] = previous[rightOffset] + 1
            } else {
                current[rightOffset + 1] = max(previous[rightOffset + 1], current[rightOffset])
            }
        }
        previous = current
    }
    return previous.last ?? 0
}

private func levenshteinDistance(_ left: [String], _ right: [String]) -> Int {
    let normalizedLeft = left.map(QuranTextNormalizer.asrComparable)
    let normalizedRight = right.map(QuranTextNormalizer.asrComparable)
    var previous = Array(0...normalizedRight.count)
    var current = previous

    for (leftOffset, leftWord) in normalizedLeft.enumerated() {
        current[0] = leftOffset + 1
        for (rightOffset, rightWord) in normalizedRight.enumerated() {
            let substitution = previous[rightOffset] + (leftWord == rightWord ? 0 : 1)
            let insertion = current[rightOffset] + 1
            let deletion = previous[rightOffset + 1] + 1
            current[rightOffset + 1] = min(substitution, insertion, deletion)
        }
        previous = current
    }
    return previous.last ?? normalizedLeft.count
}
