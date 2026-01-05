import SwiftUI

@main
struct GitMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var viewModel = ProjectScannerViewModel()

    var body: some Scene {
        WindowGroup {
            ProjectListView()
                .environmentObject(themeManager)
                .environmentObject(viewModel)
                .preferredColorScheme(themeManager.currentTheme.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)

        Settings {
            SettingsView(themeManager: themeManager)
        }

        MenuBarExtra("GitMonitor", systemImage: "arrow.triangle.branch") {
            MenuBarContentView(viewModel: viewModel)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent app from terminating when last window is closed
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Create and show a new window if none exist
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
}
