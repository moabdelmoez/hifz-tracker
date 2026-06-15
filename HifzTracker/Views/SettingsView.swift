import SwiftUI

struct SettingsView: View {
    @AppStorage("preferredInputDeviceID") private var preferredInputDeviceID = "system-default"
    @AppStorage("showDebugTranscript") private var showDebugTranscript = true

    var body: some View {
        TabView {
            Form {
                Picker("Microphone", selection: $preferredInputDeviceID) {
                    Text("System Default").tag("system-default")
                }
                Toggle("Show debug transcript", isOn: $showDebugTranscript)
            }
            .formStyle(.grouped)
            .padding()
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Runtime")
                    .font(.headline)
                LabeledContent("ASR", value: "Offline ONNX Runtime CPU")
                LabeledContent("Audio storage", value: "Metadata only")
                LabeledContent("Network", value: "Disabled")
                Spacer()
            }
            .padding()
            .tabItem {
                Label("Privacy", systemImage: "hand.raised")
            }
        }
        .scenePadding()
    }
}
