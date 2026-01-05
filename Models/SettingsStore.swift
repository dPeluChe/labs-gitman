import SwiftUI

enum TerminalApp: String, CaseIterable, Identifiable {
    case terminal = "Terminal"
    case iterm = "iTerm2"
    case warp = "Warp"
    case ghostty = "Ghostty"
    case hyper = "Hyper"
    
    var id: String { rawValue }
    
    var bundleIdentifier: String {
        switch self {
        case .terminal: return "com.apple.Terminal"
        case .iterm: return "com.googlecode.iTerm2"  // Fixed: capital 'I'
        case .warp: return "dev.warp.Warp"
        case .ghostty: return "com.mitchellh.ghostty"
        case .hyper: return "co.zeit.hyper"
        }
    }
}

class SettingsStore: ObservableObject {
    @AppStorage("preferredTerminal") var preferredTerminal: TerminalApp = .terminal
    @Published var showSavedIndicator = false
    @Published var saveMessage = ""
    
    func setPreferredTerminal(_ terminal: TerminalApp) {
        preferredTerminal = terminal
        showSavedFeedback("Terminal preference updated")
    }
    
    private func showSavedFeedback(_ message: String) {
        saveMessage = message
        withAnimation {
            showSavedIndicator = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                self.showSavedIndicator = false
            }
        }
    }
}
