import Foundation

/// Service for interacting with Git and GitHub CLI
actor GitService {
    private let fileManager = FileManager.default
    private let processExecutor = ProcessExecutor()

    // MARK: - Git Repository Detection

    func isGitRepository(at path: String) -> Bool {
        let gitPath = (path as NSString).appendingPathComponent(".git")
        return fileManager.fileExists(atPath: gitPath)
    }

    // MARK: - GitHub Detection

    func isGitHubRepository(at path: String) async -> Bool {
        // First check if it's a git repo
        guard isGitRepository(at: path) else { return false }

        // Resolve git path
        let gitCheck = await isCommandAvailable("git")
        guard gitCheck.isAvailable, let gitPath = gitCheck.path else { return false }

        do {
            let output = try await processExecutor.execute(
                command: gitPath,
                arguments: ["remote", "-v"],
                directory: path
            )
            return output.contains("github.com")
        } catch {
            return false
        }
    }

    // MARK: - Dependency Checking

    /// Checks if required tools are installed and accessible
    func checkDependencies() async -> [DependencyStatus] {
        async let gitCheck = isCommandAvailable("git")
        async let ghCheck = isCommandAvailable("gh")

        let (git, gh) = await (gitCheck, ghCheck)

        var statuses: [DependencyStatus] = []
        
        if !git.isAvailable {
            statuses.append(.missingGit(path: git.path))
        }
        
        if !gh.isAvailable {
            statuses.append(.missingGitHubCLI(path: gh.path))
        }
        
        return statuses
    }
    
    enum DependencyStatus: Hashable {
        case missingGit(path: String?)
        case missingGitHubCLI(path: String?)
        
        var message: String {
            switch self {
            case .missingGit: return "Git is not installed or not in PATH."
            case .missingGitHubCLI: return "GitHub CLI (gh) is not installed."
            }
        }
        
        var installInstruction: String {
            switch self {
            case .missingGit: return "Install Xcode Command Line Tools or 'brew install git'"
            case .missingGitHubCLI: return "Run 'brew install gh' in Terminal"
            }
        }
    }
    
    private struct CommandCheck {
        let isAvailable: Bool
        let path: String?
    }

    private func isCommandAvailable(_ command: String) async -> CommandCheck {
        // Common paths to search, including Apple Silicon Homebrew
        let searchPaths = [
            "/usr/bin",
            "/usr/local/bin",
            "/opt/homebrew/bin", // Apple Silicon
            "/bin"
        ]
        
        // 1. Try to find precise path first
        for path in searchPaths {
            let fullPath = (path as NSString).appendingPathComponent(command)
            if fileManager.fileExists(atPath: fullPath) && fileManager.isExecutableFile(atPath: fullPath) {
                return CommandCheck(isAvailable: true, path: fullPath)
            }
        }
        
        // 2. Fallback to 'which' command
        do {
            let path = try await processExecutor.execute(
                command: "/usr/bin/which",
                arguments: [command],
                directory: nil
            )
            let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
            return CommandCheck(isAvailable: !trimmedPath.isEmpty, path: trimmedPath.isEmpty ? nil : trimmedPath)
        } catch {
            return CommandCheck(isAvailable: false, path: nil)
        }
    }
    
    private func resolveCommandPath(_ command: String) async -> String {
        let result = await isCommandAvailable(command)
        return result.path ?? command // Return command name itself as fallback to let system attempt resolution
    }

    // MARK: - Git Status

    func getStatus(for project: Project) async throws -> GitStatus {
        guard isGitRepository(at: project.path) else {
            throw GitError.notAGitRepository
        }
        
        let gitPath = await resolveCommandPath("git")

        async let currentBranch = getCurrentBranch(path: project.path, gitPath: gitPath)
        async let hasChanges = hasUncommittedChanges(path: project.path, gitPath: gitPath)
        async let untracked = getUntrackedFiles(path: project.path, gitPath: gitPath)
        async let modified = getModifiedFiles(path: project.path, gitPath: gitPath)
        async let staged = getStagedFiles(path: project.path, gitPath: gitPath)
        async let lastCommit = getLastCommit(path: project.path, gitPath: gitPath)

        let (branch, changes, untrackedFiles, modifiedFiles, stagedFiles, commit) = try await (
            currentBranch,
            hasChanges,
            untracked,
            modified,
            staged,
            lastCommit
        )
        
        // Check GitHub integration
        let isGitHub = await isGitHubRepository(at: project.path)

        // Check for pull requests if GitHub CLI is available
        let prCount = await getPendingPullRequestCount(path: project.path)

        return GitStatus(
            currentBranch: branch,
            hasUncommittedChanges: changes,
            untrackedFiles: untrackedFiles,
            modifiedFiles: modifiedFiles,
            stagedFiles: stagedFiles,
            pendingPullRequests: prCount,
            lastCommitHash: commit.hash,
            lastCommitMessage: commit.message,
            hasGitHubRemote: isGitHub
        )
    }

    // MARK: - Git Operations

    private func getCurrentBranch(path: String, gitPath: String) async throws -> String {
        let output = try await processExecutor.execute(
            command: gitPath,
            arguments: ["rev-parse", "--abbrev-ref", "HEAD"],
            directory: path
        )

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func hasUncommittedChanges(path: String, gitPath: String) async throws -> Bool {
        do {
            let output = try await processExecutor.execute(
                command: gitPath,
                arguments: ["status", "--porcelain"],
                directory: path
            )

            return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            return false
        }
    }

    private func getUntrackedFiles(path: String, gitPath: String) async throws -> [String] {
        do {
            let output = try await processExecutor.execute(
                command: gitPath,
                arguments: ["ls-files", "--others", "--exclude-standard"],
                directory: path
            )

            return output
                .split(separator: "\n")
                .map { String($0) }
                .filter { !$0.isEmpty }
        } catch {
            return []
        }
    }

    private func getModifiedFiles(path: String, gitPath: String) async throws -> [String] {
        do {
            let output = try await processExecutor.execute(
                command: gitPath,
                arguments: ["diff", "--name-only"],
                directory: path
            )

            return output
                .split(separator: "\n")
                .map { String($0) }
                .filter { !$0.isEmpty }
        } catch {
            return []
        }
    }

    private func getStagedFiles(path: String, gitPath: String) async throws -> [String] {
        do {
            let output = try await processExecutor.execute(
                command: gitPath,
                arguments: ["diff", "--cached", "--name-only"],
                directory: path
            )

            return output
                .split(separator: "\n")
                .map { String($0) }
                .filter { !$0.isEmpty }
        } catch {
            return []
        }
    }

    private func getLastCommit(path: String, gitPath: String) async throws -> (hash: String, message: String) {
        do {
            let hash = try await processExecutor.execute(
                command: gitPath,
                arguments: ["rev-parse", "HEAD"],
                directory: path
            )

            let message = try await processExecutor.execute(
                command: gitPath,
                arguments: ["log", "-1", "--pretty=%s"],
                directory: path
            )

            return (
                hash.trimmingCharacters(in: .whitespacesAndNewlines),
                message.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            return (hash: "", message: "")
        }
    }

    // MARK: - GitHub CLI Integration

    private func getPendingPullRequestCount(path: String) async -> Int {
        // Resolve gh path
        let check = await isCommandAvailable("gh")
        guard check.isAvailable, let ghPath = check.path else {
            return 0
        }

        do {
            let output = try await processExecutor.execute(
                command: ghPath,
                arguments: ["pr", "status", "--json", "title,state", "-q", ".[] | .state"],
                directory: path
            )

            // Count open PRs
            let openPRs = output
                .split(separator: "\n")
                .filter { $0.contains("OPEN") }

            return openPRs.count
        } catch {
            return 0
        }
    }

    // MARK: - Errors

    enum GitError: Error {
        case notAGitRepository
        case commandFailed(String)
    }
}

/// Helper for executing shell processes
actor ProcessExecutor {
    func execute(command: String, arguments: [String], directory: String?) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        
        // Add environment to ensure PATH is respected if needed
        var env = ProcessInfo.processInfo.environment
        // Append common paths to PATH if missing
        let pathVar = env["PATH"] ?? ""
        let extraPaths = ":/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
        if !pathVar.contains("/opt/homebrew/bin") {
            env["PATH"] = pathVar + extraPaths
        }
        process.environment = env

        if let directory = directory {
            process.currentDirectoryURL = URL(fileURLWithPath: directory)
        }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            if process.terminationStatus != 0 {
                throw GitService.GitError.commandFailed(output)
            }

            return output
        } catch {
            throw error
        }
    }
}
