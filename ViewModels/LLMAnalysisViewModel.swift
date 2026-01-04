import Foundation
import OSLog

@MainActor
class LLMAnalysisViewModel: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisResult: String?
    @Published var errorMessage: String?

    private let llmService = LLMService.shared
    private let logger = Logger(subsystem: "com.gitmonitor", category: "LLMAnalysis")

    // MARK: - Analysis Methods

    func analyzeProjectBuild(
        projectName: String,
        buildOutput: String,
        buildStatus: LLMService.BuildStatus
    ) async {
        isAnalyzing = true
        analysisResult = nil
        errorMessage = nil

        logger.info("Starting build analysis for \(projectName)")

        do {
            let result = try await llmService.analyzeBuildOutput(
                projectName: projectName,
                buildOutput: buildOutput,
                buildStatus: buildStatus
            )

            analysisResult = result
            logger.info("Build analysis completed successfully")

        } catch {
            logger.error("Build analysis failed: \(error.localizedDescription)")
            errorMessage = "Analysis failed: \(error.localizedDescription)"
        }

        isAnalyzing = false
    }

    func analyzeCodeQuality(
        projectName: String,
        lintOutput: String,
        language: String
    ) async {
        isAnalyzing = true
        analysisResult = nil
        errorMessage = nil

        logger.info("Starting code quality analysis for \(projectName)")

        do {
            let result = try await llmService.analyzeCodeQuality(
                projectName: projectName,
                lintOutput: lintOutput,
                language: language
            )

            analysisResult = result
            logger.info("Code quality analysis completed successfully")

        } catch {
            logger.error("Code quality analysis failed: \(error.localizedDescription)")
            errorMessage = "Analysis failed: \(error.localizedDescription)"
        }

        isAnalyzing = false
    }

    func analyzeGitStatus(
        projectName: String,
        branch: String,
        hasChanges: Bool,
        modifiedFiles: [String],
        pendingPRs: Int
    ) async {
        isAnalyzing = true
        analysisResult = nil
        errorMessage = nil

        logger.info("Starting git status analysis for \(projectName)")

        do {
            let result = try await llmService.analyzeGitStatus(
                projectName: projectName,
                branch: branch,
                hasChanges: hasChanges,
                modifiedFiles: modifiedFiles,
                pendingPRs: pendingPRs
            )

            analysisResult = result
            logger.info("Git status analysis completed successfully")

        } catch {
            logger.error("Git status analysis failed: \(error.localizedDescription)")
            errorMessage = "Analysis failed: \(error.localizedDescription)"
        }

        isAnalyzing = false
    }

    // MARK: - Configuration

    var glmAPIKey: String {
        get {
            llmService.glmAPIKey
        }
        set {
            llmService.glmAPIKey = newValue
            llmService.saveConfiguration()
        }
    }

    var ollamaBaseURL: String {
        get {
            llmService.ollamaBaseURL
        }
        set {
            llmService.ollamaBaseURL = newValue
            llmService.saveConfiguration()
        }
    }

    var selectedModel: LLMService.LLMModel {
        get {
            llmService.selectedModel
        }
        set {
            llmService.selectedModel = newValue
            llmService.saveConfiguration()
        }
    }

    var ollamaModel: String {
        get {
            llmService.ollamaModel
        }
        set {
            llmService.ollamaModel = newValue
            llmService.saveConfiguration()
        }
    }

    // MARK: - Service Status

    var isGLMAvailable: Bool {
        llmService.isGLMAvailable
    }

    var isOllamaAvailable: Bool {
        llmService.isOllamaAvailable
    }
}
