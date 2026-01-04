import SwiftUI

struct LLMAnalysisSheet: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel = LLMAnalysisViewModel()
    @State private var selectedAnalysisType: AnalysisType = .gitStatus
    @State private var inputText = ""

    init(project: Project) {
        self.project = project
    }

    private enum AnalysisType: String, CaseIterable {
        case gitStatus = "Git Status"
        case buildOutput = "Build Output"
        case codeQuality = "Code Quality"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Analysis type picker
                Picker("Analysis Type", selection: $selectedAnalysisType) {
                    ForEach(AnalysisType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                // Input section based on type
                inputSection

                // LLM Configuration
                llmConfigSection

                Spacer()

                // Result section
                if let result = viewModel.analysisResult {
                    resultSection(result)
                } else if viewModel.isAnalyzing {
                    ProgressView("Analyzing...")
                        .padding()
                }

                // Action buttons
                HStack(spacing: 12) {
                    Button("Close") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button("Analyze") {
                        Task {
                            await performAnalysis()
                        }
                    }
                    .disabled(!canAnalyze)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 700, height: 600)
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    @ViewBuilder
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(inputLabel)
                .font(.subheadline)
                .fontWeight(.semibold)

            switch selectedAnalysisType {
            case .gitStatus:
                gitStatusInput
            case .buildOutput:
                buildInput
            case .codeQuality:
                codeQualityInput
            }
        }
    }

    private var inputLabel: String {
        switch selectedAnalysisType {
        case .gitStatus:
            return "Git Status Information"
        case .buildOutput:
            return "Build Output"
        case .codeQuality:
            return "Linting Output"
        }
    }

    @ViewBuilder
    private var gitStatusInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let status = project.gitStatus {
                HStack {
                    Text("Branch:")
                        .foregroundColor(.secondary)
                    Text(status.currentBranch)
                        .fontWeight(.semibold)
                }

                Toggle("Has Uncommitted Changes", isOn: .constant(status.hasUncommittedChanges))
                    .disabled(true)

                if status.hasUncommittedChanges {
                    Text("Modified Files:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(status.modifiedFiles, id: \.self) { file in
                        Text("• \(file)")
                            .font(.caption)
                            .padding(.leading, 8)
                    }
                }

                HStack {
                    Text("Pending PRs:")
                        .foregroundColor(.secondary)
                    Text("\(status.pendingPullRequests)")
                        .fontWeight(.semibold)
                }
            } else {
                Text("No Git status available for this project")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var buildInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paste build output below:")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $inputText)
                .font(.system(.caption, design: .monospaced))
                .frame(height: 150)
                .background(Color(.textBackgroundColor))
                .cornerRadius(6)
        }
    }

    @ViewBuilder
    private var codeQualityInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Language:")
                    .foregroundColor(.secondary)

                Picker("Language", selection: .constant("Swift")) {
                    Text("Swift").tag("Swift")
                    Text("JavaScript").tag("JavaScript")
                    Text("Python").tag("Python")
                    Text("TypeScript").tag("TypeScript")
                }
                .pickerStyle(.menu)
            }

            Text("Paste linting output below:")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $inputText)
                .font(.system(.caption, design: .monospaced))
                .frame(height: 150)
                .background(Color(.textBackgroundColor))
                .cornerRadius(6)
        }
    }

    @ViewBuilder
    private var llmConfigSection: some View {
        GroupBox(label: Label("LLM Configuration", systemImage: "brain")) {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Model", selection: Binding(
                    get: { viewModel.selectedModel },
                    set: { viewModel.selectedModel = $0 }
                )) {
                    ForEach(LLMService.LLMModel.allCases, id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }

                switch viewModel.selectedModel {
                case .glm:
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GLM-4.7 API Key")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        SecureField("Enter API key", text: $viewModel.glmAPIKey)
                            .textFieldStyle(.roundedBorder)

                        if !viewModel.isGLMAvailable {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                Text("API key not configured")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }

                case .ollama:
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ollama Base URL")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("Enter URL", text: $viewModel.ollamaBaseURL)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            if viewModel.isOllamaAvailable {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Connected")
                                    .font(.caption)
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("Not available")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func resultSection(_ result: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Analysis Result")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(result)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
            }
        }
    }

    private var canAnalyze: Bool {
        switch selectedAnalysisType {
        case .gitStatus:
            return project.gitStatus != nil
        case .buildOutput, .codeQuality:
            return !inputText.isEmpty
        }
    }

    private func performAnalysis() async {
        switch selectedAnalysisType {
        case .gitStatus:
            if let status = project.gitStatus {
                await viewModel.analyzeGitStatus(
                    projectName: project.name,
                    branch: status.currentBranch,
                    hasChanges: status.hasUncommittedChanges,
                    modifiedFiles: status.modifiedFiles,
                    pendingPRs: status.pendingPullRequests
                )
            }

        case .buildOutput:
            let buildStatus: LLMService.BuildStatus = inputText.contains("error")
                ? .failed
                : inputText.contains("warning")
                ? .warning
                : .success

            await viewModel.analyzeProjectBuild(
                projectName: project.name,
                buildOutput: inputText,
                buildStatus: buildStatus
            )

        case .codeQuality:
            await viewModel.analyzeCodeQuality(
                projectName: project.name,
                lintOutput: inputText,
                language: "Swift"
            )
        }
    }
}

#Preview {
    LLMAnalysisSheet(
        project: Project(
            path: "/Users/test/project",
            name: "Test Project"
        )
    )
}
