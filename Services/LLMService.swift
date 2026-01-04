import Foundation

/// Singleton service for LLM integration (BYOK - Bring Your Own Key)
@MainActor
class LLMService: ObservableObject {
    static let shared = LLMService()

    // MARK: - Published Properties

    @Published var isGLMAvailable = false
    @Published var isOllamaAvailable = false
    @Published var glmAPIKey: String = ""
    @Published var ollamaBaseURL: String = "http://localhost:11434"
    @Published var selectedModel: LLMModel = .glm
    @Published var ollamaModel: String = "codellama"

    // MARK: - Types

    enum LLMModel: String, CaseIterable {
        case glm = "GLM-4.7"
        case ollama = "Ollama (Local)"

        var displayName: String {
            rawValue
        }
    }

    enum LLMError: Error, LocalizedError {
        case noAPIKey
        case serviceUnavailable
        case invalidResponse
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "API key not configured"
            case .serviceUnavailable:
                return "LLM service is not available"
            case .invalidResponse:
                return "Invalid response from LLM service"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Configuration

    private init() {
        loadConfiguration()
        checkAvailability()
    }

    private func loadConfiguration() {
        // Load from UserDefaults or environment variables
        if let key = UserDefaults.standard.string(forKey: "glm_api_key") {
            self.glmAPIKey = key
        }

        if let ollamaURL = UserDefaults.standard.string(forKey: "ollama_base_url") {
            self.ollamaBaseURL = ollamaURL
        }

        if let model = UserDefaults.standard.string(forKey: "selected_model"),
           let llmModel = LLMModel(rawValue: model) {
            self.selectedModel = llmModel
        }

        if let ollamaModel = UserDefaults.standard.string(forKey: "ollama_model") {
            self.ollamaModel = ollamaModel
        }
    }

    func saveConfiguration() {
        UserDefaults.standard.set(glmAPIKey, forKey: "glm_api_key")
        UserDefaults.standard.set(ollamaBaseURL, forKey: "ollama_base_url")
        UserDefaults.standard.set(selectedModel.rawValue, forKey: "selected_model")
        UserDefaults.standard.set(ollamaModel, forKey: "ollama_model")
    }

    private func checkAvailability() {
        // Check GLM API key
        isGLMAvailable = !glmAPIKey.isEmpty

        // Check Ollama availability asynchronously
        Task {
            await checkOllamaAvailability()
        }
    }

    private func checkOllamaAvailability() async {
        do {
            let url = URL(string: "\(ollamaBaseURL)/api/tags")!
            let (_, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse {
                isOllamaAvailable = httpResponse.statusCode == 200
            }
        } catch {
            isOllamaAvailable = false
        }
    }

    // MARK: - Analysis Methods

    /// Analyze project build output and provide suggestions
    func analyzeBuildOutput(
        projectName: String,
        buildOutput: String,
        buildStatus: BuildStatus
    ) async throws -> String {
        let prompt = buildAnalysisPrompt(
            projectName: projectName,
            buildOutput: buildOutput,
            buildStatus: buildStatus
        )

        return try await generateResponse(prompt: prompt)
    }

    /// Analyze code quality and linting issues
    func analyzeCodeQuality(
        projectName: String,
        lintOutput: String,
        language: String
    ) async throws -> String {
        let prompt = codeQualityPrompt(
            projectName: projectName,
            lintOutput: lintOutput,
            language: language
        )

        return try await generateResponse(prompt: prompt)
    }

    /// Analyze git status and provide recommendations
    func analyzeGitStatus(
        projectName: String,
        branch: String,
        hasChanges: Bool,
        modifiedFiles: [String],
        pendingPRs: Int
    ) async throws -> String {
        let prompt = gitStatusPrompt(
            projectName: projectName,
            branch: branch,
            hasChanges: hasChanges,
            modifiedFiles: modifiedFiles,
            pendingPRs: pendingPRs
        )

        return try await generateResponse(prompt: prompt)
    }

    // MARK: - Private Methods

    private func generateResponse(prompt: String) async throws -> String {
        switch selectedModel {
        case .glm:
            return try await callGLMAPI(prompt: prompt)
        case .ollama:
            return try await callOllamaAPI(prompt: prompt)
        }
    }

    // MARK: - GLM-4.7 API

    private func callGLMAPI(prompt: String) async throws -> String {
        guard !glmAPIKey.isEmpty else {
            throw LLMError.noAPIKey
        }

        // Note: This is a generic structure for GLM API
        // Adjust based on actual GLM-4.7 API documentation
        let url = URL(string: "https://open.bigmodel.cn/api/paas/v4/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(glmAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "glm-4",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 2000
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw LLMError.serviceUnavailable
            }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content
            }

            throw LLMError.invalidResponse
        } catch let error as LLMError {
            throw error
        } catch {
            throw LLMError.networkError(error)
        }
    }

    // MARK: - Ollama API

    private func callOllamaAPI(prompt: String) async throws -> String {
        guard isOllamaAvailable else {
            throw LLMError.serviceUnavailable
        }

        let url = URL(string: "\(ollamaBaseURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": ollamaModel,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": 0.7,
                "num_predict": 2000
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw LLMError.serviceUnavailable
            }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let response = json["response"] as? String {
                return response
            }

            throw LLMError.invalidResponse
        } catch let error as LLMError {
            throw error
        } catch {
            throw LLMError.networkError(error)
        }
    }

    // MARK: - Prompt Templates

    private func buildAnalysisPrompt(
        projectName: String,
        buildOutput: String,
        buildStatus: BuildStatus
    ) -> String {
        return """
        You are a senior software engineer analyzing build output for project: \(projectName)

        Build Status: \(buildStatus)

        Build Output:
        \(buildOutput)

        Please provide:
        1. A summary of what went wrong (if applicable)
        2. Root cause analysis
        3. Specific recommendations to fix the issues
        4. Priority level (Critical/High/Medium/Low)

        Keep the response concise and actionable.
        """
    }

    private func codeQualityPrompt(
        projectName: String,
        lintOutput: String,
        language: String
    ) -> String {
        return """
        You are a code quality expert analyzing linting output for project: \(projectName)

        Language: \(language)

        Lint Output:
        \(lintOutput)

        Please provide:
        1. Most critical issues to address first
        2. Patterns in the issues that suggest systemic problems
        3. Recommendations for preventing these issues in the future
        4. Estimated effort to fix (High/Medium/Low)

        Keep the response concise and actionable.
        """
    }

    private func gitStatusPrompt(
        projectName: String,
        branch: String,
        hasChanges: Bool,
        modifiedFiles: [String],
        pendingPRs: Int
    ) -> String {
        return """
        You are a DevOps expert analyzing Git status for project: \(projectName)

        Current Branch: \(branch)
        Has Uncommitted Changes: \(hasChanges)
        Modified Files: \(modifiedFiles.joined(separator: ", "))
        Pending Pull Requests: \(pendingPRs)

        Please provide:
        1. Assessment of current branch hygiene
        2. Recommendations for managing uncommitted changes
        3. Advice on pending PRs
        4. Best practices to maintain

        Keep the response concise and actionable.
        """
    }

    enum BuildStatus: String {
        case success
        case failed
        case warning
    }
}
