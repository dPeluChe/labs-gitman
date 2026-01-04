import SwiftUI

struct SettingsView: View {
    @ObservedObject var themeManager: ThemeManager
    @StateObject private var settings = SettingsStore()
    
    var body: some View {
        TabView {
            GeneralSettingsView(themeManager: themeManager, settings: settings)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var settings: SettingsStore
    
    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $themeManager.currentTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Label(theme.rawValue, systemImage: theme.icon)
                            .tag(theme)
                    }
                }
                .pickerStyle(.inline)
            } header: {
                Text("Display")
            }
            
            Section {
                Picker("Terminal App", selection: $settings.preferredTerminal) {
                    ForEach(TerminalApp.allCases) { app in
                        Text(app.rawValue).tag(app)
                    }
                }
            } header: {
                Text("Integrations")
            } footer: {
                Text("Choose your preferred external terminal application.")
            }
        }
        .padding()
    }
}
