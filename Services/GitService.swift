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

    // MARK: - Git Status

    func getStatus(for project: Project) async throws -> GitStatus {
        guard isGitRepository(at: project.path) else {
            throw GitError.notAGitRepository
        }

        async let currentBranch = getCurrentBranch(path: project.path)
        async let hasChanges = hasUncommittedChanges(path: project.path)
        async let untracked = getUntrackedFiles(path: project.path)
        async let modified = getModifiedFiles(path: project.path)
        async let staged = getStagedFiles(path: project.path)
        async let lastCommit = getLastCommit(path: project.path)

        let (branch, changes, untrackedFiles, modifiedFiles, stagedFiles, commit) = try await (
            currentBranch,
            hasChanges,
            untracked,
            modified,
            staged,
            lastCommit
        )

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
            lastCommitMessage: commit.message
        )
    }

    // MARK: - Git Operations

    private func getCurrentBranch(path: String) async throws -> String {
        let output = try await processExecutor.execute(
            command: "/usr/bin/git",
            arguments: ["rev-parse", "--abbrev-ref", "HEAD"],
            directory: path
        )

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func hasUncommittedChanges(path: String) async throws -> Bool {
        do {
            let output = try await processExecutor.execute(
                command: "/usr/bin/git",
                arguments: ["status", "--porcelain"],
                directory: path
            )

            return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            return false
        }
    }

    private func getUntrackedFiles(path: String) async throws -> [String] {
        do {
            let output = try await processExecutor.execute(
                command: "/usr/bin/git",
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

    private func getModifiedFiles(path: String) async throws -> [String] {
        do {
            let output = try await processExecutor.execute(
                command: "/usr/bin/git",
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

    private func getStagedFiles(path: String) async throws -> [String] {
        do {
            let output = try await processExecutor.execute(
                command: "/usr/bin/git",
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

    private func getLastCommit(path: String) async throws -> (hash: String, message: String) {
        do {
            let hash = try await processExecutor.execute(
                command: "/usr/bin/git",
                arguments: ["rev-parse", "HEAD"],
                directory: path
            )

            let message = try await processExecutor.execute(
                command: "/usr/bin/git",
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
        // First check if gh CLI is available
        guard await isGitHubCLIAvailable() else {
            return 0
        }

        do {
            let output = try await processExecutor.execute(
                command: "/usr/local/bin/gh",
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

    private func isGitHubCLIAvailable() async -> Bool {
        do {
            let _ = try await processExecutor.execute(
                command: "/usr/local/bin/gh",
                arguments: ["--version"],
                directory: nil
            )
            return true
        } catch {
            return false
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
