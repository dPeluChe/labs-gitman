import Foundation
import OSLog

/// Detects changes in git repositories without executing git commands
/// Uses filesystem timestamps as a fast alternative to git status
actor ChangeDetector {
    private let logger = Logger(subsystem: "com.gitmonitor", category: "ChangeDetector")
    private let fileManager = FileManager.default
    
    // MARK: - Change Detection
    
    /// Check if a git repository has changes since last scan
    /// This is much faster than running git commands
    /// - Parameter project: The project to check
    /// - Returns: True if changes detected, false otherwise
    func hasChanges(project: Project) -> Bool {
        guard project.isGitRepository else {
            // Non-git projects always "changed" (we don't track them)
            return false
        }
        
        let gitIndexPath = (project.path as NSString).appendingPathComponent(".git/index")
        let gitHeadPath = (project.path as NSString).appendingPathComponent(".git/HEAD")
        let gitRefsPath = (project.path as NSString).appendingPathComponent(".git/refs/heads")
        
        // Get modification dates
        guard let indexDate = modificationDate(at: gitIndexPath) else {
            // If we can't check, assume it changed
            logger.debug("No .git/index found for \(project.name), assuming changed")
            return true
        }
        
        guard let headDate = modificationDate(at: gitHeadPath) else {
            logger.debug("No .git/HEAD found for \(project.name), assuming changed")
            return true
        }
        
        // Optional: Check refs directory for branch updates
        let refsDate = modificationDate(at: gitRefsPath)
        
        // Compare with last scan date
        let lastCheck = project.lastScanned
        
        let hasChange = indexDate > lastCheck || 
                       headDate > lastCheck || 
                       (refsDate != nil && refsDate! > lastCheck)
        
        if hasChange {
            logger.debug("\(project.name): Changes detected")
        }
        
        return hasChange
    }
    
    /// Check if a project needs a full refresh (hasn't been fully scanned recently)
    /// - Parameters:
    ///   - project: The project to check
    ///   - threshold: Time threshold in seconds (default: 15 minutes)
    /// - Returns: True if full refresh is needed
    func needsFullRefresh(project: Project, threshold: TimeInterval = 900) -> Bool {
        guard let gitStatus = project.gitStatus else {
            // No status yet, needs full refresh
            return true
        }
        
        let elapsed = Date().timeIntervalSince(project.lastScanned)
        return elapsed > threshold
    }
    
    // MARK: - Batch Operations
    
    /// Filter a list of projects to only those with detected changes
    /// - Parameter projects: Array of projects to check
    /// - Returns: Array of projects that have changes
    func filterChangedProjects(_ projects: [Project]) -> [Project] {
        let changed = projects.filter { hasChanges(project: $0) }
        
        logger.info("Change detection: \(changed.count) of \(projects.count) repos changed")
        
        return changed
    }
    
    /// Recursively find all git repositories in a project hierarchy
    /// - Parameter project: Root project (may be workspace)
    /// - Returns: Flat array of all git repositories
    func extractGitRepos(from project: Project) -> [Project] {
        var repos: [Project] = []
        
        if project.isGitRepository {
            repos.append(project)
        }
        
        for subProject in project.subProjects {
            repos.append(contentsOf: extractGitRepos(from: subProject))
        }
        
        return repos
    }
    
    /// Recursively find changed git repositories in a project hierarchy
    /// - Parameter project: Root project (may be workspace)
    /// - Returns: Flat array of changed git repositories
    func extractChangedRepos(from project: Project) -> [Project] {
        let allRepos = extractGitRepos(from: project)
        return filterChangedProjects(allRepos)
    }
    
    // MARK: - Helper Methods
    
    /// Get modification date of a file or directory
    /// - Parameter path: Path to check
    /// - Returns: Modification date if available, nil otherwise
    private func modificationDate(at path: String) -> Date? {
        guard fileManager.fileExists(atPath: path) else {
            return nil
        }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            return attributes[.modificationDate] as? Date
        } catch {
            logger.error("Failed to get mod date for \(path): \(error)")
            return nil
        }
    }
    
    // MARK: - Statistics
    
    /// Get change detection statistics for a list of projects
    /// - Parameter projects: Projects to analyze
    /// - Returns: Statistics about changes
    func getChangeStats(for projects: [Project]) -> ChangeStats {
        let gitRepos = projects.flatMap { extractGitRepos(from: $0) }
        let changed = filterChangedProjects(gitRepos)
        
        return ChangeStats(
            totalRepos: gitRepos.count,
            changedRepos: changed.count,
            unchangedRepos: gitRepos.count - changed.count,
            changeRate: gitRepos.isEmpty ? 0 : Double(changed.count) / Double(gitRepos.count)
        )
    }
}

// MARK: - Data Models

/// Statistics about change detection
struct ChangeStats {
    let totalRepos: Int
    let changedRepos: Int
    let unchangedRepos: Int
    let changeRate: Double  // 0.0 to 1.0
    
    var percentChanged: String {
        String(format: "%.1f%%", changeRate * 100)
    }
}
