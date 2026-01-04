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
        case .iterm: return "com.googlecode.iterm2"
        case .warp: return "dev.warp.Warp"
        case .ghostty: return "com.mitchellh.ghostty" // Verify ID if possible, common guess
        case .hyper: return "co.zeit.hyper"
        }
    }
}

class SettingsStore: ObservableObject {
    @AppStorage("preferredTerminal") var preferredTerminal: TerminalApp = .terminal
}
