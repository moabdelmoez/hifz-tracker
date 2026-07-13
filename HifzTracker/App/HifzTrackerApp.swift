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

        Window("Dashboard", id: "dashboard") {
            DashboardWindowView()
                .modelContainer(for: StoredSessionRecord.self)
                .frame(minWidth: 620, minHeight: 420)
        }

        Settings {
            SettingsView()
                .frame(width: 520, height: 300)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct HifzTrackerCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Recitation") {
            Button("Open Dashboard") {
                openWindow(id: "dashboard")
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }
}
