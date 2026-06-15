import Foundation
import HifzCore

enum AppQuranRepositoryFactory {
    static func makeRepository(bundle: Bundle = .main) -> SQLiteQuranRepository? {
        guard
            let databaseURL = bundle.url(forResource: "qpc-v4", withExtension: "db"),
            let tanzilURL = bundle.url(forResource: "quran-simple-clean", withExtension: "txt")
        else {
            return nil
        }

        let layoutURL = bundle.url(
            forResource: "kfgqpc-v4-layout",
            withExtension: "sqlite",
            subdirectory: "Layout"
        )
        let pageMapping = layoutURL.flatMap {
            try? PageMapping.loadKFGQPCV4Layout(layoutDatabaseURL: $0, qpcDatabaseURL: databaseURL)
        } ?? .fallback

        return try? SQLiteQuranRepository(
            databaseURL: databaseURL,
            tanzilURL: tanzilURL,
            pageMapping: pageMapping,
            layoutDatabaseURL: layoutURL
        )
    }
}
