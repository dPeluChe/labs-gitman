import Foundation
import OSLog

/// Persistent storage for application configuration
@MainActor
class ConfigStore: ObservableObject {
    @Published var monitoredPaths: [String] = []
    @Published var projects: [Project] = []
    @Published var ignoredPaths: [String] = []

    private let pathsKey = "monitoredPaths"
    private let ignoredKey = "ignoredPaths"
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.gitmonitor", category: "ConfigStore")

    // UserDefaults persistence
    private let defaults = UserDefaults.standard

    init() {
        loadMonitoredPaths()
        loadIgnoredPaths()
    }

    // MARK: - Path Management

    func addMonitoredPath(_ path: String) {
        guard !monitoredPaths.contains(path) else { return }
        monitoredPaths.append(path)
        saveMonitoredPaths()
    }

    func removeMonitoredPath(_ path: String) {
        monitoredPaths.removeAll { $0 == path }
        saveMonitoredPaths()
    }

    private func loadMonitoredPaths() {
        if let savedPaths = defaults.stringArray(forKey: pathsKey) {
            monitoredPaths = savedPaths
        }
    }

    private func saveMonitoredPaths() {
        defaults.set(monitoredPaths, forKey: pathsKey)
    }
    
    // MARK: - Ignore List Management
    
    func ignorePath(_ path: String) {
        guard !ignoredPaths.contains(path) else { return }
        ignoredPaths.append(path)
        saveIgnoredPaths()
        // Remove immediately from current projects
        projects.removeAll { $0.path == path }
    }
    
    private func loadIgnoredPaths() {
        if let saved = defaults.stringArray(forKey: ignoredKey) {
            ignoredPaths = saved
        }
    }
    
    private func saveIgnoredPaths() {
        defaults.set(ignoredPaths, forKey: ignoredKey)
    }

    // MARK: - Project Discovery

    /// Scan all monitored paths and discover projects
    func scanMonitoredPaths() async -> [Project] {
        var discoveredProjects: [Project] = []

        for path in monitoredPaths {
            logger.debug("Scanning monitored path: \(path)")
            let projectsInPath = await scanPathForProjects(path)
            discoveredProjects.append(contentsOf: projectsInPath)
        }

        // Merge with existing projects (update if exists, add if new)
        for project in discoveredProjects {
            if let index = projects.firstIndex(where: { $0.path == project.path }) {
                // Keep existing git status if not updated yet, but update basic info
                var updated = project
                if let existing = projects[index].gitStatus {
                    updated.gitStatus = existing
                }
                // Important: If we just detected it IS a git repo, ensure that sticks
                if project.isGitRepository {
                    updated.isGitRepository = true
                }
                projects[index] = updated
            } else {
                projects.append(project)
            }
        }

        // Remove projects that no longer exist
        projects.removeAll { project in
            !discoveredProjects.contains(where: { $0.path == project.path })
        }

        logger.debug("Total projects after scan: \(self.projects.count)")
        return projects
    }

    private func scanPathForProjects(_ path: String) async -> [Project] {
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            logger.error("Path does not exist or is not directory: \(path)")
            return []
        }

        // 1. If the monitored path itself is a git repo, return it as a single root item
        if isGitRepo(path) {
            if ignoredPaths.contains(path) { return [] }
            logger.debug("Found git repo at root: \(path)")
            var project = Project(path: path)
            project.isGitRepository = true
            return [project]
        }

        // 2. Scan immediate children to build the hierarchy
        var childProjects: [Project] = []
        
        let url = URL(fileURLWithPath: path)
        let keys: [URLResourceKey] = [.isDirectoryKey, .nameKey]
        
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            logger.error("Failed to list contents of: \(path)")
            return []
        }
        
        for folderURL in contents {
            let itemPath = folderURL.path
            let name = folderURL.lastPathComponent
            
            // Skip system/common ignored items
            if ignoredPaths.contains(itemPath) || name.hasPrefix(".") || ["node_modules", "Pods", "build", "dist"].contains(name) { continue }
            
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue else { continue }
            
            if isGitRepo(itemPath) {
                // Case 1: Direct Git Repository
                childProjects.append(Project(path: itemPath, isGitRepository: true))
            } else {
                // Case 2: Folder. Check if it contains repos (Workspace) or is empty/files (Folder)
                let subRepos = findGitRepositoriesRecursively(in: folderURL, currentDepth: 0, maxDepth: 2) // Limited depth for internal workspaces
                
                if !subRepos.isEmpty {
                    // Feature: Internal Workspace (Folder containing repos)
                    // We flatten the repos found inside this folder into this workspace's subSubjects
                    var workspace = Project(path: itemPath, isGitRepository: false, isWorkspace: true)
                    workspace.subProjects = subRepos.sorted { $0.name < $1.name }
                    childProjects.append(workspace)
                } else {
                    // Feature: Non-Repo Folder (for review)
                    // We add it only if it's not strictly ignored. The user requested to see "folders".
                    // To avoid too much noise, we could filter empty folders, but let's show them for now.
                    childProjects.append(Project(path: itemPath, isGitRepository: false))
                }
            }
        }

        // Create the Root Project (The Monitored Path) acting as the Top-Level Workspace
        var rootProject = Project(path: path, isGitRepository: false, isWorkspace: true, isRoot: true)
        rootProject.subProjects = childProjects.sorted { $0.name < $1.name }
        
        return [rootProject]
    }
    
    /// Recursively find git repositories in a directory
    private func findGitRepositoriesRecursively(in rootURL: URL, currentDepth: Int, maxDepth: Int) -> [Project] {
        if currentDepth >= maxDepth { return [] }
        
        var foundProjects: [Project] = []
        let keys: [URLResourceKey] = [.isDirectoryKey]
        
        guard let contents = try? fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return []
        }
        
        for url in contents {
            let path = url.path
            
            // Skip common dependency/build folders to improve performance and reduce noise
            if ["node_modules", "Pods", "Carthage", ".build", "build", "dist", "vendor", "venv", ".env"].contains(url.lastPathComponent) {
                continue
            }
            
            if ignoredPaths.contains(path) { continue }
            
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { continue }
            
            if isGitRepo(path) {
                // Found one! Add it and do NOT recurse inside it (submodules handled by git)
                foundProjects.append(Project(path: path, isGitRepository: true))
            } else {
                // Recurse deeper
                let deeperProjects = findGitRepositoriesRecursively(in: url, currentDepth: currentDepth + 1, maxDepth: maxDepth)
                foundProjects.append(contentsOf: deeperProjects)
            }
        }
        
        return foundProjects
    }

    private func isGitRepo(_ path: String) -> Bool {
        let gitPath = (path as NSString).appendingPathComponent(".git")
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: gitPath, isDirectory: &isDir)
    }

    // MARK: - Project Management

    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        }
    }

    func getProject(byPath path: String) -> Project? {
        projects.first { $0.path == path }
    }
}
