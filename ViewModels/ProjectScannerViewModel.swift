import Foundation
import OSLog
import SwiftUI

@MainActor
class ProjectScannerViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var isScanning = false
    @Published var errorMessage: String?
    @Published var missingDependencies: [GitService.DependencyStatus] = []

    private let configStore = ConfigStore()
    private let gitService = GitService()
    private let logger = Logger(subsystem: "com.gitmonitor", category: "ProjectScanner")

    init() {
        loadProjects()
    }
    
    func checkDependencies() async {
        let missing = await gitService.checkDependencies()
        missingDependencies = missing
        if !missing.isEmpty {
             logger.warning("Missing dependencies: \(missing)")
        }
    }

    func scanAllProjects() async {
        isScanning = true
        errorMessage = nil
        logger.info("Starting project scan")

        // 1. Discover projects (identifies which are git repos)
        let discoveredProjects = await configStore.scanMonitoredPaths()
        
        // IMMEDIATE UI UPDATE: Show discovered projects immediately so the list is not empty
        // We preserve existing projects' GitStatus if they match, to avoid flickering to "Loading..." if possible
        var mergedProjects: [Project] = []
        for newProject in discoveredProjects {
            if let existing = projects.first(where: { $0.path == newProject.path }) {
                // Keep existing status while we refresh
                var p = newProject
                p.gitStatus = existing.gitStatus
                mergedProjects.append(p)
            } else {
                mergedProjects.append(newProject)
            }
        }
        self.projects = mergedProjects.sorted { $0.name < $1.name }
        
        // 2. Fetch details for git repos in batches to avoid system overload
        let batchSize = 5
        let gitProjects = self.projects.filter { $0.isGitRepository }
        
        for batch in gitProjects.chunked(into: batchSize) {
            await withTaskGroup(of: Void.self) { group in
                for project in batch {
                    group.addTask {
                        await self.refreshProjectStatus(project)
                    }
                }
            }
        }

        logger.info("Scan completed. Total: \(self.projects.count)")
        isScanning = false
    }

    func refreshProjectStatus(_ project: Project) async {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        
        // Visual indicator logic handled by gitStatus being nil initially or updating lastScanned
        do {
            let gitStatus = try await gitService.getStatus(for: project)
            
            // UI Update on MainActor
            if projects.indices.contains(index) {
                projects[index].gitStatus = gitStatus
                projects[index].lastScanned = Date()
                projects[index].isGitRepository = true
            }
        } catch {
            logger.error("Failed to refresh project \(project.name): \(error.localizedDescription)")
            
            // Soft failure handling: If it's a workspace root or error 0, just mark it as scanned but maybe invalid status?
            if projects.indices.contains(index) {
                projects[index].lastScanned = Date() 
            }
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
        // Refresh local list immediately
        self.projects.removeAll { $0.path == path }
    }

    func getMonitoredPaths() -> [String] {
        configStore.monitoredPaths
    }

    private func loadProjects() {
        projects = configStore.projects
    }

    func getProject(byPath path: String) -> Project? {
        projects.first { $0.path == path }
    }

    var gitRepositories: [Project] {
        projects.filter { $0.isGitRepository }
    }

    var nonGitProjects: [Project] {
        projects.filter { !$0.isGitRepository }
    }

    var projectsNeedingAttention: [Project] {
        projects.filter { $0.gitStatus?.hasUncommittedChanges == true }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
