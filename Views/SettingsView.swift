import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = LLMAnalysisViewModel()

    init() {}

    var body: some View {
        TabView {
            generalSettings
            llmSettings
        }
        .frame(width: 500, height: 400)
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General")
                .font(.title2)
                .fontWeight(.bold)

            GroupBox(label: Label("About", systemImage: "info.circle.fill")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Name:")
                            .foregroundColor(.secondary)
                        Text("GitMonitor")
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text("Version:")
                            .foregroundColor(.secondary)
                        Text("1.0.0")
                            .fontWeight(.semibold)
                    }

                    Divider()

                    Text("A macOS application for monitoring multiple Git projects with AI-powered analysis.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .tabItem {
            Label("General", systemImage: "gear")
        }
    }

    private var llmSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("AI Configuration")
                .font(.title2)
                .fontWeight(.bold)

            GroupBox(label: Label("Model Selection", systemImage: "brain")) {
                Picker("Select LLM Model", selection: Binding(
                    get: { viewModel.selectedModel },
                    set: { viewModel.selectedModel = $0 }
                )) {
                    ForEach(LLMService.LLMModel.allCases, id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.radioGroup)

                Divider()

                switch viewModel.selectedModel {
                case .glm:
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GLM-4.7 Configuration")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("API Key")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            SecureField("Enter your GLM-4.7 API key", text: $viewModel.glmAPIKey)
                                .textFieldStyle(.roundedBorder)

                            Link("Get API Key", destination: URL(string: "https://open.bigmodel.cn/")!)
                                .font(.caption)
                        }
                    }

                case .ollama:
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ollama Configuration")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Base URL")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextField("Ollama server URL", text: $viewModel.ollamaBaseURL)
                                .textFieldStyle(.roundedBorder)

                            if viewModel.isOllamaAvailable {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Ollama service is running")
                                        .font(.caption)
                                }
                            } else {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text("Cannot connect to Ollama")
                                        .font(.caption)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Model Name")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextField("e.g., codellama, mistral", text: $viewModel.ollamaModel)
                                .textFieldStyle(.roundedBorder)

                            Link("Download Models", destination: URL(string: "https://ollama.ai/library")!)
                                .font(.caption)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
        .tabItem {
            Label("AI Settings", systemImage: "brain")
        }
    }
}

#Preview {
    SettingsView()
}
