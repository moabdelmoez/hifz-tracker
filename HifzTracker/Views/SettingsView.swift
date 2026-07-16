import SwiftUI

struct SettingsView: View {
    @AppStorage("showDebugTranscript") private var showDebugTranscript = true

    var body: some View {
        TabView {
            Form {
                Section("Display") {
                    Toggle("Show debug transcript", isOn: $showDebugTranscript)
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            Form {
                Section("Privacy & Runtime") {
                    LabeledContent("ASR", value: "Offline ONNX Runtime CPU")
                    LabeledContent("Audio storage", value: "Metadata only")
                    LabeledContent("Network", value: "Disabled")
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
