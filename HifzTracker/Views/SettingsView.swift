import SwiftUI

enum RecognitionTranscriptPreference {
    static func storage(in store: UserDefaults? = nil) -> AppStorage<Bool> {
        AppStorage(wrappedValue: false, "showDebugTranscript", store: store)
    }
}

struct SettingsView: View {
    @AppStorage private var showDebugTranscript: Bool

    init() {
        _showDebugTranscript = RecognitionTranscriptPreference.storage()
    }

    var body: some View {
        Form {
            Toggle("Show recognition transcript", isOn: $showDebugTranscript)
                .help("Display the words recognized during recitation")

            Section("Recitation data") {
                LabeledContent("Speech recognition", value: "Offline, on this Mac")
                LabeledContent("Saved on this Mac", value: "Recitation progress")
                LabeledContent("Microphone audio", value: "Kept in memory during recitation")
            }
        }
        .formStyle(.grouped)
        .scenePadding()
    }
}
