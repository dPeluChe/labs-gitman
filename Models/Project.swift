import Foundation

/// Represents a monitored project directory
struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var path: String
    var name: String
    var lastScanned: Date
    var isGitRepository: Bool
    var gitStatus: GitStatus?

    init(path: String, name: String? = nil) {
        self.id = UUID()
        self.path = path
        self.name = name ?? (path as NSString).lastPathComponent
        self.lastScanned = Date()
        self.isGitRepository = false
        self.gitStatus = nil
    }

    /// Human-readable status description
    var statusDescription: String {
        guard isGitRepository else {
            return "Not a Git repository"
        }

        guard let status = gitStatus else {
            return "No status available"
        }

        var parts: [String] = []
        parts.append("On branch: \(status.currentBranch)")

        if status.hasUncommittedChanges {
            parts.append("Uncommitted changes")
        }

        if status.pendingPullRequests > 0 {
            parts.append("\(status.pendingPullRequests) PR(s)")
        }

        return parts.joined(separator: " • ")
    }
}

/// Git branch information
struct GitBranch: Codable, Hashable {
    let name: String
    let isCurrent: Bool
    let lastCommitDate: Date?
    let lastCommitHash: String?
}

/// Git repository status information
struct GitStatus: Codable, Hashable {
    var currentBranch: String
    var hasUncommittedChanges: Bool
    var untrackedFiles: [String]
    var modifiedFiles: [String]
    var stagedFiles: [String]
    var pendingPullRequests: Int
    var lastCommitHash: String?
    var lastCommitMessage: String?
    var lastCommitDate: Date? // Used for sorting
    var hasGitHubRemote: Bool
    var branches: [GitBranch] // List of branches

    init(
        currentBranch: String = "main",
        hasUncommittedChanges: Bool = false,
        untrackedFiles: [String] = [],
        modifiedFiles: [String] = [],
        stagedFiles: [String] = [],
        pendingPullRequests: Int = 0,
        lastCommitHash: String? = nil,
        lastCommitMessage: String? = nil,
        lastCommitDate: Date? = nil,
        hasGitHubRemote: Bool = false,
        branches: [GitBranch] = []
    ) {
        self.currentBranch = currentBranch
        self.hasUncommittedChanges = hasUncommittedChanges
        self.untrackedFiles = untrackedFiles
        self.modifiedFiles = modifiedFiles
        self.stagedFiles = stagedFiles
        self.pendingPullRequests = pendingPullRequests
        self.lastCommitHash = lastCommitHash
        self.lastCommitMessage = lastCommitMessage
        self.lastCommitDate = lastCommitDate
        self.hasGitHubRemote = hasGitHubRemote
        self.branches = branches
    }

    /// Overall health status
    var healthStatus: HealthStatus {
        if hasUncommittedChanges {
            return .needsAttention
        }
        if pendingPullRequests > 0 {
            return .hasPullRequests
        }
        return .clean
    }

    enum HealthStatus {
        case clean
        case hasPullRequests
        case needsAttention
    }
}
