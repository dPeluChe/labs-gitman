import SpriteKit
import GameplayKit

class AgentNode: SKNode {
    var agentId: UUID
    var stateMachine: GKStateMachine!
    
    // Helper to check if agent is free to take tasks
    var isAvailable: Bool {
        return stateMachine.currentState is AgentIdleState
    }
    
    private var bodyNode: SKShapeNode!
    private var headNode: SKShapeNode!
    private var directionIndicator: SKShapeNode!
    private var nameLabel: SKLabelNode!
    private var progressBar: SKNode?
    
    private let agentColor: NSColor
    
    init(id: UUID, name: String, color: NSColor, position: CGPoint) {
        self.agentId = id
        self.agentColor = color
        super.init()
        self.name = name
        self.position = position
        setupAgent(name: name)
        setupStateMachine()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupStateMachine() {
        stateMachine = GKStateMachine(states: [
            AgentIdleState(agentNode: self),
            AgentWorkingState(agentNode: self),
            AgentAlertState(agentNode: self)
            // Moving/Presenting states are created dynamically as they need parameters
        ])
        stateMachine.enter(AgentIdleState.self)
    }
    
    private func setupAgent(name: String) {
        bodyNode = ShapeFactory.createRoundedRect(
            size: CGSize(width: 30, height: 40),
            cornerRadius: 8,
            fillColor: agentColor,
            strokeColor: agentColor.blended(withFraction: 0.3, of: .black),
            lineWidth: 2
        )
        addChild(bodyNode)
        
        headNode = ShapeFactory.createCircle(
            radius: 12,
            fillColor: agentColor.blended(withFraction: 0.2, of: .white)!,
            strokeColor: agentColor.blended(withFraction: 0.3, of: .black),
            lineWidth: 2
        )
        headNode.position = CGPoint(x: 0, y: 30)
        addChild(headNode)
        
        directionIndicator = ShapeFactory.createTriangle(
            size: 8,
            fillColor: .white,
            strokeColor: .clear
        )
        directionIndicator.position = CGPoint(x: 0, y: -25)
        addChild(directionIndicator)
        
        nameLabel = SKLabelNode(text: name)
        nameLabel.fontName = "Helvetica-Bold"
        nameLabel.fontSize = 9
        nameLabel.fontColor = .white
        nameLabel.position = CGPoint(x: 0, y: -45)
        addChild(nameLabel)
    }
    
    // MARK: - Animation Primitives (Called by States)
    
    func playIdleAnimation() {
        let bob = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 3, duration: 0.6),
            SKAction.moveBy(x: 0, y: -3, duration: 0.6)
        ])
        bodyNode.run(SKAction.repeatForever(bob), withKey: "idle")
        
        let headBob = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 2, duration: 0.6),
            SKAction.moveBy(x: 0, y: -2, duration: 0.6)
        ])
        headNode.run(SKAction.repeatForever(headBob), withKey: "headIdle")
    }
    
    func stopIdleAnimation() {
        bodyNode.removeAction(forKey: "idle")
        headNode.removeAction(forKey: "headIdle")
    }
    
    func performMove(to targetPos: CGPoint) async {
        let angle = atan2(targetPos.y - self.position.y, targetPos.x - self.position.x)
        directionIndicator.zRotation = angle - .pi / 2
        
        let distance = hypot(targetPos.x - self.position.x, targetPos.y - self.position.y)
        let speed: CGFloat = 200.0 // pixels per second
        let duration = TimeInterval(distance / speed)
        
        let moveAction = SKAction.move(to: targetPos, duration: duration)
        // Linear usually looks better for isometric pathfinding, but EaseInEaseOut is ok for direct lines
        moveAction.timingMode = .easeInEaseOut
        
        let walkBob = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 5, duration: 0.15),
            SKAction.moveBy(x: 0, y: -5, duration: 0.15)
        ])
        bodyNode.run(SKAction.repeatForever(walkBob), withKey: "walk")
        
        await self.runAsync(moveAction)
        
        bodyNode.removeAction(forKey: "walk")
        bodyNode.position = .zero // Reset bobbing offset
    }
    
    func startWorkingAnimation() {
        // Show progress bar
        let bar = ShapeFactory.createProgressBar(
            width: 40,
            height: 6,
            progress: 0.0, // Indeterminate or starting at 0
            backgroundColor: NSColor(white: 0.3, alpha: 0.8),
            fillColor: NSColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)
        )
        bar.position = CGPoint(x: 0, y: 50)
        addChild(bar)
        progressBar = bar
        
        // Spin head or do something "busy"
        let spin = SKAction.rotate(byAngle: .pi * 2, duration: 1.0)
        headNode.run(SKAction.repeatForever(spin), withKey: "working")
    }
    
    func stopWorkingAnimation() {
        progressBar?.removeFromParent()
        progressBar = nil
        headNode.removeAction(forKey: "working")
        headNode.zRotation = 0
    }
    
    func celebrate() {
        let jump = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 20, duration: 0.2),
            SKAction.moveBy(x: 0, y: -20, duration: 0.2)
        ])
        run(SKAction.repeat(jump, count: 2))
        
        let sparkle = SKLabelNode(text: "✨")
        sparkle.fontSize = 20
        sparkle.position = CGPoint(x: 0, y: 60)
        addChild(sparkle)
        
        let fadeOut = SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ])
        sparkle.run(fadeOut)
    }
    
    func alert() {
        let shake = SKAction.sequence([
            SKAction.moveBy(x: -3, y: 0, duration: 0.05),
            SKAction.moveBy(x: 6, y: 0, duration: 0.1),
            SKAction.moveBy(x: -6, y: 0, duration: 0.1),
            SKAction.moveBy(x: 3, y: 0, duration: 0.05)
        ])
        run(SKAction.repeat(shake, count: 2))
        
        let warning = SKLabelNode(text: "⚠️")
        warning.fontSize = 20
        warning.position = CGPoint(x: 0, y: 60)
        addChild(warning)
        
        let fadeOut = SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ])
        warning.run(fadeOut)
    }
    // MARK: - Command Methods (Bridge to State Machine)
    
    func commandMove(to target: CGPoint) async {
        await withCheckedContinuation { continuation in
            let movingState = AgentMovingState(agentNode: self, target: target) {
                continuation.resume()
            }
            // Manually rebuild the state machine to include the new dynamic state
            self.stateMachine = GKStateMachine(states: [
                movingState,
                AgentIdleState(agentNode: self),
                AgentWorkingState(agentNode: self),
                AgentAlertState(agentNode: self)
            ])
            self.stateMachine.enter(AgentMovingState.self)
        }
    }
    
    func commandPresent(report: ProjectReport) {
        let presentingState = AgentPresentingState(agentNode: self, report: report)
        self.stateMachine = GKStateMachine(states: [
            presentingState,
            AgentIdleState(agentNode: self),
            AgentWorkingState(agentNode: self),
            AgentAlertState(agentNode: self)
        ])
        self.stateMachine.enter(AgentPresentingState.self)
    }
}
