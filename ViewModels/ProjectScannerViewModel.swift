import Foundation
import OSLog

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
        // Load existing projects
        loadProjects()
    }
    
    // MARK: - Dependencies
    
    func checkDependencies() async {
        let missing = await gitService.checkDependencies()
        missingDependencies = missing
        
        if !missing.isEmpty {
             logger.warning("Missing dependencies: \(missing)")
        }
    }

    // MARK: - Scanning

    func scanAllProjects() async {
        isScanning = true
        errorMessage = nil

        logger.info("Starting project scan")

        do {
            // Discover projects from monitored paths
            let discoveredProjects = await configStore.scanMonitoredPaths()

            // Update git status for each project
            var updatedProjects: [Project] = []

            for project in discoveredProjects {
                if project.isGitRepository {
                    let gitStatus = try? await gitService.getStatus(for: project)
                    var updatedProject = project
                    updatedProject.gitStatus = gitStatus
                    updatedProject.isGitRepository = true
                    updatedProjects.append(updatedProject)
                } else {
                    updatedProjects.append(project)
                }
            }

            projects = updatedProjects
            logger.info("Scan completed. Found \(self.projects.count) projects")
        }

        isScanning = false
    }

    func refreshProjectStatus(_ project: Project) async {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else {
            return
        }

        guard project.isGitRepository else {
            return
        }

        do {
            let gitStatus = try await gitService.getStatus(for: project)
            projects[index].gitStatus = gitStatus
            projects[index].lastScanned = Date()
        } catch {
            logger.error("Failed to refresh project \(project.name): \(error.localizedDescription)")
        }
    }

    // MARK: - Path Management

    func addMonitoredPath(_ path: String) {
        configStore.addMonitoredPath(path)
    }

    func removeMonitoredPath(_ path: String) {
        configStore.removeMonitoredPath(path)
    }

    func getMonitoredPaths() -> [String] {
        configStore.monitoredPaths
    }

    // MARK: - Project Management

    private func loadProjects() {
        projects = configStore.projects
    }

    func getProject(byPath path: String) -> Project? {
        projects.first { $0.path == path }
    }

    // MARK: - Computed Properties

    var gitRepositories: [Project] {
        projects.filter { $0.isGitRepository }
    }

    var nonGitProjects: [Project] {
        projects.filter { !$0.isGitRepository }
    }

    var projectsNeedingAttention: [Project] {
        projects.filter { $0.gitStatus?.hasUncommittedChanges == true }
    }

    var projectCount: Int {
        projects.count
    }

    var repositoryCount: Int {
        gitRepositories.count
    }
}
