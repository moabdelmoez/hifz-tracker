import Foundation

public enum QuranReferenceWords {
    public static func wordsForAyah(_ text: String, surah: Int, ayah: Int) -> [String] {
        var words = QuranTextNormalizer
            .asrComparable(text)
            .split(separator: " ")
            .map(String.init)

        let basmallah = ["بسم", "الله", "الرحمن", "الرحيم"]
        if surah != 1, ayah == 1, words.starts(with: basmallah) {
            words.removeFirst(basmallah.count)
        }

        return words
    }
}
