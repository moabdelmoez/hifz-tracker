import CoreText
import Foundation
import OSLog

private let mushafFontLogger = Logger(subsystem: "dev.mostafa.HifzTracker", category: "MushafFont")

enum MushafFontRegistrar {
    static func registerBundledQPCV4TajweedFonts(bundle: Bundle = .main, fileManager: FileManager = .default) {
        guard let fontsDirectory = bundle.url(forResource: "Fonts", withExtension: nil) else {
            mushafFontLogger.notice("QPC V4 Tajweed fonts directory is not bundled")
            return
        }

        let fontURLs: [URL]
        do {
            fontURLs = try fileManager.contentsOfDirectory(
                at: fontsDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            .filter { $0.pathExtension.lowercased() == "ttf" && $0.lastPathComponent.hasPrefix("p") }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        } catch {
            mushafFontLogger.error("Unable to list QPC V4 Tajweed fonts: \(error.localizedDescription, privacy: .public)")
            return
        }

        guard !fontURLs.isEmpty else {
            mushafFontLogger.notice("No QPC V4 Tajweed page fonts found in bundle")
            return
        }

        var registeredCount = 0
        for fontURL in fontURLs {
            var registrationError: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &registrationError) {
                registeredCount += 1
            } else if let error = registrationError?.takeRetainedValue() {
                mushafFontLogger.error("Unable to register \(fontURL.lastPathComponent, privacy: .public): \(CFErrorCopyDescription(error) as String, privacy: .public)")
            }
        }

        mushafFontLogger.info("Registered \(registeredCount, privacy: .public) QPC V4 Tajweed page fonts")
    }
}
