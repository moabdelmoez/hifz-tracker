import Foundation

public enum MushafFontResolver {
    public static func qpcV4TajweedFontName(pageNumber: Int) -> String {
        let pageCode = String(format: "%03d", pageNumber)
        let regularSuffix = pageNumber >= 6 ? "-Regular" : ""
        return "QCF4\(pageCode)_COLOR\(regularSuffix)"
    }

    public static func qpcV4TajweedFontFileName(pageNumber: Int) -> String {
        "p\(pageNumber).ttf"
    }
}
