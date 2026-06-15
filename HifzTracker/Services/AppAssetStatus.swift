import Foundation

enum AppAssetStatus {
    static func summary(bundle: Bundle = .main) -> String? {
        let required = [
            ("Quran DB", "qpc-v4", "db"),
            ("Tanzil text", "quran-simple-clean", "txt")
        ]

        let missing = required.compactMap { name, resource, ext in
            bundle.url(forResource: resource, withExtension: ext) == nil ? name : nil
        }

        var messages: [String] = []
        if !missing.isEmpty {
            messages.append("Missing bundled Quran assets: \(missing.joined(separator: ", "))")
        }

        let releaseAssets = [
            ("model_fp32", "onnx", "Models"),
            ("tokenizer", "json", "Tokenizer"),
            ("tokenizer", "model", "Tokenizer"),
            ("tokenizer_config", "json", "Tokenizer"),
            ("tokens", "txt", "Tokenizer"),
            ("model_config", "yaml", "Tokenizer"),
            ("kfgqpc-v4-layout", "sqlite", "Layout")
        ]
        let missingReleaseAssets = releaseAssets.filter { name, ext, subdirectory in
            bundle.url(forResource: name, withExtension: ext, subdirectory: subdirectory) == nil
        }
        let missingFontPack = (1...604).contains { page in
            bundle.url(forResource: "p\(page)", withExtension: "ttf", subdirectory: "Fonts") == nil
        }
        if !missingReleaseAssets.isEmpty || missingFontPack {
            messages.append("Real ASR/page assets not installed; manual smoke controls are enabled.")
        }

        return messages.isEmpty ? nil : messages.joined(separator: " ")
    }
}
