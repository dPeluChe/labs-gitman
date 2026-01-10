import SpriteKit
import OSLog
import AppKit

class OfficeScene: SKScene {
    weak var coordinator: GameCoordinator?
    
    private let grid = IsometricGrid(
        tileWidth: GameConstants.tileWidth,
        tileHeight: GameConstants.tileHeight
    )
    private let logger = Logger(subsystem: "com.gitmonitor", category: "OfficeScene")
    
    private var worldNode: SKNode! // Container for all 2.5D isometric content
    private var officeBackground: SKNode!
    private var deskNode: DeskNode!
    private var reportBoard: ReportBoardNode!
    private var debugOverlay: DebugOverlayNode!
    
    private var agents: [AgentNode] = []
    private var portals: [ProjectPortalNode] = []

    private var isProcessingQueue: Bool = false
    private var selectedAgent: AgentNode? // For manual control
    
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
        // Setup World Container centered on screen
        worldNode = SKNode()
        worldNode.position = CGPoint(x: size.width/2, y: size.height/2)
        addChild(worldNode)
        
        setupOffice()
        setupDesk()
        setupAgents()
        setupReportBoard() // HUD - attached to self
        setupDebugOverlay() // HUD - attached to self
        setupProjectPortals()
    }
    
    private func setupOffice() {
        officeBackground = SKNode()
        officeBackground.zPosition = -1000 // Deep background
        worldNode.addChild(officeBackground)
        
        let floorTiles = GameConstants.floorGridSize
        for row in 0..<floorTiles {
            for col in 0..<floorTiles {
                // Logical coords: centered around (0,0)
                let logicalX = col - floorTiles/2
                let logicalY = row - floorTiles/2
                
                let screenPos = grid.logicalToScreen(x: logicalX, y: logicalY)
                let floor = GameConstants.Colors.officeFloor
                let stroke = GameConstants.Colors.officeFloorStroke
                let tile = ShapeFactory.createIsometricTile(
                    width: grid.tileWidth,
                    height: grid.tileHeight,
                    fillColor: NSColor(red: floor.r, green: floor.g, blue: floor.b, alpha: floor.a),
                    strokeColor: NSColor(red: stroke.r, green: stroke.g, blue: stroke.b, alpha: stroke.a),
                    lineWidth: 1
                )
                tile.position = screenPos
                // Floor tiles zPosition:
                // They should always be behind objects on the same Y.
                // grid.zPosition(for: y) returns -y.
                // We subtract a large constant to ensure floor is always bottom.
                tile.zPosition = grid.zPosition(for: screenPos.y) - 500
                officeBackground.addChild(tile)
            }
        }
    }
    
    private func setupDesk() {
        // Desk at logical (0, -5) - Front Center
        let deskPos = grid.logicalToScreen(x: 0, y: -5)
        deskNode = DeskNode(position: deskPos, grid: grid)
        deskNode.zPosition = grid.zPosition(for: deskPos.y)
        worldNode.addChild(deskNode)
    }
    
    private func setupAgents() {
        let a1 = GameConstants.Colors.agent1
        let a2 = GameConstants.Colors.agent2
        
        // Spawn agents at specific logical tiles (Side areas)
        let agentConfigs: [(name: String, color: NSColor, startX: Int, startY: Int)] = [
            ("Agent 1", NSColor(red: a1.r, green: a1.g, blue: a1.b, alpha: a1.a), 3, -3),
            ("Agent 2", NSColor(red: a2.r, green: a2.g, blue: a2.b, alpha: a2.a), -3, -3)
        ]
        
        for config in agentConfigs {
            let agentPos = grid.logicalToScreen(x: config.startX, y: config.startY)
            let agent = AgentNode(
                id: UUID(),
                name: config.name,
                color: config.color,
                position: agentPos
            )
            agent.zPosition = grid.zPosition(for: agentPos.y)
            worldNode.addChild(agent)
            agents.append(agent)
        }
    }
    
    private func setupReportBoard() {
        // Position relative to Screen (HUD)
        // Bottom center
        let boardPos = CGPoint(x: size.width/2, y: size.height * GameConstants.reportBoardYPosition)
        reportBoard = ReportBoardNode(position: boardPos)
        reportBoard.zPosition = 1000 // HUD
        reportBoard.onReportTap = { [weak self] report in
            self?.handleReportTap(report)
        }
        addChild(reportBoard)
    }
    
    private func setupDebugOverlay() {
        debugOverlay = DebugOverlayNode()
        debugOverlay.position = CGPoint(x: 180, y: size.height - 120)
        debugOverlay.zPosition = 2000 // Top HUD
        addChild(debugOverlay)
    }
    
    private func setupProjectPortals() {
        guard let coordinator = coordinator else { return }

        let gitRepos = coordinator.projects.filter { $0.isGitRepository }
        let maxPortals = min(gitRepos.count, GameConstants.maxPortals) // Updated to 10
        
        logger.info("🎮 Setting up portals: \(gitRepos.count) git repos found, showing \(maxPortals)")
        
        // Remove existing portals
        portals.forEach { $0.removeFromParent() }
        portals.removeAll()
        
        if gitRepos.isEmpty {
            logger.warning("⚠️ No git repos to show! Make sure you've added monitored paths.")
            return
        }

        // Layout: Back Wall (y=5), Centered X
        let startY = 5
        let startX = -(maxPortals / 2)
        
        for (index, project) in gitRepos.prefix(maxPortals).enumerated() {
            let logicalX = startX + index
            let logicalY = startY
            
            let portalPos = grid.logicalToScreen(x: logicalX, y: logicalY)
            
            let portal = ProjectPortalNode(project: project, position: portalPos)
            portal.zPosition = grid.zPosition(for: portalPos.y)
            portal.onTap = { [weak self, weak portal] in
                guard let portal else { return }
                self?.handlePortalTap(portal.project)
            }
            worldNode.addChild(portal)
            portals.append(portal)
        }
    }
    
    private func handlePortalTap(_ project: Project) {
        guard let coordinator = coordinator else { return }
        
        coordinator.enqueueTask(for: project)
        
        if !isProcessingQueue {
            Task { await processNextTask() }
        }
    }
    
    // MARK: - Input Handling
    
    override func mouseDown(with event: NSEvent) {
        let locationInView = event.location(in: self)
        let worldPos = worldNode.convert(locationInView, from: self)
        let clickedNodes = worldNode.nodes(at: worldPos)
        
        var agentClicked = false
        for node in clickedNodes {
            var candidate = node
            while let parent = candidate.parent, candidate != worldNode {
                if let agent = candidate as? AgentNode {
                    selectAgent(agent)
                    agentClicked = true
                    break
                }
                candidate = parent
            }
            if agentClicked { break }
        }
        
        if agentClicked { return }
        
        // Tap on floor -> Move
        let (logX, logY) = grid.screenToLogical(point: worldPos)
        moveSelectedAgent(to: (logX, logY))
    }
    
    private func selectAgent(_ agent: AgentNode) {
        if let previous = selectedAgent {
            previous.setSelected(false)
        }
        selectedAgent = agent
        agent.setSelected(true)
        logger.info("Selected agent: \(agent.name ?? "Agent")")
    }
    
    private func moveSelectedAgent(to logical: (Int, Int)) {
        let agentToMove = selectedAgent ?? agents.first(where: { $0.isAvailable })
        guard let agent = agentToMove, agent.isAvailable else { return }
        
        if selectedAgent == nil { selectAgent(agent) }
        
        // Clamp to grid bounds to prevent leaving the room
        let limit = GameConstants.floorGridSize / 2 - 1
        let clampedX = max(-limit, min(limit, logical.0))
        let clampedY = max(-limit, min(limit, logical.1))
        
        let targetPos = grid.logicalToScreen(x: clampedX, y: clampedY)
        
        let marker = ShapeFactory.createCircle(radius: 5, fillColor: .white)
        marker.position = targetPos
        marker.alpha = 0.5
        marker.zPosition = 5
        worldNode.addChild(marker)
        marker.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ]))
        
        Task {
            await agent.commandMove(to: targetPos)
            // CRITICAL: Return to Idle state after manual move
            agent.stateMachine.enter(AgentIdleState.self)
            
            // Wake up dispatcher: "I'm free, is there work?"
            await processNextTask()
        }
    }
    
    // MARK: - Task Processing (Parallel)
    
    private func processNextTask() async {
        isProcessingQueue = true
        defer { isProcessingQueue = false }

        guard let coordinator = coordinator else { return }
        
        // Dispatch Loop
        while !coordinator.taskQueue.isEmpty {
            // Check for ANY available agent
            guard let agent = agents.first(where: { $0.isAvailable }) else {
                break // Stop if no agents
            }
            
            guard let task = coordinator.dequeueTask() else { break }
            
            // Find portal
            guard let portal = portals.first(where: { $0.project.path == task.project.path }) else {
                logger.warning("Portal not found for project: \(task.project.name)")
                continue
            }
            
            // Mark agent reserved synchronously to prevent race condition
            agent.isReserved = true
            
            // Spawn Worker (Fire and Forget)
            Task {
                await performTask(agent: agent, task: task, portal: portal)
                
                // Trigger dispatcher again when done to pick up new queue items
                await processNextTask()
            }
            
            // Small yield to prevent race conditions in loop
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
    
    private func performTask(agent: AgentNode, task: AgentTask, portal: ProjectPortalNode) async {
        // 1. Move
        await agent.commandMove(to: portal.position)
        
        portal.showActivity()
        agent.stateMachine.enter(AgentWorkingState.self)
        
        guard let coordinator = coordinator else { return }
        
        do {
            agent.isHidden = true
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            let status = try await coordinator.executeTask(task)
            
            try? await Task.sleep(nanoseconds: 200_000_000)
            agent.isHidden = false
            
            portal.hideActivity()
            portal.applyStatus(status)
            
            // 3. Return
            await agent.commandMove(to: deskNode.position)
            
            // 4. Report
            let report = ProjectReport(project: task.project, status: status, agentName: agent.name)
            coordinator.addReport(report)
            reportBoard.showReport(report)
            
            agent.commandPresent(report: report)
            
        } catch {
            logger.error("Task failed: \(error.localizedDescription)")
            agent.isHidden = false
            agent.stateMachine.enter(AgentIdleState.self)
            portal.hideActivity()
        }
    }
    
    private func handleReportTap(_ report: ProjectReport) {
        let alert = NSAlert()
        let agentText = report.agentName != nil ? " (by \(report.agentName!))" : ""
        alert.messageText = "📂 \(report.project.name)\(agentText)"
        
        if report.status.hasUncommittedChanges {
            let modified = report.status.modifiedFiles
            let untracked = report.status.untrackedFiles
            let staged = report.status.stagedFiles
            let totalCount = modified.count + untracked.count + staged.count
            
            var details = "⚠️ \(totalCount) uncommitted changes\nBranch: \(report.status.currentBranch)\n\n"
            let allFiles = (staged.map { "✅ \($0)" } + modified.map { "📝 \($0)" } + untracked.map { "❓ \($0)" })
            let showCount = min(allFiles.count, 10)
            details += allFiles.prefix(showCount).joined(separator: "\n")
            if allFiles.count > showCount { details += "\n...and \(allFiles.count - showCount) more" }
            alert.informativeText = details
            alert.alertStyle = .warning
        } else {
            alert.informativeText = "✅ Clean working directory\n\nBranch: \(report.status.currentBranch)\nLast commit: \(report.status.lastCommitMessage ?? "Unknown")"
            alert.alertStyle = .informational
        }
        alert.addButton(withTitle: "OK")
        
        // Clear report from board when viewed
        reportBoard.clearReports()
        
        alert.runModal()
    }
    
    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
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
                agent.zPosition = grid.zPosition(for: agent.position.y)
                let stateName = String(describing: type(of: agent.stateMachine.currentState!))
                    .replacingOccurrences(of: "Agent", with: "")
                    .replacingOccurrences(of: "State", with: "")
                debugOverlay.updateAgentState(index: index, stateDescription: stateName)
            }
        }
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 35 {
            debugOverlay.isVisible.toggle()
            if debugOverlay.isVisible {
                // Grid overlay logic
            } else {
                debugOverlay.hideGrid()
            }
        }
    }
    
    func refreshPortals() {
        setupProjectPortals()
    }
}
