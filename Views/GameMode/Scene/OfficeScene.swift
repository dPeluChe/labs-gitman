import SpriteKit
import OSLog
import AppKit

class OfficeScene: SKScene {
    weak var coordinator: GameCoordinator?
    
    private let grid = IsometricGrid(tileWidth: 80, tileHeight: 40)
    private let logger = Logger(subsystem: "com.gitmonitor", category: "OfficeScene")
    
    private var officeBackground: SKNode!
    private var deskNode: DeskNode!
    private var reportBoard: ReportBoardNode!
    private var debugOverlay: DebugOverlayNode!
    
    private var agents: [AgentNode] = []
    private var portals: [ProjectPortalNode] = []

    private var isProcessingQueue: Bool = false
    
    private var lastUpdateTime: TimeInterval = 0
    private var frameCount: Int = 0
    private var fps: Int = 0
    
    init(coordinator: GameCoordinator) {
        self.coordinator = coordinator
        super.init(size: CGSize(width: GameConstants.sceneWidth, height: GameConstants.sceneHeight))
        let bg = GameConstants.Colors.background
        self.backgroundColor = NSColor(red: bg.r, green: bg.g, blue: bg.b, alpha: bg.a)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMove(to view: SKView) {
        setupOffice()
        setupDesk()
        setupAgents()
        setupReportBoard()
        setupDebugOverlay()
        setupProjectPortals()
    }
    
    private func setupOffice() {
        officeBackground = SKNode()
        officeBackground.zPosition = -100
        addChild(officeBackground)
        
        let floorTiles = GameConstants.floorGridSize
        for row in 0..<floorTiles {
            for col in 0..<floorTiles {
                let screenPos = grid.logicalToScreen(x: col - floorTiles/2, y: row - floorTiles/2)
                let floor = GameConstants.Colors.officeFloor
                let stroke = GameConstants.Colors.officeFloorStroke
                let tile = ShapeFactory.createIsometricTile(
                    width: grid.tileWidth,
                    height: grid.tileHeight,
                    fillColor: NSColor(red: floor.r, green: floor.g, blue: floor.b, alpha: floor.a),
                    strokeColor: NSColor(red: stroke.r, green: stroke.g, blue: stroke.b, alpha: stroke.a),
                    lineWidth: 1
                )
                tile.position = CGPoint(x: screenPos.x + size.width/2, y: screenPos.y + size.height/2)
                tile.zPosition = grid.zPosition(for: screenPos.y)
                officeBackground.addChild(tile)
            }
        }
    }
    
    private func setupDesk() {
        let deskPos = CGPoint(x: size.width/2, y: size.height * GameConstants.deskYPosition)
        deskNode = DeskNode(position: deskPos, grid: grid)
        deskNode.zPosition = 10
        addChild(deskNode)
    }
    
    private func setupAgents() {
        let a1 = GameConstants.Colors.agent1
        let a2 = GameConstants.Colors.agent2
        let agentConfigs: [(name: String, color: NSColor, xOffset: CGFloat)] = [
            ("Agent 1", NSColor(red: a1.r, green: a1.g, blue: a1.b, alpha: a1.a), -80),
            ("Agent 2", NSColor(red: a2.r, green: a2.g, blue: a2.b, alpha: a2.a), 80)
        ]
        
        for (_, config) in agentConfigs.enumerated() {
            let agentPos = CGPoint(
                x: size.width/2 + config.xOffset,
                y: size.height * 0.35
            )
            let agent = AgentNode(
                id: UUID(),
                name: config.name,
                color: config.color,
                position: agentPos
            )
            agent.zPosition = 20
            addChild(agent)
            agents.append(agent)
        }
    }
    
    private func setupReportBoard() {
        let boardPos = CGPoint(x: size.width/2, y: size.height * GameConstants.reportBoardYPosition)
        reportBoard = ReportBoardNode(position: boardPos)
        reportBoard.zPosition = 5
        reportBoard.onReportTap = { [weak self] report in
            self?.handleReportTap(report)
        }
        addChild(reportBoard)
    }
    
    private func setupDebugOverlay() {
        debugOverlay = DebugOverlayNode()
        debugOverlay.position = CGPoint(x: 180, y: size.height - 120)
        debugOverlay.zPosition = 1000
        addChild(debugOverlay)
    }
    
    private func setupProjectPortals() {
        guard let coordinator = coordinator else { return }

        let gitRepos = coordinator.projects.filter { $0.isGitRepository }
        let maxPortals = min(gitRepos.count, GameConstants.maxPortals)
        
        logger.info("🎮 Setting up portals: \(gitRepos.count) git repos found, showing \(maxPortals)")
        
        if gitRepos.isEmpty {
            logger.warning("⚠️ No git repos to show! Make sure you've added monitored paths.")
            if !portals.isEmpty {
                return
            }
        }

        portals.forEach { $0.removeFromParent() }
        portals.removeAll()
        
        for (index, project) in gitRepos.prefix(maxPortals).enumerated() {
            let row = index / 3
            let col = index % 3
            
            let portalPos = CGPoint(
                x: size.width * GameConstants.portalStartX + CGFloat(col) * GameConstants.portalSpacingX,
                y: size.height * GameConstants.portalStartY - CGFloat(row) * GameConstants.portalSpacingY
            )
            
            let portal = ProjectPortalNode(project: project, position: portalPos)
            portal.zPosition = 15
            portal.onTap = { [weak self, weak portal] in
                guard let portal else { return }
                self?.handlePortalTap(portal.project)
            }
            addChild(portal)
            portals.append(portal)
        }
    }
    
    private func handlePortalTap(_ project: Project) {
        guard let coordinator = coordinator else { return }
        
        coordinator.enqueueTask(for: project)
        
        if !isProcessingQueue {
            Task {
                await processNextTask()
            }
        }
    }
    
    private func handleReportTap(_ report: ProjectReport) {
        logger.info("Report tapped for project: \(report.project.name)")
        
        let alert = NSAlert()
        alert.messageText = "📂 \(report.project.name)"
        
        if report.status.hasUncommittedChanges {
            let modified = report.status.modifiedFiles
            let untracked = report.status.untrackedFiles
            let staged = report.status.stagedFiles
            let totalCount = modified.count + untracked.count + staged.count
            
            var details = "⚠️ \(totalCount) uncommitted changes\nBranch: \(report.status.currentBranch)\n\n"
            
            let allFiles = (
                staged.map { "✅ \($0)" } +
                modified.map { "📝 \($0)" } +
                untracked.map { "❓ \($0)" }
            )
            
            let showCount = min(allFiles.count, 10)
            details += allFiles.prefix(showCount).joined(separator: "\n")
            
            if allFiles.count > showCount {
                details += "\n...and \(allFiles.count - showCount) more"
            }
            
            alert.informativeText = details
            alert.alertStyle = .warning
        } else {
            alert.informativeText = "✅ Clean working directory\n\nBranch: \(report.status.currentBranch)\nLast commit: \(report.status.lastCommitMessage ?? "Unknown")"
            alert.alertStyle = .informational
        }
        
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func processNextTask() async {
        isProcessingQueue = true
        defer { isProcessingQueue = false }

        guard let coordinator = coordinator else { return }
        
        // Find agent in IdleState
        guard let agent = agents.first(where: { $0.isAvailable }) else {
            logger.warning("No available agents")
            return
        }
        
        guard let task = coordinator.dequeueTask() else { return }
        
        guard let portal = portals.first(where: { $0.project.path == task.project.path }) else {
            logger.warning("Portal not found for project: \(task.project.name)")
            return
        }
        
        // 1. Move to Portal
        await agent.commandMove(to: portal.position)
        
        portal.showActivity()
        
        // 2. Work
        agent.stateMachine.enter(AgentWorkingState.self)
        
        do {
            // Simulate "walking into" portal
            agent.isHidden = true // Optional: hide agent while inside
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            let status = try await coordinator.executeTask(task)
            
            try? await Task.sleep(nanoseconds: 200_000_000)
            agent.isHidden = false
            
            portal.hideActivity()
            portal.applyStatus(status)
            
            // 3. Return to Desk
            await agent.commandMove(to: deskNode.position)
            
            // 4. Present Report
            let report = ProjectReport(project: task.project, status: status)
            coordinator.addReport(report)
            reportBoard.showReport(report)
            
            // This state handles celebration/alert and auto-return to idle
            // Hack: replace the state instance for this specific report
            // GKStateMachine doesn't make swapping easy by default, but we can just use the node helper I'll add.
            agent.commandPresent(report: report)
            
            // Trigger next task if any
            if !coordinator.taskQueue.isEmpty {
                // Detach to allow recursion without stack depth issues
                Task { await processNextTask() }
            }
            
        } catch {
            logger.error("Task execution failed: \(error.localizedDescription)")
            agent.isHidden = false
            agent.stateMachine.enter(AgentIdleState.self)
            portal.hideActivity()
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }
        
        let deltaTime = currentTime - lastUpdateTime
        if deltaTime >= 1.0 {
            fps = frameCount
            frameCount = 0
            lastUpdateTime = currentTime
            
            debugOverlay.updateFPS(fps)
        }
        frameCount += 1
        
        if let coordinator = coordinator {
            debugOverlay.updateQueueLength(coordinator.taskQueue.count)
            
            for (index, agent) in agents.enumerated() {
                let stateName = String(describing: type(of: agent.stateMachine.currentState!)).replacingOccurrences(of: "Agent", with: "").replacingOccurrences(of: "State", with: "")
                debugOverlay.updateAgentState(index: index, stateDescription: stateName)
            }
        }
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 35 {
            debugOverlay.isVisible.toggle()
            
            if debugOverlay.isVisible {
                debugOverlay.showGrid(in: self, grid: grid, rows: 8, cols: 8)
            } else {
                debugOverlay.hideGrid()
            }
        }
    }
    
    func refreshPortals() {
        setupProjectPortals()
    }
}
