import XCTest
@testable import HifzCore

final class ProgressiveTranscriptLocatorTests: XCTestCase {
    func testRejectsShortInitialMatchBeforePlaceIsLocked() {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 24
        )
        let expected = references([
            (1, ["سبح", "لله", "ما", "في", "السماوات"]),
            (22, ["هو", "الله", "الذي"])
        ])

        let location = locator.locate(expected: expected, recognizedWords: ["هو", "الله"])

        XCTAssertNil(location)
    }

    func testAcceptsCompleteShortAyahAsInitialLock() throws {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 24
        )
        let expected = references([
            (1, ["انا", "اعطيناك", "الكوثر"]),
            (2, ["فصل", "لربك", "وانحر"])
        ], surah: 108)

        let location = try XCTUnwrap(
            locator.locate(expected: expected, recognizedWords: ["انا", "اعطيناك", "الكوثر"])
        )

        XCTAssertEqual(location.completedThrough.location, "108:1:3")
    }

    func testRejectsLaterCompleteShortAyahBeforeInitialLock() {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 24
        )
        let expected = references([
            (1, ["هل", "اتاك", "حديث", "الغاشية"]),
            (2, ["وجوه", "يومئذ", "خاشعة"]),
            (3, ["عاملة", "ناصبة"]),
            (4, ["تصلى", "نارا", "حامية"]),
            (5, ["تسقى", "من", "عين", "انية"]),
            (6, ["ليس", "لهم", "طعام", "الا", "من", "ضريع"]),
            (7, ["لا", "يسمن", "ولا", "يغني", "من", "جوع"]),
            (8, ["وجوه", "يومئذ", "ناعمة"])
        ], surah: 88)

        let location = locator.locate(
            expected: expected,
            recognizedWords: ["وجوه", "يومئذ", "ناعمة"]
        )

        XCTAssertNil(
            location,
            "A complete short ayah later in the selected scope should not initial-lock when it can be an ASR confusion of the near-start ayah."
        )
    }

    func testRejectsFarRepeatedStrongMatchBeforeInitialLock() {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 24
        )
        let expected = references([
            (1, ["لم", "يكن", "الذين", "كفروا", "من", "اهل", "الكتاب", "والمشركين", "منفكين", "حتى", "تاتيهم", "البينة"]),
            (2, ["رسول", "من", "الله", "يتلو", "صحفا", "مطهرة"]),
            (3, ["فيها", "كتب", "قيمة"]),
            (4, ["وما", "تفرق", "الذين", "اوتوا", "الكتاب", "الا", "من", "بعد", "ما", "جاءتهم", "البينة"]),
            (5, ["وما", "امروا", "الا", "ليعبدوا", "الله", "مخلصين", "له", "الدين", "حنفاء", "ويقيموا", "الصلاة", "ويؤتوا", "الزكاة", "وذلك", "دين", "القيمة"]),
            (6, ["ان", "الذين", "كفروا", "من", "اهل", "الكتاب", "والمشركين", "في", "نار", "جهنم"])
        ], surah: 98)

        let location = locator.locate(
            expected: expected,
            recognizedWords: ["ان", "الذين", "كفروا", "من", "اهل", "الكتاب", "والمشركين", "في"]
        )

        XCTAssertNil(
            location,
            "The first live lock should not jump to a far repeated phrase before progress from the selected start is established."
        )
    }

    func testPostLockAdvancesThroughSurahNasrOneAyahPerCall() throws {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 24
        )
        let expected = references([
            (1, ["اذا", "جاء", "نصر", "الله", "والفتح"]),
            (2, ["ورايت", "الناس", "يدخلون", "في", "دين", "الله", "افواجا"]),
            (3, ["فسبح", "بحمد", "ربك", "واستغفره", "انه", "كان", "توابا"])
        ], surah: 110)

        _ = try XCTUnwrap(locator.locate(
            expected: expected,
            recognizedWords: ["اذا", "جاء", "نصر", "الله", "والفتح"]
        ))
        let trailingTranscript = ["يدخلون", "في", "دين", "الله", "افواجا", "فسبح", "بحمد", "ربك", "واستغفره", "انه", "كان", "توابا"]
        let ayahTwo = try XCTUnwrap(locator.locate(
            expected: expected,
            recognizedWords: trailingTranscript
        ))
        let ayahThree = try XCTUnwrap(locator.locate(expected: expected, recognizedWords: trailingTranscript))

        XCTAssertEqual(ayahTwo.completedThrough.location, "110:2:7")
        XCTAssertEqual(ayahThree.completedThrough.location, "110:3:7")
    }

    func testInitialLockDoesNotSkipSelectedStartAyah() {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 24
        )
        let expected = references([
            (1, ["اذا", "جاء", "نصر", "الله", "والفتح"]),
            (2, ["ورايت", "الناس", "يدخلون", "في", "دين", "الله", "افواجا"]),
            (3, ["فسبح", "بحمد", "ربك", "واستغفره", "انه", "كان", "توابا"])
        ], surah: 110)

        let trailingTranscript = ["يدخلون", "في", "دين", "الله", "افواجا", "فسبح", "بحمد", "ربك", "واستغفره", "انه", "كان", "توابا"]
        let ayahTwo = locator.locate(
            expected: expected,
            recognizedWords: trailingTranscript
        )
        let ayahThree = locator.locate(expected: expected, recognizedWords: trailingTranscript)

        XCTAssertNil(ayahTwo)
        XCTAssertNil(ayahThree)
    }

    func testSequentialProgressionCrossesSurahBoundaryOneAyahPerCall() throws {
        let expected = references([
            (11, ["اول", "ثان", "ثالث", "رابع"])
        ], surah: 100) + references([
            (1, ["خامس", "سادس", "سابع", "ثامن"]),
            (2, ["تاسع", "عاشر", "حادي", "عشر"])
        ], surah: 101)
        let transcript = expected.map(\.text)
        var locator = ProgressiveTranscriptLocator()

        let selectedSurah = try XCTUnwrap(locator.locate(expected: expected, recognizedWords: transcript))
        let nextSurah = try XCTUnwrap(locator.locate(expected: expected, recognizedWords: transcript))
        let secondAyah = try XCTUnwrap(locator.locate(expected: expected, recognizedWords: transcript))

        XCTAssertEqual(selectedSurah.completedThrough.location, "100:11:4")
        XCTAssertEqual(nextSurah.completedThrough.location, "101:1:4")
        XCTAssertEqual(secondAyah.completedThrough.location, "101:2:4")
    }

    func testPostLockCompletesShortAyahAcrossSingleASRSubstitutionWithMatchedSuffix() throws {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 24
        )
        let expected = references([
            (6, ["كلا", "ان", "الانسان", "ليطغى"]),
            (7, ["ان", "راه", "استغنى"]),
            (8, ["ان", "الى", "ربك", "الرجعى"])
        ], surah: 96)

        _ = try XCTUnwrap(locator.locate(
            expected: expected,
            recognizedWords: ["كلا", "ان", "الانسان", "ليطغى"]
        ))
        _ = try XCTUnwrap(locator.locate(
            expected: expected,
            recognizedWords: ["ان", "راه", "استغنى"]
        ))
        let recognizedWords = ["ان", "الى", "ربه", "الرجعى"]
        let prefix = try XCTUnwrap(locator.locate(
            expected: expected,
            recognizedWords: recognizedWords
        ))
        let completed = try XCTUnwrap(locator.locate(expected: expected, recognizedWords: recognizedWords))

        XCTAssertEqual(prefix.completedThrough.location, "96:8:2")
        XCTAssertEqual(completed.completedThrough.location, "96:8:4")
    }

    func testPostLockDoesNotBridgeSingleASRSubstitutionWithoutAcceptedPrefix() throws {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 24
        )
        let expected = references([
            (6, ["كلا", "ان", "الانسان", "ليطغى"]),
            (7, ["ان", "راه", "استغنى"]),
            (8, ["ان", "الى", "ربك", "الرجعى"])
        ], surah: 96)

        _ = try XCTUnwrap(locator.locate(
            expected: expected,
            recognizedWords: ["كلا", "ان", "الانسان", "ليطغى"]
        ))
        _ = try XCTUnwrap(locator.locate(
            expected: expected,
            recognizedWords: ["ان", "راه", "استغنى"]
        ))
        let location = locator.locate(
            expected: expected,
            recognizedWords: ["ربه", "الرجعى"]
        )

        XCTAssertNil(location)
    }

    func testRejectsNearbyCompleteShortAyahBeforeInitialLock() {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 24
        )
        let expected = references([
            (1, ["هل", "اتاك", "حديث", "الغاشية"]),
            (2, ["وجوه", "يومئذ", "خاشعة"]),
            (3, ["عاملة", "ناصبة"])
        ], surah: 88)

        let location = locator.locate(
            expected: expected,
            recognizedWords: ["وجوه", "يومئذ", "خاشعة"]
        )

        XCTAssertNil(location)
    }

    func testAcceptsUniqueThreeWordInitialMatchNearStart() throws {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 24
        )
        let expected = references([
            (1, ["يا", "ايها", "المزمل", "قم", "الليل", "الا"]),
            (2, ["رب", "المشرق", "والمغرب"])
        ], surah: 73)

        let location = try XCTUnwrap(
            locator.locate(expected: expected, recognizedWords: ["يا", "ايها", "المزمل"])
        )

        XCTAssertEqual(location.completedThrough.location, "73:1:3")
        XCTAssertEqual(location.matchedWordCount, 3)
    }

    func testRejectsRepeatedThreeWordInitialMatchUntilFourWordMatch() throws {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 24
        )
        let expected = references([
            (1, ["يا", "ايها", "الذين", "امنوا", "اوفوا"]),
            (2, ["قريب", "منكم"]),
            (3, ["يا", "ايها", "الذين", "صدقوا", "الله"])
        ], surah: 5)

        let ambiguousShortMatch = locator.locate(
            expected: expected,
            recognizedWords: ["يا", "ايها", "الذين"]
        )
        XCTAssertNil(ambiguousShortMatch)

        let strongMatch = try XCTUnwrap(
            locator.locate(expected: expected, recognizedWords: ["يا", "ايها", "الذين", "امنوا"])
        )
        XCTAssertEqual(strongMatch.completedThrough.location, "5:1:4")
        XCTAssertEqual(strongMatch.matchedWordCount, 4)
    }

    func testRejectsUniqueThreeWordInitialMatchBeyondRelaxedStartLimit() {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 24
        )
        let filler = (1...32).map { "حشو\($0)" }
        let expected = references([
            (1, filler),
            (2, ["نادر", "قريب", "واضح", "بعد"])
        ])

        let location = locator.locate(expected: expected, recognizedWords: ["نادر", "قريب", "واضح"])

        XCTAssertNil(location)
    }

    func testKeepsLockedProgressFromJumpingToDistantShortMatch() throws {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 12
        )
        let expected = references([
            (1, ["سبح", "لله", "ما", "في", "السماوات", "وما", "في", "الارض"]),
            (2, ["هو", "الذي", "اخرج", "الذين", "كفروا"]),
            (3, Array(repeating: "حشو", count: 32)),
            (22, ["هو", "الله", "الذي", "لا", "اله"])
        ])

        let initialLocation = try XCTUnwrap(
            locator.locate(expected: expected, recognizedWords: ["سبح", "لله", "ما", "في"])
        )
        XCTAssertEqual(initialLocation.completedThrough.location, "59:1:4")

        let distantShortMatch = locator.locate(expected: expected, recognizedWords: ["هو", "الله", "الذي"])

        XCTAssertNil(distantShortMatch)
    }

    func testDoesNotJumpFromAyahThreeToRepeatedPhraseInAyahTen() throws {
        let ayahs = [
            (3, ["اتبعوا", "ما", "انزل", "اليكم", "من", "ربكم", "ولا", "تتبعوا", "من", "دونه", "اولياء", "قليلا", "ما", "تذكرون"]),
            (4, ["وكم", "من", "قرية", "اهلكناها", "فجاءها", "باسنا", "بياتا", "او", "هم", "قائلون"]),
            (5, ["فما", "كان", "دعواهم", "اذ", "جاءهم", "باسنا", "الا", "ان", "قالوا", "انا", "كنا", "ظالمين"]),
            (6, ["فلنسالن", "الذين", "ارسل", "اليهم", "ولنسالن", "المرسلين"]),
            (7, ["فلنقصن", "عليهم", "بعلم", "وما", "كنا", "غائبين"]),
            (8, ["والوزن", "يومئذ", "الحق", "فمن", "ثقلت", "موازينه", "فاولئك", "هم", "المفلحون"]),
            (9, ["ومن", "خفت", "موازينه", "فاولئك", "الذين", "خسروا", "انفسهم", "بما", "كانوا", "باياتنا", "يظلمون"]),
            (10, ["ولقد", "مكناكم", "في", "الارض", "وجعلنا", "لكم", "فيها", "معايش", "قليلا", "ما", "تشكرون"])
        ]
        let expected = references(ayahs, surah: 7)
        let ayahThreeTranscript = ayahs[0].1
        var locator = ProgressiveTranscriptLocator()

        let initial = try XCTUnwrap(locator.locate(expected: expected, recognizedWords: ayahThreeTranscript))
        XCTAssertEqual(initial.completedThrough.location, "7:3:14")

        XCTAssertNil(locator.locate(expected: expected, recognizedWords: ayahThreeTranscript))
    }

    func testPostLockDoesNotJumpToLaterOccurrenceOfRepeatedPhraseWithinAyah() throws {
        let expected = references([
            (1, [
                "يا", "ايها", "الذين", "امنوا", "لا", "تتخذوا", "عدوي", "وعدوكم", "اولياء", "تلقون",
                "اليهم", "بالمودة", "وقد", "كفروا", "بما", "جاءكم", "من", "الحق", "يخرجون", "الرسول",
                "واياكم", "ان", "تؤمنوا", "بالله", "ربكم", "ان", "كنتم", "خرجتم", "جهادا", "في",
                "سبيلي", "وابتغاء", "مرضاتي", "تسرون", "اليهم", "بالمودة", "وانا", "اعلم", "بما", "اخفيتم",
                "وما", "اعلنتم", "ومن", "يفعله", "منكم", "فقد", "ضل", "سواء", "السبيل"
            ])
        ], surah: 60)
        var locator = ProgressiveTranscriptLocator()

        let throughWordTen = try XCTUnwrap(locator.locate(
            expected: expected,
            recognizedWords: Array(expected[0..<10].map(\.text))
        ))
        let firstOccurrence = try XCTUnwrap(locator.locate(
            expected: expected,
            recognizedWords: ["اليهم", "بالمودة"]
        ))
        let staleFirstOccurrence = locator.locateWithOutcome(
            expected: expected,
            recognizedWords: ["اولياء", "تلقون", "اليهم", "بالمودة"]
        )

        XCTAssertEqual(throughWordTen.completedThrough.location, "60:1:10")
        XCTAssertEqual(firstOccurrence.completedThrough.location, "60:1:12")
        XCTAssertEqual(staleFirstOccurrence, .notAdvancing(completedOffset: 11, acceptedOffset: 11))
        guard staleFirstOccurrence == .notAdvancing(completedOffset: 11, acceptedOffset: 11) else { return }

        let resumed = try XCTUnwrap(locator.locate(
            expected: expected,
            recognizedWords: ["وقد", "كفروا", "بما", "جاءكم"]
        ))
        XCTAssertEqual(resumed.completedThrough.location, "60:1:16")
    }

    func testDoesNotEnterNextAyahBeforeCurrentFinalWord() throws {
        let expected = references([
            (1, ["start", "same1", "same2", "same3", "same4", "unfinished"]),
            (2, ["same1", "same2", "same3", "same4"])
        ], surah: 72)
        var locator = ProgressiveTranscriptLocator()

        let current = try XCTUnwrap(locator.locate(
            expected: expected,
            recognizedWords: ["start", "same1", "same2", "same3", "same4"]
        ))
        let prematureNextAyah = locator.locate(
            expected: expected,
            recognizedWords: ["same1", "same2", "same3", "same4"]
        )

        XCTAssertEqual(current.completedThrough.location, "72:1:5")
        XCTAssertNil(prematureNextAyah)
    }

    func testTimedEvidenceUsesOnlyWordsAfterCompletedAyahBoundary() throws {
        let expected = references([
            (1, ["start", "same1", "same2", "same3", "same4", "final"]),
            (2, ["same1", "same2", "same3", "same4"])
        ], surah: 72)
        var locator = ProgressiveTranscriptLocator()
        let firstWindow = [
            TranscriptWordEvidence(text: "start", sampleRange: 0..<10),
            TranscriptWordEvidence(text: "same1", sampleRange: 10..<20),
            TranscriptWordEvidence(text: "same2", sampleRange: 20..<30),
            TranscriptWordEvidence(text: "same3", sampleRange: 30..<40),
            TranscriptWordEvidence(text: "same4", sampleRange: 40..<50),
            TranscriptWordEvidence(text: "final", sampleRange: 50..<60),
            TranscriptWordEvidence(text: "same1", sampleRange: 60..<70),
            TranscriptWordEvidence(text: "same2", sampleRange: 70..<80),
            TranscriptWordEvidence(text: "same3", sampleRange: 80..<90),
            TranscriptWordEvidence(text: "same4", sampleRange: 90..<100)
        ]

        let completedFirstAyah = try XCTUnwrap(locator.locate(expected: expected, evidence: firstWindow))
        let completedSecondAyah = try XCTUnwrap(locator.locate(expected: expected, evidence: firstWindow))

        XCTAssertEqual(completedFirstAyah.completedThrough.location, "72:1:6")
        XCTAssertEqual(completedSecondAyah.completedThrough.location, "72:2:4")
    }

    func testTimedEvidenceRejectsStaleOverlapUntilNextAyahIsRecitedAgain() throws {
        let expected = references([
            (1, ["start", "same1", "same2", "same3", "same4", "final"]),
            (2, ["same1", "same2", "same3", "same4"])
        ], surah: 72)
        var locator = ProgressiveTranscriptLocator()

        _ = try XCTUnwrap(locator.locate(expected: expected, evidence: [
            TranscriptWordEvidence(text: "start", sampleRange: 0..<10),
            TranscriptWordEvidence(text: "same1", sampleRange: 10..<20),
            TranscriptWordEvidence(text: "same2", sampleRange: 20..<30),
            TranscriptWordEvidence(text: "same3", sampleRange: 30..<40),
            TranscriptWordEvidence(text: "same4", sampleRange: 40..<50),
            TranscriptWordEvidence(text: "final", sampleRange: 100..<110)
        ]))

        let stale = locator.locateWithOutcome(expected: expected, evidence: [
            TranscriptWordEvidence(text: "same1", sampleRange: 10..<20),
            TranscriptWordEvidence(text: "same2", sampleRange: 20..<30),
            TranscriptWordEvidence(text: "same3", sampleRange: 30..<40),
            TranscriptWordEvidence(text: "same4", sampleRange: 40..<50)
        ])
        let fresh = try XCTUnwrap(locator.locate(expected: expected, evidence: [
            TranscriptWordEvidence(text: "same1", sampleRange: 110..<120),
            TranscriptWordEvidence(text: "same2", sampleRange: 120..<130),
            TranscriptWordEvidence(text: "same3", sampleRange: 130..<140),
            TranscriptWordEvidence(text: "same4", sampleRange: 140..<150)
        ]))

        XCTAssertEqual(stale, .freshEvidenceRequired)
        XCTAssertEqual(fresh.completedThrough.location, "72:2:4")
    }

    func testContinuesProgressWithinLockedNeighborhood() throws {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 12
        )
        let expected = references([
            (1, ["سبح", "لله", "ما", "في", "السماوات", "وما", "في", "الارض"]),
            (2, ["هو", "الذي", "اخرج", "الذين", "كفروا"])
        ])

        _ = try XCTUnwrap(locator.locate(expected: expected, recognizedWords: ["سبح", "لله", "ما", "في"]))
        let completedCurrentAyah = try XCTUnwrap(locator.locate(
            expected: expected,
            recognizedWords: ["السماوات", "وما", "في", "الارض"]
        ))
        let nextLocation = try XCTUnwrap(locator.locate(expected: expected, recognizedWords: ["هو", "الذي", "اخرج", "الذين"]))

        XCTAssertEqual(completedCurrentAyah.completedThrough.location, "59:1:8")
        XCTAssertEqual(nextLocation.completedThrough.location, "59:2:4")
    }

    func testPostLockPrefersAdvancingMatchOverStrongerOldMatch() throws {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 12
        )
        let expected = references([
            (1, ["سبح", "لله", "ما", "في", "السماوات", "وما", "في", "الارض"]),
            (2, ["هو", "الذي", "اخرج", "الذين", "كفروا"])
        ])

        _ = try XCTUnwrap(locator.locate(expected: expected, recognizedWords: ["سبح", "لله", "ما", "في"]))
        let nextLocation = try XCTUnwrap(locator.locate(
            expected: expected,
            recognizedWords: ["سبح", "لله", "ما", "في", "حشو", "السماوات", "وما"]
        ))

        XCTAssertEqual(nextLocation.completedThrough.location, "59:1:6")
        XCTAssertEqual(nextLocation.matchedWordCount, 2)
    }

    func testInitialLockPrefersEarliestRepeatedPhraseInSelectedRange() throws {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 24
        )
        let expected = references([
            (1, ["يا", "ايها", "الذين", "امنوا", "اوفوا", "بالعقود"]),
            (2, ["حشو", "قريب"]),
            (106, ["يا", "ايها", "الذين", "امنوا", "شهادة", "بينكم"])
        ], surah: 5)

        let location = try XCTUnwrap(
            locator.locate(expected: expected, recognizedWords: ["بسم", "الله", "الرحمن", "الرحيم", "يا", "ايها", "الذين", "امنوا", "اف"])
        )

        XCTAssertEqual(location.completedThrough.location, "5:1:4")
    }

    func testPreparedIndexKeepsRepeatedLiveLocatesFast() throws {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 12,
            lookAheadWordCount: 96
        )
        let expected = longRepeatedReferences(wordCount: 6_000)
        let index = TranscriptPositionIndex(expected: expected)
        let firstChunk = Array(expected[0..<16].map(\.text))
        let liveChunks = (0..<360).map { iteration in
            let start = 4 + (iteration % 72)
            return Array(expected[start..<(start + 16)].map(\.text))
        }

        let firstLocation = try XCTUnwrap(locator.locate(index: index, recognizedWords: firstChunk))
        XCTAssertEqual(firstLocation.completedThrough.location, "2:1:10")
        XCTAssertEqual(firstLocation.matchedWordCount, 10)

        let startedAt = ContinuousClock.now
        for chunk in liveChunks {
            _ = locator.locate(index: index, recognizedWords: chunk)
        }
        let elapsed = startedAt.duration(to: .now)
        let milliseconds = Double(elapsed.components.seconds * 1_000)
            + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000

        XCTAssertLessThan(milliseconds, 120, "Prepared live locates took \(milliseconds)ms")
    }

    private func references(_ ayahs: [(Int, [String])], surah: Int = 59) -> [RecitationWordReference] {
        ayahs.flatMap { ayah, words in
            words.enumerated().map { offset, word in
                RecitationWordReference(surah: surah, ayah: ayah, wordIndex: offset + 1, text: word)
            }
        }
    }

    private func longRepeatedReferences(wordCount: Int) -> [RecitationWordReference] {
        precondition(wordCount > 0)
        let uniqueWords = (0..<64).map { "كلمة\($0)" }
        return (0..<wordCount).map { offset in
            RecitationWordReference(
                surah: 2,
                ayah: (offset / 10) + 1,
                wordIndex: (offset % 10) + 1,
                text: uniqueWords[offset % uniqueWords.count]
            )
        }
    }
}
