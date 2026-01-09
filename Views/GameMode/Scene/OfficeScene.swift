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
        
        portals.forEach { $0.removeFromParent() }
        portals.removeAll()
        
        let gitRepos = coordinator.projects.filter { $0.isGitRepository }
        let maxPortals = min(gitRepos.count, GameConstants.maxPortals)
        
        logger.info("🎮 Setting up portals: \(gitRepos.count) git repos found, showing \(maxPortals)")
        
        if gitRepos.isEmpty {
            logger.warning("⚠️ No git repos to show! Make sure you've added monitored paths.")
        }
        
        for (index, project) in gitRepos.prefix(maxPortals).enumerated() {
            let row = index / 3
            let col = index % 3
            
            let portalPos = CGPoint(
                x: size.width * GameConstants.portalStartX + CGFloat(col) * GameConstants.portalSpacingX,
                y: size.height * GameConstants.portalStartY - CGFloat(row) * GameConstants.portalSpacingY
            )
            
            let portal = ProjectPortalNode(project: project, position: portalPos)
            portal.zPosition = 15
            portal.onTap = { [weak self] in
                self?.handlePortalTap(project)
            }
            addChild(portal)
            portals.append(portal)
        }
    }
    
    private func handlePortalTap(_ project: Project) {
        guard let coordinator = coordinator else { return }
        
        coordinator.enqueueTask(for: project)
        
        Task {
            await processNextTask()
        }
    }
    
    private func handleReportTap(_ report: ProjectReport) {
        logger.info("Report tapped for project: \(report.project.name)")
        
        let alert = NSAlert()
        alert.messageText = "📂 \(report.project.name)"
        
        if report.status.hasUncommittedChanges {
            let total = report.status.modifiedFiles.count + report.status.untrackedFiles.count + report.status.stagedFiles.count
            alert.informativeText = "⚠️ \(total) uncommitted changes\n\nBranch: \(report.status.currentBranch)"
            alert.alertStyle = .warning
        } else {
            alert.informativeText = "✅ Clean working directory\n\nBranch: \(report.status.currentBranch)"
            alert.alertStyle = .informational
        }
        
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func processNextTask() async {
        guard let coordinator = coordinator else { return }
        guard let agent = agents.first(where: { $0.state.isAvailable }) else {
            logger.warning("No available agents")
            return
        }
        
        guard let task = coordinator.dequeueTask() else { return }
        
        guard let portal = portals.first(where: { $0.project.id == task.project.id }) else {
            logger.warning("Portal not found for project: \(task.project.name)")
            return
        }
        
        agent.state = .walkingToPortal(projectId: task.project.id)
        portal.showActivity()
        
        await agent.moveTo(position: portal.position, duration: 1.0)
        
        agent.state = .enteringPortal
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        agent.state = .working(progress: 0.0)
        
        do {
            let status = try await coordinator.executeTask(task)
            
            agent.state = .working(progress: 1.0)
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            agent.state = .exitingPortal
            portal.hideActivity()
            portal.updateStatus()
            
            agent.state = .returningWithReport(status)
            await agent.moveTo(position: deskNode.position, duration: 1.0)
            
            agent.state = .presentingReport
            
            let report = ProjectReport(project: task.project, status: status)
            coordinator.addReport(report)
            reportBoard.showReport(report)
            
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            if status.hasUncommittedChanges {
                agent.state = .alerting
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            } else {
                agent.state = .celebrating
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            
            agent.state = .idle
            
            if !coordinator.taskQueue.isEmpty {
                await processNextTask()
            }
            
        } catch {
            logger.error("Task execution failed: \(error.localizedDescription)")
            agent.state = .idle
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
                debugOverlay.updateAgentState(index: index, state: agent.state)
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
