import SwiftData
import SwiftUI

@main
struct HifzTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Hifz Tracker", id: "recite") {
            RecitationRootView()
                .modelContainer(for: StoredSessionRecord.self)
                .frame(minWidth: 760, minHeight: 520)
        }
        .defaultSize(width: 1_180, height: 780)
        .commands {
            HifzTrackerCommands()
        }

        Window("Progress", id: "progress") {
            DashboardWindowView()
                .modelContainer(for: StoredSessionRecord.self)
                .frame(minWidth: 900, minHeight: 620)
        }

        Settings {
            SettingsView()
                .frame(width: 520, height: 300)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = AppASRFactory.warmedLiveService
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct HifzTrackerCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Recitation") {
            Button("Open Progress") {
                openWindow(id: "progress")
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }
}
