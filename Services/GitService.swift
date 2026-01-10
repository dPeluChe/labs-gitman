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
        guard isGitRepository(at: path) else { return false }
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
        let searchPaths = [
            "/usr/bin",
            "/usr/local/bin",
            "/opt/homebrew/bin", // Apple Silicon
            "/bin"
        ]
        
        for path in searchPaths {
            let fullPath = (path as NSString).appendingPathComponent(command)
            if fileManager.fileExists(atPath: fullPath) && fileManager.isExecutableFile(atPath: fullPath) {
                return CommandCheck(isAvailable: true, path: fullPath)
            }
        }
        
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
        return result.path ?? command
    }

    // MARK: - Git Status

    /// Get full git status for a project
    /// Executes all git commands for complete information (~10 commands)
    /// Use this when: user opens project detail, explicit refresh, or periodic full scan
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
        async let branches = getBranches(path: project.path, gitPath: gitPath)

        async let counts = getBehindAheadCounts(path: project.path, gitPath: gitPath)

        let (branch, changes, untrackedFiles, modifiedFiles, stagedFiles, commit, branchList, behindAhead) = try await (
            currentBranch,
            hasChanges,
            untracked,
            modified,
            staged,
            lastCommit,
            branches,
            counts
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
            lastCommitDate: commit.date,
            hasGitHubRemote: isGitHub,
            incomingCommits: behindAhead.behind,
            outgoingCommits: behindAhead.ahead,
            branches: branchList
        )
    }
    
    /// Get lightweight git status for quick refreshes
    /// Only executes essential commands (3 instead of 10) for faster updates
    /// Reuses cached data when available
    /// Use this when: app startup, background refresh, or quick status check
    func getLightStatus(for project: Project, cachedStatus: GitStatus?) async throws -> GitStatus {
        guard isGitRepository(at: project.path) else {
            throw GitError.notAGitRepository
        }
        
        let gitPath = await resolveCommandPath("git")
        
        // Execute only essential commands in parallel
        async let currentBranch = getCurrentBranch(path: project.path, gitPath: gitPath)
        async let hasChanges = hasUncommittedChanges(path: project.path, gitPath: gitPath)
        async let lastCommit = getLastCommit(path: project.path, gitPath: gitPath)
        
        let (branch, changes, commit) = try await (currentBranch, hasChanges, lastCommit)
        
        // Reuse cached data for non-critical info, or use defaults
        return GitStatus(
            currentBranch: branch,
            hasUncommittedChanges: changes,
            untrackedFiles: cachedStatus?.untrackedFiles ?? [],
            modifiedFiles: cachedStatus?.modifiedFiles ?? [],
            stagedFiles: cachedStatus?.stagedFiles ?? [],
            pendingPullRequests: cachedStatus?.pendingPullRequests ?? 0,
            lastCommitHash: commit.hash,
            lastCommitMessage: commit.message,
            lastCommitDate: commit.date,
            hasGitHubRemote: cachedStatus?.hasGitHubRemote ?? false,
            incomingCommits: cachedStatus?.incomingCommits ?? 0,
            outgoingCommits: cachedStatus?.outgoingCommits ?? 0,
            branches: cachedStatus?.branches ?? []
        )
    }

    private func getBehindAheadCounts(path: String, gitPath: String) async throws -> (behind: Int, ahead: Int) {
        do {
            // git rev-list --left-right --count HEAD...@{u}
            // However, that fails if no upstream is set.
            // Safer: git status -sb --porcelain=v2
            // output usually: # branch.ab +0 -0
            // but porcelain v2 is complex.
            // Let's stick to 'git rev-list --count --left-right HEAD...@{u}' and catch error (e.g. no upstream)
            
            let output = try await processExecutor.execute(
                command: gitPath,
                arguments: ["rev-list", "--left-right", "--count", "HEAD...@{u}"],
                directory: path
            )
            
            // Output format: "ahead    behind" e.g. "1    5"
            let parts = output.split(separator: "\t", omittingEmptySubsequences: true)
                .flatMap { $0.split(separator: " ", omittingEmptySubsequences: true) }
            
            if parts.count >= 2,
               let ahead = Int(parts[0]),
               let behind = Int(parts[1]) {
                return (behind, ahead)
            }
            return (0, 0)
        } catch {
            return (0, 0)
        }
    }

    // MARK: - Git Operations

    private func getCurrentBranch(path: String, gitPath: String) async throws -> String {
        do {
            let output = try await processExecutor.execute(
                command: gitPath,
                arguments: ["rev-parse", "--abbrev-ref", "HEAD"],
                directory: path
            )
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
             // Handle empty repository (no HEAD yet)
             return "No Branch (Empty)"
        }
    }

    private func getBranches(path: String, gitPath: String) async throws -> [GitBranch] {
        // Output format: refname:short|objectname:short|committerdate:iso-strict|HEAD
        let format = "%(refname:short)|%(objectname:short)|%(committerdate:iso8601)|%(HEAD)"
        do {
            let output = try await processExecutor.execute(
                command: gitPath,
                arguments: ["branch", "-v", "--sort=-committerdate", "--format=\(format)"],
                directory: path
            )
            
            var branches: [GitBranch] = []
            let lines = output.split(separator: "\n")
            
            let dateFormatter = ISO8601DateFormatter()
            
            for line in lines {
                let parts = line.split(separator: "|", omittingEmptySubsequences: false)
                if parts.count >= 4 {
                    let name = String(parts[0])
                    let hash = String(parts[1])
                    let dateStr = String(parts[2])
                    let isCurrent = String(parts[3]) == "*"
                    
                    let date = dateFormatter.date(from: dateStr)
                    
                    branches.append(GitBranch(
                        name: name,
                        isCurrent: isCurrent,
                        lastCommitDate: date,
                        lastCommitHash: hash
                    ))
                }
            }
            return branches
        } catch {
            return []
        }
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

            return output.split(separator: "\n").map { String($0) }.filter { !$0.isEmpty }
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

            return output.split(separator: "\n").map { String($0) }.filter { !$0.isEmpty }
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

            return output.split(separator: "\n").map { String($0) }.filter { !$0.isEmpty }
        } catch {
            return []
        }
    }

    private func getLastCommit(path: String, gitPath: String) async throws -> (hash: String, message: String, date: Date?) {
        do {
            let hash = try await processExecutor.execute(
                command: gitPath,
                arguments: ["rev-parse", "HEAD"],
                directory: path
            )

            let logOutput = try await processExecutor.execute(
                command: gitPath,
                arguments: ["log", "-1", "--pretty=format:%B|||GITMAN|||%cd", "--date=iso-strict"],
                directory: path
            )
            
            let trimmedLog = logOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = trimmedLog.components(separatedBy: "|||GITMAN|||")
            
            let message = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let dateString = parts.count > 1 ? parts[1] : ""
            
            let formatter = ISO8601DateFormatter()
            let date = formatter.date(from: dateString)

            return (
                hash.trimmingCharacters(in: .whitespacesAndNewlines),
                message,
                date
            )
        } catch {
            return (hash: "", message: "", date: nil)
        }
    }

    func getCommitHistory(path: String, limit: Int = 10) async throws -> [GitCommit] {
        guard isGitRepository(at: path) else {
            throw GitError.notAGitRepository
        }

        let gitPath = await resolveCommandPath("git")

        do {
            let output = try await processExecutor.execute(
                command: gitPath,
                arguments: [
                    "log",
                    "-\(limit)",
                    "--pretty=%H|%an|%ae|%s|%cd",
                    "--date=iso-strict",
                    "--abbrev-commit"
                ],
                directory: path
            )

            let formatter = ISO8601DateFormatter()
            
            let commits = output.split(separator: "\n").compactMap { line -> GitCommit? in
                let parts = String(line).components(separatedBy: "|")
                guard parts.count >= 5 else { return nil }

                let hash = parts[0].prefix(7)
                let author = parts[1]
                let email = parts[2]
                let message = parts[3]
                let dateString = parts[4]

                if let date = formatter.date(from: dateString) {
                    return GitCommit(
                        hash: String(hash),
                        author: author,
                        email: email,
                        message: message,
                        date: date
                    )
                }

                return nil
            }

            return commits
        } catch {
            return []
        }
    }

    // MARK: - Branch Switching

    func switchBranch(path: String, branchName: String) async throws {
        guard isGitRepository(at: path) else {
            throw GitError.notAGitRepository
        }

        let gitPath = await resolveCommandPath("git")

        // Check for uncommitted changes
        let hasChanges = try await hasUncommittedChanges(path: path, gitPath: gitPath)

        if hasChanges {
            throw GitError.uncommittedChanges
        }

        // Switch branch
        let output = try await processExecutor.execute(
            command: gitPath,
            arguments: ["checkout", branchName],
            directory: path
        )

        // Check for errors
        if output.lowercased().contains("error") {
            throw GitError.checkoutFailed(output)
        }
    }

    // MARK: - GitHub CLI Integration

    private func getPendingPullRequestCount(path: String) async -> Int {
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
            let openPRs = output.split(separator: "\n").filter { $0.contains("OPEN") }
            return openPRs.count
        } catch {
            return 0
        }
    }

    // MARK: - Errors

    enum GitError: Error, LocalizedError {
        case notAGitRepository
        case uncommittedChanges
        case checkoutFailed(String)
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAGitRepository:
                return "Not a Git repository"
            case .uncommittedChanges:
                return "You have uncommitted changes. Please commit or stash them first."
            case .checkoutFailed(let message):
                return "Failed to checkout branch: \(message)"
            case .commandFailed(let message):
                return "Command failed: \(message)"
            }
        }
    }
}

/// Helper for executing shell processes
actor ProcessExecutor {
    func execute(command: String, arguments: [String], directory: String?) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        
        var env = ProcessInfo.processInfo.environment
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

        return try await withCheckedThrowingContinuation { continuation in
            // Move ALL blocking work to a background thread
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try process.run()
                    
                    // This blocks the background thread, which is fine
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    
                    let output = String(data: data, encoding: .utf8) ?? ""
                    
                    if process.terminationStatus != 0 {
                        continuation.resume(throwing: GitService.GitError.commandFailed(output))
                    } else {
                        continuation.resume(returning: output)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
