import SwiftUI
import SpriteKit
import Combine
import OSLog

@MainActor
class GameCoordinator: ObservableObject {
    @Published var projects: [Project] = []
    @Published var taskQueue: [AgentTask] = []
    @Published var activeReports: [ProjectReport] = []
    @Published var isProcessing: Bool = false
    @Published var debugMode: Bool = false
    @Published var isDiscovering: Bool = false
    
    private let scannerViewModel: ProjectScannerViewModel
    private let configStore = ConfigStore()
    private let logger = Logger(subsystem: "com.gitmonitor", category: "GameCoordinator")
    
    var maxVisibleReports: Int = 1
    
    private var cancellables = Set<AnyCancellable>()
    
    init(scannerViewModel: ProjectScannerViewModel) {
        self.scannerViewModel = scannerViewModel
        
        scannerViewModel.$projects
            .assign(to: &$projects)
    }
    
    /// Fast discovery: Load project structure WITHOUT executing git commands
    /// This makes portals appear instantly in Game Mode
    func discoverProjectsForGameMode() async {
        isDiscovering = true
        logger.info("🎮 Starting fast discovery for Game Mode...")
        
        let discovered = await configStore.discoverProjects()
        
        // Flatten to get all git repos (including nested ones)
        var allGitRepos: [Project] = []
        for root in discovered {
            if root.isGitRepository {
                allGitRepos.append(root)
            }
            allGitRepos.append(contentsOf: root.subProjects.filter { $0.isGitRepository })
        }
        
        projects = allGitRepos
        logger.info("🎮 Fast discovery complete: \(allGitRepos.count) git repos ready for portals")
        isDiscovering = false
    }
    
    func enqueueTask(for project: Project) {
        let task = AgentTask(project: project)
        taskQueue.append(task)
        logger.info("Enqueued task for project: \(project.name)")
    }
    
    func dequeueTask() -> AgentTask? {
        guard !taskQueue.isEmpty else { return nil }
        return taskQueue.removeFirst()
    }
    
    func executeTask(_ task: AgentTask) async throws -> GitStatus {
        logger.info("Executing task for project: \(task.project.name)")
        
        await scannerViewModel.fullRefreshProjectStatus(task.project)
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        guard let updatedProject = scannerViewModel.getProject(byId: task.project.id),
              let status = updatedProject.gitStatus else {
            throw GameCoordinatorError.statusNotAvailable
        }
        
        return status
    }
    
    func addReport(_ report: ProjectReport) {
        activeReports.insert(report, at: 0)
        
        if activeReports.count > maxVisibleReports {
            activeReports = Array(activeReports.prefix(maxVisibleReports))
        }
        
        logger.info("Added report for project: \(report.project.name)")
    }
    
    func clearReports() {
        activeReports.removeAll()
    }
    
    func getUpdatedProject(_ projectId: UUID) -> Project? {
        return scannerViewModel.getProject(byId: projectId)
    }
}

enum GameCoordinatorError: Error {
    case statusNotAvailable
    case agentNotAvailable
}
