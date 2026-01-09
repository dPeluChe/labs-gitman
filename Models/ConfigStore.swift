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
            // Normalize paths and remove duplicates
            let normalizedPaths = savedPaths.map { URL(fileURLWithPath: $0).standardized.path }

            // Remove duplicates and nested paths
            let deduplicated = deduplicatePaths(normalizedPaths)

            monitoredPaths = deduplicated

            // If we removed duplicates, save the cleaned list
            if deduplicated.count != savedPaths.count {
                logger.warning("⚠️  Removed \(savedPaths.count - deduplicated.count) duplicate/nested monitored paths")
                saveMonitoredPaths()
            }
        }
    }

    /// Remove duplicate and nested paths from monitored paths
    /// Example: If we have ["/foo", "/foo/bar"], only keep "/foo"
    private func deduplicatePaths(_ paths: [String]) -> [String] {
        var uniquePaths: [String] = []

        for path in paths {
            // Check if this path is a child of any existing path
            let isNested = uniquePaths.contains { existingPath in
                path.hasPrefix(existingPath + "/") || path == existingPath
            }

            if !isNested {
                // Check if any existing path is a child of this path
                uniquePaths.removeAll { existingPath in
                    existingPath.hasPrefix(path + "/")
                }
                uniquePaths.append(path)
            }
        }

        return uniquePaths.sorted()
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
    
    /// Fast discovery: Only checks folder structure, NO git commands
    /// Perfect for Game Mode initial load - shows portals instantly
    func discoverProjects() async -> [Project] {
        var discoveredProjects: [Project] = []
        var visitedPaths: Set<String> = []
        
        logger.info("🚀 Fast discovery of \(self.monitoredPaths.count) monitored paths (no git commands)")
        
        for path in self.monitoredPaths {
            let normalizedPath = URL(fileURLWithPath: path).standardized.path
            if visitedPaths.contains(normalizedPath) { continue }
            visitedPaths.insert(normalizedPath)
            
            let projectsInPath = await discoverProjectsInPath(path, visitedPaths: &visitedPaths)
            discoveredProjects.append(contentsOf: projectsInPath)
            
            logger.info("  ✅ Discovered \(projectsInPath.count) project(s) in \(path)")
        }
        
        logger.info("🏁 Fast discovery complete: \(discoveredProjects.count) projects (ready for portals)")
        return discoveredProjects
    }
    
    /// Fast discovery helper - only checks .git folder existence
    private func discoverProjectsInPath(_ path: String, visitedPaths: inout Set<String>) async -> [Project] {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return []
        }
        
        var childProjects: [Project] = []
        let url = URL(fileURLWithPath: path)
        let keys: [URLResourceKey] = [.isDirectoryKey, .nameKey]
        
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return []
        }
        
        for folderURL in contents {
            let itemPath = folderURL.standardized.path
            let name = folderURL.lastPathComponent
            
            if visitedPaths.contains(itemPath) { continue }
            if ignoredPaths.contains(itemPath) || name.hasPrefix(".") || ["node_modules", "Pods", "build", "dist", ".git"].contains(name) { continue }
            
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue else { continue }
            
            visitedPaths.insert(itemPath)
            
            // Only check if .git folder exists (FAST, no git commands)
            if isGitRepo(itemPath) {
                logger.debug("✅ Discovered git repo: \(name)")
                childProjects.append(Project(path: itemPath, isGitRepository: true))
            } else {
                // Check for nested repos (shallow scan)
                let subRepos = findGitRepositoriesRecursively(in: folderURL, currentDepth: 0, maxDepth: 2, visitedPaths: &visitedPaths)
                
                if subRepos.count >= 2 {
                    logger.debug("🟡 Discovered workspace '\(name)' with \(subRepos.count) repos")
                    var workspace = Project(path: itemPath, isGitRepository: false, isWorkspace: true)
                    workspace.subProjects = subRepos
                    childProjects.append(workspace)
                } else if subRepos.count == 1 {
                    childProjects.append(contentsOf: subRepos)
                }
            }
        }
        
        let rootProject = Project(path: path, isGitRepository: isGitRepo(path), isWorkspace: !childProjects.isEmpty)
        var root = rootProject
        root.subProjects = childProjects
        return [root]
    }

    /// Scan all monitored paths and discover projects
    func scanMonitoredPaths() async -> [Project] {
        var discoveredProjects: [Project] = []
        var visitedPaths: Set<String> = [] // Track visited paths to prevent duplicates

        logger.info("🚀 Starting scan of \(self.monitoredPaths.count) monitored paths")

        for path in self.monitoredPaths {
            logger.debug("📂 Scanning monitored path: \(path)")

            // Normalize path for deduplication
            let normalizedPath = URL(fileURLWithPath: path).standardized.path
            if visitedPaths.contains(normalizedPath) {
                logger.warning("⚠️  Skipping duplicate monitored path: \(normalizedPath)")
                continue
            }
            visitedPaths.insert(normalizedPath)

            let projectsInPath = await scanPathForProjects(path, visitedPaths: &visitedPaths)
            discoveredProjects.append(contentsOf: projectsInPath)

            logger.info("  ✅ Found \(projectsInPath.count) root project(s) in \(path)")
        }

        logger.info("🏁 Scan complete: \(discoveredProjects.count) total root projects discovered")

        // CRITICAL SAFETY CHECK: Verify all discovered projects are marked as roots
        #if DEBUG
        let nonRoots = discoveredProjects.filter { !$0.isRoot }
        if !nonRoots.isEmpty {
            logger.error("❌ BUG: scanMonitoredPaths returned \(nonRoots.count) non-root projects!")
            for nr in nonRoots {
                logger.error("  - \(nr.name) at \(nr.path) (isRoot: false)")
            }
        }
        #endif

        return discoveredProjects
    }

    private func scanPathForProjects(_ path: String, visitedPaths: inout Set<String>) async -> [Project] {
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            logger.error("Path does not exist or is not directory: \(path)")
            return []
        }

        // 1. If the monitored path itself is a git repo, return it as a single root item
        // But here we want to return a root structure that contains children
        // The root itself is created at the end.
        
        // Check contents
        var childProjects: [Project] = []
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)
        let keys: [URLResourceKey] = [.isDirectoryKey, .nameKey]
        
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            logger.error("Failed to list contents of: \(path)")
            return []
        }
        
        for folderURL in contents {
            let itemPath = folderURL.standardized.path
            let name = folderURL.lastPathComponent
            
            if visitedPaths.contains(itemPath) { continue }
            
            // Skip system/common ignored items
            if ignoredPaths.contains(itemPath) || name.hasPrefix(".") || ["node_modules", "Pods", "build", "dist", ".git"].contains(name) { continue }
            
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue else { continue }
            
            visitedPaths.insert(itemPath)
            
            if isGitRepo(itemPath) {
                logger.debug("✅ Found git repo: \(name)")
                childProjects.append(Project(path: itemPath, isGitRepository: true))
            } else {
                let contents = try? fileManager.contentsOfDirectory(atPath: itemPath)
                let hasWorkspaceFile = contents?.contains { 
                    $0.hasSuffix(".code-workspace") || $0.hasSuffix(".xcworkspace")
                } ?? false
                
                let subRepos = findGitRepositoriesRecursively(in: folderURL, currentDepth: 0, maxDepth: 2, visitedPaths: &visitedPaths)
                
                if subRepos.count >= 2 {
                    logger.debug("🟡 Found workspace '\(name)' with \(subRepos.count) repos\(hasWorkspaceFile ? " (has workspace file)" : "")")
                    var workspace = Project(path: itemPath, isGitRepository: false, isWorkspace: true)
                    workspace.subProjects = subRepos
                    childProjects.append(workspace)
                } else if subRepos.count == 1 {
                    logger.debug("📦 Found wrapper folder '\(name)' - showing inner repo directly")
                    childProjects.append(contentsOf: subRepos)
                } else if hasWorkspaceFile {
                    logger.debug("🟡 Found workspace file in '\(name)' (no repos yet)")
                    childProjects.append(Project(path: itemPath, isGitRepository: false, isWorkspace: true))
                } else {
                    logger.debug("⏭️ Skipping empty folder: \(name)")
                }
            }
        }


        // Create the Root Project (The Monitored Path) acting as the Top-Level Workspace
        var rootProject = Project(path: path, isGitRepository: false, isWorkspace: true, isRoot: true)
        rootProject.subProjects = childProjects  // Sorting will be handled by UI layer
        
        return [rootProject]
    }
    
    /// Recursively find git repositories in a directory
    private func findGitRepositoriesRecursively(in rootURL: URL, currentDepth: Int, maxDepth: Int, visitedPaths: inout Set<String>) -> [Project] {
        if currentDepth >= maxDepth { return [] }
        
        var foundProjects: [Project] = []
        let keys: [URLResourceKey] = [.isDirectoryKey]
        
        guard let contents = try? fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return []
        }
        
        for url in contents {
            let path = url.standardized.path
            
            // Deduplication check
            if visitedPaths.contains(path) { continue }
            
            // Skip common dependency/build folders to improve performance and reduce noise
            if ["node_modules", "Pods", "Carthage", ".build", "build", "dist", "vendor", "venv", ".env"].contains(url.lastPathComponent) {
                continue
            }
            
            if ignoredPaths.contains(path) { continue }
            
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { continue }
            
            // Mark as visited
            visitedPaths.insert(path)
            
            if isGitRepo(path) {
                // Found one! Add it and do NOT recurse inside it (submodules handled by git)
                foundProjects.append(Project(path: path, isGitRepository: true))
            } else {
                // Recurse deeper
                let deeperProjects = findGitRepositoriesRecursively(in: url, currentDepth: currentDepth + 1, maxDepth: maxDepth, visitedPaths: &visitedPaths)
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
