import SwiftUI

struct SettingsView: View {
    @ObservedObject var themeManager = ThemeManager()
    
    var body: some View {
        TabView {
            GeneralSettingsView(themeManager: themeManager)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(width: 450, height: 250)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var themeManager: ThemeManager
    
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
            } footer: {
                Text("Choose your preferred appearance style.")
            }
        }
        .padding()
    }
}
