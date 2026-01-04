import SwiftUI
import Combine
import Foundation

struct TerminalView: View {
    let projectPath: String
    @StateObject private var vm = TerminalViewModel()
    @State private var inputCommand: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Output Area
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(vm.outputLines) { line in
                            Text(line.text)
                                .font(.monospaced(.body)())
                                .foregroundColor(line.isError ? .red : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
                .onChange(of: vm.outputLines.count) { _ in
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
                
                TextField("Enter command...", text: $inputCommand)
                    .font(.monospaced(.body)())
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
                    .onSubmit {
                        executeCommand()
                    }
                
                if vm.isRunning {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.horizontal, 4)
                }
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
        Task {
            await vm.runCommand(inputCommand)
            inputCommand = ""
            isInputFocused = true
        }
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
    private var process: Process?
    
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
        outputLines.append(ConsoleLine(text: text, isError: isError))
    }
}
