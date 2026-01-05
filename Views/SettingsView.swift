import SwiftUI

struct SettingsView: View {
    @ObservedObject var themeManager: ThemeManager
    @StateObject private var settings = SettingsStore()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView {
            GeneralSettingsView(themeManager: themeManager, settings: settings)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(width: 450, height: 300)
        .onAppear {
            setupKeyboardShortcuts()
        }
    }

    private func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // ESC key
                dismiss()
                return nil
            }
            return event
        }
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var settings: SettingsStore
    
    var body: some View {
        VStack(spacing: 0) {
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
                    .onChange(of: settings.preferredTerminal) { _, newValue in
                        settings.setPreferredTerminal(newValue)
                    }
                } header: {
                    Text("Integrations")
                } footer: {
                    Text("Choose your preferred external terminal application.")
                }
            }
            .padding()
            
            if settings.showSavedIndicator {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(settings.saveMessage)
                        .font(.caption)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
