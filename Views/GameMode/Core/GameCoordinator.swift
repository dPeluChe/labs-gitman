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
    }
    
    /// Fast discovery: Load project structure WITHOUT executing git commands
    /// This makes portals appear instantly in Game Mode
    func discoverProjectsForGameMode() async {
        isDiscovering = true
        logger.info("🎮 Starting fast discovery for Game Mode...")
        defer { isDiscovering = false }

        let discovered = await configStore.discoverProjects()
        
        // Flatten to get all git repos (including nested ones)
        var allGitRepos: [Project] = []
        for root in discovered {
            if root.isGitRepository {
                allGitRepos.append(root)
            }
            allGitRepos.append(contentsOf: root.subProjects.filter { $0.isGitRepository })
        }
        
        // Sort by modification date (newest first) to show most relevant portals
        allGitRepos.sort { p1, p2 in
            let date1 = getModificationDate(at: p1.path)
            let date2 = getModificationDate(at: p2.path)
            return date1 > date2
        }
        
        projects = allGitRepos
        logger.info("🎮 Fast discovery complete: \(allGitRepos.count) git repos ready for portals")
    }
    
    private func getModificationDate(at path: String) -> Date {
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: path)
            return attr[.modificationDate] as? Date ?? Date.distantPast
        } catch {
            return Date.distantPast
        }
    }

    private func applyStatus(toProjectAtPath path: String, status: GitStatus) {
        if let index = projects.firstIndex(where: { $0.path == path }) {
            projects[index].gitStatus = status
            projects[index].lastScanned = Date()
        }
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

        // Use a timeout to ensure agents don't get stuck forever
        return try await withThrowingTaskGroup(of: GitStatus.self) { group in
            // Task 1: The actual work (DETACHED to prevent Main Thread Block)
            group.addTask {
                // We detach to ensure we are OFF the Main Actor.
                // Although scannerViewModel is @MainActor, calling it from here ensures
                // we await the result without blocking the UI thread setup.
                let taskResult = try await Task.detached(priority: .userInitiated) {
                    return try await self.scannerViewModel.fetchStatus(for: task.project)
                }.value
                return taskResult
            }
            
            // Task 2: The timeout
            group.addTask {
                try await Task.sleep(nanoseconds: 15 * 1_000_000_000) // 15 seconds
                throw GameCoordinatorError.timeout
            }
            
            // Return whichever finishes first
            let result = try await group.next()!
            group.cancelAll()
            
            // Update local state (Back on MainActor)
            await MainActor.run {
                self.applyStatus(toProjectAtPath: task.project.path, status: result)
                self.scannerViewModel.applyStatus(forPath: task.project.path, status: result)
            }
            
            return result
        }
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

    // MARK: - Auto Play Logic
    
    @Published var isAutoPlayActive: Bool = false
    private var autoPlayTask: Task<Void, Never>?
    private var currentAutoIndex: Int = 0
    
    func startAutoPlay() {
        guard !isAutoPlayActive else { return }
        isAutoPlayActive = true
        logger.info("🎮 Starting Auto Play (Game Mode)")
        
        autoPlayTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { return }
                await self.checkAndEnqueueAutoTask()
                
                // Wait randomly between 3 and 5 seconds before checking again
                // This creates a natural rhythm
                let delay = UInt64(Int.random(in: 3_000_000_000...5_000_000_000))
                try? await Task.sleep(nanoseconds: delay)
            }
        }
    }
    
    func stopAutoPlay() {
        isAutoPlayActive = false
        autoPlayTask?.cancel()
        autoPlayTask = nil
        logger.info("🎮 Stopped Auto Play")
    }
    
    private func checkAndEnqueueAutoTask() async {
        // Only enqueue if we have agents available (implied by low queue)
        // Keep queue small so users can intervene immediately
        guard taskQueue.count < 3 else { return }
        
        let gitRepos = projects.filter { $0.isGitRepository }
        guard !gitRepos.isEmpty else { return }
        
        // Option A: Only visible portals (GameConstants.maxPortals = 6 usually)
        let visibleCount = min(gitRepos.count, 6)
        let visibleProjects = Array(gitRepos.prefix(visibleCount))
        
        guard !visibleProjects.isEmpty else { return }
        
        let project = visibleProjects[currentAutoIndex % visibleProjects.count]
        currentAutoIndex += 1
        
        // Verify it isn't already in queue
        guard !taskQueue.contains(where: { $0.project.id == project.id }) else { return }
        
        logger.info("🤖 Auto-Enqueue: \(project.name)")
        
        // Ensure UI updates happen on MainActor, but logic doesn't block
        enqueueTask(for: project)
    }
}

enum GameCoordinatorError: Error {
    case statusNotAvailable
    case agentNotAvailable
    case timeout
}
