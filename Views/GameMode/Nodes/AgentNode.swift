import SpriteKit

class AgentNode: SKNode {
    var agentId: UUID
    var state: AgentState = .idle {
        didSet {
            updateVisualState()
        }
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
        playIdleAnimation()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
    
    private func playIdleAnimation() {
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
    
    private func stopIdleAnimation() {
        bodyNode.removeAction(forKey: "idle")
        headNode.removeAction(forKey: "headIdle")
    }
    
    func moveTo(position: CGPoint, duration: TimeInterval = 1.0) async {
        stopIdleAnimation()
        
        let angle = atan2(position.y - self.position.y, position.x - self.position.x)
        directionIndicator.zRotation = angle - .pi / 2
        
        let moveAction = SKAction.move(to: position, duration: duration)
        moveAction.timingMode = .easeInEaseOut
        
        let walkBob = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 5, duration: 0.15),
            SKAction.moveBy(x: 0, y: -5, duration: 0.15)
        ])
        bodyNode.run(SKAction.repeatForever(walkBob), withKey: "walk")
        
        await self.runAsync(moveAction)
        
        bodyNode.removeAction(forKey: "walk")
        bodyNode.position = .zero
    }
    
    func showWorkingState(progress: Float) {
        progressBar?.removeFromParent()
        
        let bar = ShapeFactory.createProgressBar(
            width: 40,
            height: 6,
            progress: progress,
            backgroundColor: NSColor(white: 0.3, alpha: 0.8),
            fillColor: NSColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)
        )
        bar.position = CGPoint(x: 0, y: 50)
        addChild(bar)
        progressBar = bar
        
        let spin = SKAction.rotate(byAngle: .pi * 2, duration: 1.0)
        headNode.run(SKAction.repeatForever(spin), withKey: "working")
    }
    
    func hideWorkingState() {
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
    
    private func updateVisualState() {
        switch state {
        case .idle:
            hideWorkingState()
            playIdleAnimation()
        case .walkingToPortal:
            hideWorkingState()
        case .working(let progress):
            showWorkingState(progress: progress)
        case .celebrating:
            hideWorkingState()
            celebrate()
        case .alerting:
            hideWorkingState()
            alert()
        default:
            break
        }
    }
}
