import Foundation

public struct MushafFontResolver: Equatable, Sendable {
    public var filePrefix: String
    public var fileExtension: String
    public var postScriptPrefix: String
    public var postScriptSuffix: String
    public var regularSuffixStartPage: Int

    public static let qpcV4Tajweed = MushafFontResolver(
        filePrefix: "p",
        fileExtension: "ttf",
        postScriptPrefix: "QCF4",
        postScriptSuffix: "_COLOR",
        regularSuffixStartPage: 6
    )

    public init(
        filePrefix: String,
        fileExtension: String,
        postScriptPrefix: String,
        postScriptSuffix: String,
        regularSuffixStartPage: Int
    ) {
        self.filePrefix = filePrefix
        self.fileExtension = fileExtension
        self.postScriptPrefix = postScriptPrefix
        self.postScriptSuffix = postScriptSuffix
        self.regularSuffixStartPage = regularSuffixStartPage
    }

    public func fontName(pageNumber: Int) -> String {
        let pageCode = String(format: "%03d", pageNumber)
        let regularSuffix = pageNumber >= regularSuffixStartPage ? "-Regular" : ""
        return "\(postScriptPrefix)\(pageCode)\(postScriptSuffix)\(regularSuffix)"
    }

    public func fontFileName(pageNumber: Int) -> String {
        "\(filePrefix)\(pageNumber).\(fileExtension)"
    }
}
