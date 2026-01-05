import SwiftUI
import Combine
import Foundation
import AppKit

// Custom TextField to handle arrow keys
struct TerminalTextField: NSViewRepresentable {
    @Binding var text: String
    var onCommit: () -> Void
    var onHistoryUp: () -> Void
    var onHistoryDown: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.focusRingType = .none
        textField.isBordered = false
        textField.drawsBackground = false
        textField.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: TerminalTextField

        init(_ parent: TerminalTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onCommit()
                return true
            } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
                parent.onHistoryUp()
                return true
            } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
                parent.onHistoryDown()
                return true
            }
            return false
        }
    }
}

struct TerminalView: View {
    let projectPath: String
    @StateObject private var vm = TerminalViewModel()
    @StateObject private var settings = SettingsStore()
    @State private var inputCommand: String = ""
    @State private var history: [String] = []
    @State private var historyIndex = -1
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Output Area
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if vm.outputLines.isEmpty {
                            // Empty state placeholder
                            VStack(spacing: 12) {
                                Spacer()
                                Image(systemName: "terminal")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                Text("Terminal Ready")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Type a command below or use quick actions")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(vm.outputLines) { line in
                                    Text(line.text)
                                        .font(.monospaced(.body)())
                                        .foregroundColor(line.isError ? .red : .primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: vm.outputLines.count) { oldValue, newValue in
                    if let last = vm.outputLines.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .background(Color.black)
            .foregroundColor(.white)
            
            // Input Area
            HStack {
                Text(">")
                    .font(.monospaced(.body)())

                TerminalTextField(
                    text: $inputCommand,
                    onCommit: executeCommand,
                    onHistoryUp: historyUp,
                    onHistoryDown: historyDown
                )
                .focused($isInputFocused)
                .frame(height: 20)
                .onAppear {
                    isInputFocused = true
                }

                if vm.isRunning {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.horizontal, 4)
                }

                // Open in External Terminal button
                Button(action: openExternalTerminal) {
                    Image(systemName: "terminal")
                        .font(.system(size: 14))
                }
                .help("Open in \(settings.preferredTerminal.rawValue)")
                .buttonStyle(.borderless)
            }
            .padding(10)
            .background(Color(.controlBackgroundColor))

            // Usage Toolbar (Common Commands)
            HStack {
                quickAction("Git Status", cmd: "git status")
                quickAction("Git Log", cmd: "git log --oneline -n 10")
                quickAction("List Files", cmd: "ls -la")
                quickAction("Build", cmd: "swift build")
                Spacer()

                Button("Clear") { vm.clear() }
                    .font(.caption)

                Button("Open External") { openExternalTerminal() }
                    .font(.caption)
            }
            .padding(8)
            .background(Color(.windowBackgroundColor))
        }
        .onAppear {
            vm.setWorkingDirectory(projectPath)
        }
    }
    
    private func quickAction(_ label: String, cmd: String) -> some View {
        Button(label) {
            inputCommand = cmd
            executeCommand()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(vm.isRunning)
    }
    
    private func executeCommand() {
        guard !inputCommand.isEmpty else { return }
        
        // Add to history if unique or last
        if history.last != inputCommand {
            history.append(inputCommand)
        }
        historyIndex = history.count // Reset index to end
        
        let cmd = inputCommand
        Task {
            // Clear input immediately for feel, but ideally after run? No, clear is standard.
            inputCommand = ""
            await vm.runCommand(cmd)
        }
    }
    
    // MARK: - History Handling
    
    private func historyUp() {
        guard !history.isEmpty else { return }
        if historyIndex == -1 { historyIndex = history.count } // Start from end
        
        if historyIndex > 0 {
            historyIndex -= 1
            inputCommand = history[historyIndex]
        }
    }
    
    private func historyDown() {
        guard !history.isEmpty else { return }
        
        if historyIndex < history.count - 1 {
            historyIndex += 1
            inputCommand = history[historyIndex]
        } else {
            // Back to empty if we go past last
            historyIndex = history.count
            inputCommand = ""
        }
    }

    private func openExternalTerminal() {
        let app = settings.preferredTerminal
        let script = "open -a \"\(app.bundleIdentifier)\" \"\(projectPath)\""
        
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", script]
        task.launch()
    }
}

struct ConsoleLine: Identifiable {
    let id = UUID()
    let text: String
    let isError: Bool
}

@MainActor
class TerminalViewModel: ObservableObject {
    @Published var outputLines: [ConsoleLine] = []
    @Published var isRunning = false
    
    private var workingDirectory: String = ""
    
    func setWorkingDirectory(_ path: String) {
        self.workingDirectory = path
    }
    
    func clear() {
        outputLines.removeAll()
    }
    
    func runCommand(_ command: String) async {
        isRunning = true
        appendLog("> \(command)", isError: false)
        
        let task = Process()
        task.currentDirectoryPath = workingDirectory
        task.launchPath = "/bin/zsh"
        // Use login shell to ensure PATH users env is loaded
        task.arguments = ["-l", "-c", command]
        
        let pipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = pipe
        task.standardError = errorPipe
        
        do {
            try task.run()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errData, encoding: .utf8) ?? ""
            
            if !output.isEmpty {
                for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
                    appendLog(String(line), isError: false)
                }
            }
            
            if !errorOutput.isEmpty {
                for line in errorOutput.split(separator: "\n", omittingEmptySubsequences: false) {
                    appendLog(String(line), isError: true)
                }
            }
            
        } catch {
             appendLog("Failed to run command: \(error.localizedDescription)", isError: true)
        }
        
        isRunning = false
    }
    
    private func appendLog(_ text: String, isError: Bool) {
        // Ensure UI updates on main thread
        outputLines.append(ConsoleLine(text: text, isError: isError))
    }
}
