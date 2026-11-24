import SwiftData
import SwiftUI

@main
struct HifzTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Hifz Tracker", id: "recite") {
            RecitationRootView { openWindow in
                appDelegate.openRecitationWindow = { openWindow(id: "recite") }
            }
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
                .frame(width: 520, height: 230)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var openRecitationWindow: (() -> Void)?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        guard !hasVisibleWindows, let openRecitationWindow else { return true }
        openRecitationWindow()
        return false
    }

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
