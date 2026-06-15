import Foundation

public enum QuranTextNormalizer {
    public static func asrComparable(_ text: String) -> String {
        let mappedScalars = text.unicodeScalars.compactMap { scalar -> UnicodeScalar? in
            if shouldDrop(scalar) {
                return nil
            }
            return replacements[scalar.value] ?? scalar
        }

        let mapped = String(String.UnicodeScalarView(mappedScalars))
        return mapped
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static let replacements: [UInt32: UnicodeScalar] = [
        0x0671: "ا",
        0x0622: "ا",
        0x0623: "ا",
        0x0625: "ا"
    ]

    private static func shouldDrop(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x0640, 0x0610...0x061A, 0x064B...0x065F, 0x0670, 0x06D6...0x06ED:
            return true
        default:
            return false
        }
    }
}
