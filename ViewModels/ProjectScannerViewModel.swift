import Foundation
import OSLog
import SwiftUI

@MainActor
class ProjectScannerViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var projects: [Project] = []
    @Published var isScanning = false
    @Published var isLoadingFromCache = false
    @Published var isApplyingFilter = false
    @Published var errorMessage: String?
    @Published var missingDependencies: [GitService.DependencyStatus] = []

    // MARK: - Services
    
    private let configStore = ConfigStore()
    private let gitService = GitService()
    private let cacheManager = CacheManager()
    private let changeDetector = ChangeDetector()
    private let logger = Logger(subsystem: "com.gitmonitor", category: "ProjectScanner")
    
    // MARK: - Configuration
    
    /// Number of projects to process concurrently (dynamic based on CPU cores)
    private var optimalBatchSize: Int {
        max(5, ProcessInfo.processInfo.activeProcessorCount)
    }

    // MARK: - Initialization
    
    init() {
        // Load from cache immediately for instant UI
        Task {
            await loadFromCache()
        }
    }
    
    // MARK: - Cache Management
    
    /// Load projects from cache for instant display
    func loadFromCache() async {
        isLoadingFromCache = true
        
        do {
            guard let cache = try await cacheManager.loadCache() else {
                logger.info("No cache found, performing full scan")
                await scanAllProjects()
                isLoadingFromCache = false
                return
            }
            
            // Validate cache
            let pathsMatch = await cacheManager.pathsMatch(cache, currentPaths: configStore.monitoredPaths)
            let isValid = await cacheManager.isCacheValid(cache, maxAge: 3600)
            
            guard pathsMatch && isValid else {
                logger.info("Cache invalid (paths changed or expired), performing full scan")
                await scanAllProjects()
                isLoadingFromCache = false
                return
            }
            
            // Use cached data
            projects = cache.projects
            logger.info("Loaded \(cache.projects.count) projects from cache")
            
            // Background: Check for changes and light refresh
            Task {
                await lightRefreshChangedProjects()
                isLoadingFromCache = false
            }
            
        } catch {
            logger.error("Failed to load cache: \(error)")
            await scanAllProjects()
            isLoadingFromCache = false
        }
    }
    
    /// Save current projects state to cache
    func saveCache(force: Bool = false) async {
        let cache = ProjectCache(
            monitoredPaths: configStore.monitoredPaths,
            projects: projects
        )
        
        do {
            try await cacheManager.saveCache(cache, force: force)
            logger.debug("Cache saved successfully")
        } catch {
            logger.error("Failed to save cache: \(error)")
        }
    }
    
    // MARK: - Project Scanning
    
    /// Perform a full scan of all monitored paths
    func scanAllProjects() async {
        isScanning = true
        errorMessage = nil
        logger.debug("Starting full project scan")

        // 1. Discover projects (filesystem scanning)
        let discoveredProjects = await configStore.scanMonitoredPaths()

        // 2. Merge with existing projects to preserve state
        var mergedProjects: [Project] = []
        for newProject in discoveredProjects {
            if let existing = projects.first(where: { $0.path == newProject.path }) {
                var p = newProject
                p.id = existing.id // Critical: Preserve ID to prevent list flashing/dups
                p.gitStatus = existing.gitStatus
                p.lastScanned = existing.lastScanned
                p.lastReviewed = existing.lastReviewed
                
                // Preserve sub-projects status/IDs if it's a workspace
                if p.isWorkspace {
                    p.subProjects = mergeSubProjects(new: p.subProjects, existing: existing.subProjects)
                }
                
                mergedProjects.append(p)
            } else {
                mergedProjects.append(newProject)
            }
        }
        
        let sortedProjects = mergedProjects.sorted { $0.name < $1.name }
        projects = sortedProjects
        
        // DEBUG: Log project structure
        logger.info("📊 DEBUG: Total root projects: \(sortedProjects.count)")
        for (index, project) in sortedProjects.enumerated() {
            logger.info("  [\(index)] \(project.name) - isRoot:\(project.isRoot) isWorkspace:\(project.isWorkspace) children:\(project.subProjects.count)")
        }

        // 3. Full refresh for all git repos
        await fullRefreshAllRepos()
        
        // 4. Save cache
        await saveCache(force: true)

        logger.debug("Scan completed: \(sortedProjects.count) projects")
        isScanning = false
    }
    
    /// Light refresh: Only update repos that have filesystem changes
    func lightRefreshChangedProjects() async {
        logger.debug("Starting light refresh of changed projects")
        
        // Extract all git repos from hierarchy
        let allRepos = await getAllGitReposFlattened()
        
        // Detect which ones have changes
        let changedRepos = await changeDetector.filterChangedProjects(allRepos)
        
        logger.info("Light refresh: \(changedRepos.count) of \(allRepos.count) repos changed")
        
        // Use light status refresh for changed repos
        let batchSize = optimalBatchSize
        for batch in changedRepos.chunked(into: batchSize) {
            await withTaskGroup(of: Void.self) { group in
                for project in batch {
                    group.addTask {
                        await self.lightRefreshProjectStatus(project)
                    }
                }
            }
        }
        
        // Save cache after refresh
        await saveCache()
    }
    
    /// Full refresh: Update all git repos with complete status
    func fullRefreshAllRepos() async {
        let allRepos = await getAllGitReposFlattened()
        
        logger.info("Full refresh: \(allRepos.count) repos")
        
        let batchSize = optimalBatchSize
        for batch in allRepos.chunked(into: batchSize) {
            await withTaskGroup(of: Void.self) { group in
                for project in batch {
                    group.addTask {
                        await self.fullRefreshProjectStatus(project)
                    }
                }
            }
        }
    }
    
    // MARK: - Status Refresh Methods

    /// Fetch a full GitStatus for a project (throws on failure).
    /// Used by Game Mode so it can update its own project list by path.
    func fetchStatus(for project: Project) async throws -> GitStatus {
        try await gitService.getStatus(for: project)
    }

    /// Apply a GitStatus to the project hierarchy by matching path.
    /// Safe no-op if the path is not currently present in `projects`.
    func applyStatus(forPath path: String, status: GitStatus) {
        func findId(in projects: [Project]) -> UUID? {
            for p in projects {
                if p.path == path { return p.id }
                if let found = findId(in: p.subProjects) { return found }
            }
            return nil
        }

        guard let projectId = findId(in: projects) else { return }
        updateProjectStatus(projectId: projectId, status: status)
    }
    
    /// Light refresh: Minimal git commands (3) with cached data reuse
    func lightRefreshProjectStatus(_ project: Project) async {
        do {
            let cachedStatus = project.gitStatus
            let gitStatus = try await gitService.getLightStatus(for: project, cachedStatus: cachedStatus)
            
            updateProjectStatus(projectId: project.id, status: gitStatus)
            
        } catch {
            logger.error("Light refresh failed for \(project.name): \(error)")
        }
    }
    
    /// Full refresh: All git commands (~10) for complete information
    func fullRefreshProjectStatus(_ project: Project) async {
        do {
            let gitStatus = try await gitService.getStatus(for: project)
            updateProjectStatus(projectId: project.id, status: gitStatus)
            
        } catch {
            logger.error("Full refresh failed for \(project.name): \(error)")
        }
    }
    
    /// Legacy method for backward compatibility - uses full refresh
    func refreshProjectStatus(_ project: Project) async {
        await fullRefreshProjectStatus(project)
    }
    
    // MARK: - Project Updates
    
    /// Update project status in the hierarchy
    @MainActor
    private func updateProjectStatus(projectId: UUID, status: GitStatus) {
        // Try top-level first
        if let index = projects.firstIndex(where: { $0.id == projectId }) {
            projects[index].gitStatus = status
            projects[index].lastScanned = Date()
            return
        }
        
        // Search in hierarchy
        for (i, rootProject) in projects.enumerated() {
            if let newRoot = updateProjectRecursively(rootProject, targetId: projectId, status: status) {
                projects[i] = newRoot
                break
            }
        }
    }
    
    /// Recursively update a project in the hierarchy
    private func updateProjectRecursively(_ project: Project, targetId: UUID, status: GitStatus) -> Project? {
        if project.id == targetId {
            var p = project
            p.gitStatus = status
            p.lastScanned = Date()
            return p
        }
        
        guard !project.subProjects.isEmpty else {
            return nil
        }
        
        var updatedSubProjects = project.subProjects
        var found = false
        
        for (index, sub) in project.subProjects.enumerated() {
            if let updatedSub = updateProjectRecursively(sub, targetId: targetId, status: status) {
                updatedSubProjects[index] = updatedSub
                found = true
                break
            }
        }
        
        if found {
            var p = project
            p.subProjects = updatedSubProjects
            return p
        }
        
        return nil
    }
    
    /// Merge sub-projects preserving state
    private func mergeSubProjects(new: [Project], existing: [Project]) -> [Project] {
        new.map { newSub in
            var sub = newSub
            if let existingSub = existing.first(where: { $0.path == newSub.path }) {
                sub.id = existingSub.id // Critical: Preserve ID
                sub.gitStatus = existingSub.gitStatus
                sub.lastScanned = existingSub.lastScanned
                sub.lastReviewed = existingSub.lastReviewed
                
                // Recursively merge children if it's a workspace
                if sub.isWorkspace {
                    sub.subProjects = mergeSubProjects(new: sub.subProjects, existing: existingSub.subProjects)
                }
            }
            return sub
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get all git repositories as a flat array
    private func getAllGitReposFlattened() async -> [Project] {
        var allRepos: [Project] = []
        for project in projects {
            allRepos.append(contentsOf: getAllGitRepos(from: project))
        }
        return allRepos
    }
    
    /// Recursively extract git repos from a project hierarchy
    private func getAllGitRepos(from project: Project) -> [Project] {
        var repos: [Project] = []
        if project.isGitRepository {
            repos.append(project)
        }
        for sub in project.subProjects {
            repos.append(contentsOf: getAllGitRepos(from: sub))
        }
        return repos
    }
    
    // MARK: - Configuration Management
    
    func checkDependencies() async {
        let missing = await gitService.checkDependencies()
        missingDependencies = missing
        if !missing.isEmpty {
             logger.warning("Missing dependencies: \(missing)")
        }
    }

    func addMonitoredPath(_ path: String) {
        configStore.addMonitoredPath(path)
    }

    func removeMonitoredPath(_ path: String) {
        configStore.removeMonitoredPath(path)
    }
    
    func ignoreProject(_ path: String) {
        configStore.ignorePath(path)
        projects.removeAll { $0.path == path }
    }

    func getMonitoredPaths() -> [String] {
        configStore.monitoredPaths
    }

    func markProjectAsReviewed(_ project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index].lastReviewed = Date()
    }
    
    // MARK: - Project Queries
    
    func getProject(byPath path: String) -> Project? {
        projects.first { $0.path == path }
    }
    
    func getProject(byId id: UUID) -> Project? {
        func find(in projects: [Project]) -> Project? {
            for p in projects {
                if p.id == id { return p }
                if let found = find(in: p.subProjects) { return found }
            }
            return nil
        }
        return find(in: projects)
    }

    func getParent(of projectId: UUID) -> Project? {
        func findParent(in project: Project) -> Project? {
            if project.subProjects.contains(where: { $0.id == projectId }) {
                return project
            }
            for sub in project.subProjects {
                if let found = findParent(in: sub) { return found }
            }
            return nil
        }
        
        for project in projects {
            if let found = findParent(in: project) { return found }
        }
        return nil
    }

    // MARK: - Computed Properties
    
    var gitRepositories: [Project] {
        var allRepos: [Project] = []
        for project in projects {
            allRepos.append(contentsOf: getAllGitRepos(from: project))
        }
        return allRepos
    }

    var nonGitProjects: [Project] {
        projects.filter { !$0.isGitRepository }
    }

    var projectsNeedingAttention: [Project] {
        var attention: [Project] = []
        for p in projects {
            attention.append(contentsOf: getAllGitRepos(from: p).filter { 
                $0.gitStatus?.hasUncommittedChanges == true 
            })
        }
        return attention
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
