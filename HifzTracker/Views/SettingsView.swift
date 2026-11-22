import SwiftUI

struct SettingsView: View {
    @AppStorage("showDebugTranscript") private var showDebugTranscript = true

    var body: some View {
        TabView {
            Form {
                Section("Display") {
                    Toggle("Show recognition transcript", isOn: $showDebugTranscript)
                        .help("Display the words recognized during recitation")
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            Form {
                Section("Recitation data") {
                    LabeledContent("Speech recognition", value: "Offline, on this Mac")
                    LabeledContent("Saved on this Mac", value: "Recitation progress")
                    LabeledContent("Microphone audio", value: "Kept in memory during recitation")
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Privacy", systemImage: "hand.raised")
            }
        }
        .scenePadding()
    }
}
