import Foundation
import OSLog

/// Persistent storage for application configuration
@MainActor
class ConfigStore: ObservableObject {
    @Published var monitoredPaths: [String] = []
    @Published var projects: [Project] = []

    private let pathsKey = "monitoredPaths"
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.gitmonitor", category: "ConfigStore")

    // UserDefaults persistence
    private let defaults = UserDefaults.standard

    init() {
        loadMonitoredPaths()
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

    // MARK: - Project Discovery

    /// Scan all monitored paths and discover projects
    func scanMonitoredPaths() async -> [Project] {
        var discoveredProjects: [Project] = []

        for path in monitoredPaths {
            logger.info("Scanning monitored path: \(path)")
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
        
        logger.info("Total projects after scan: \(self.projects.count)")
        return projects
    }

    private func scanPathForProjects(_ path: String) async -> [Project] {
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            logger.error("Path does not exist or is not directory: \(path)")
            return []
        }

        // If the path itself is a git repo, return it as a project
        let gitPath = (path as NSString).appendingPathComponent(".git")
        if fileManager.fileExists(atPath: gitPath) {
            logger.info("Found git repo at root: \(path)")
            var project = Project(path: path)
            project.isGitRepository = true
            return [project]
        }

        // Otherwise, scan for subdirectories that are git repos
        var projects: [Project] = []

        guard let contents = try? fileManager.contentsOfDirectory(
            atPath: path
        ) else {
            logger.error("Failed to list contents of: \(path)")
            return []
        }

        for item in contents {
            let itemPath = (path as NSString).appendingPathComponent(item)

            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDir),
                  isDir.boolValue else {
                continue
            }

            // Skip hidden directories
            if item.hasPrefix(".") {
                continue
            }

            let itemGitPath = (itemPath as NSString).appendingPathComponent(".git")
            if fileManager.fileExists(atPath: itemGitPath) {
                logger.info("Found submodule/repo: \(itemPath)")
                var project = Project(path: itemPath)
                project.isGitRepository = true
                projects.append(project)
            } else {
                // Keep as non-git project
                let project = Project(path: itemPath)
                projects.append(project)
            }
        }

        return projects
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
