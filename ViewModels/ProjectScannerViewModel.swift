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
        
        // 2. Fetch details for git repos in parallel
        await withTaskGroup(of: Void.self) { group in
            for project in self.projects where project.isGitRepository {
                group.addTask {
                    await self.refreshProjectStatus(project)
                }
            }
        }

        logger.info("Scan completed. Total: \(self.projects.count)")
        isScanning = false
    }

    func refreshProjectStatus(_ project: Project) async {
        // Since we are inside a task group, we might want to check if the project still exists in our list
        // but for now, we just find it by ID.
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        
        // Visual indicator that we are refreshing this specific row? 
        // For now, the "Loading..." state in UI handles it if gitStatus is nil.
        // If we want a spinner on existing rows, we'd need a separate state, but let's keep it simple for now.

        do {
            let gitStatus = try await gitService.getStatus(for: project)
            
            // UI Update on MainActor
            if projects.indices.contains(index) {
                projects[index].gitStatus = gitStatus
                projects[index].lastScanned = Date()
                // Ensure isGitRepository is definitely true
                projects[index].isGitRepository = true
            }
        } catch {
            logger.error("Failed to refresh project \(project.name): \(error.localizedDescription)")
            // We don't set errorMessage here to avoid spamming the global alert for every single project failure
            // But we could maybe set a status on the project itself if we had an error field on the model.
        }
    }

    func addMonitoredPath(_ path: String) {
        configStore.addMonitoredPath(path)
    }

    func removeMonitoredPath(_ path: String) {
        configStore.removeMonitoredPath(path)
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
