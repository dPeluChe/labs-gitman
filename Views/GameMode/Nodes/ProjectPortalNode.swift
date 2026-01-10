import SpriteKit

class ProjectPortalNode: SKNode {
    var project: Project
    private var portalShape: SKShapeNode!
    private var statusIndicator: SKShapeNode!
    private var nameLabel: SKLabelNode!
    private var statsLabel: SKLabelNode!
    
    var onTap: (() -> Void)?
    
    init(project: Project, position: CGPoint) {
        self.project = project
        super.init()
        self.position = position
        self.name = "portal_\(project.id.uuidString)"
        setupPortal()
        updateStatus()
    }

    func applyStatus(_ status: GitStatus) {
        project.gitStatus = status
        project.lastScanned = Date()
        updateStatus()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupPortal() {
        // Shadow
        let shadow = ShapeFactory.createShadow(width: GameConstants.portalWidth, height: GameConstants.portalWidth/2)
        shadow.position = CGPoint(x: 0, y: -GameConstants.portalWidth/3)
        addChild(shadow)
        
        // 2.5D Prism Body
        // Width: 60, Length (Depth): 60, Height: 80
        portalShape = ShapeFactory.createPrism(
            width: GameConstants.portalWidth, 
            length: GameConstants.portalWidth, 
            height: GameConstants.portalHeight, 
            color: portalColor()
        ) as? SKShapeNode // Cast might fail if createPrism returns SKNode, but we don't need it to be ShapeNode specifically here unless we change color
        
        // Actually createPrism returns SKNode container, so we need to handle color updates differently
        // Let's keep a reference to the container
        let prism = ShapeFactory.createPrism(
            width: GameConstants.portalWidth, 
            length: GameConstants.portalWidth, 
            height: GameConstants.portalHeight, 
            color: portalColor()
        )
        prism.name = "prism"
        addChild(prism)
        
        statusIndicator = ShapeFactory.createCircle(
            radius: 8,
            fillColor: statusColor(),
            strokeColor: .white,
            lineWidth: 2
        )
        statusIndicator.position = CGPoint(x: 0, y: GameConstants.portalHeight + 10) // Floating above
        addChild(statusIndicator)
        
        nameLabel = SKLabelNode(text: project.name)
        nameLabel.fontName = "Helvetica-Bold"
        nameLabel.fontSize = 10
        nameLabel.fontColor = .white
        nameLabel.position = CGPoint(x: 0, y: GameConstants.portalHeight + 30)
        nameLabel.preferredMaxLayoutWidth = 100
        nameLabel.numberOfLines = 2
        addChild(nameLabel)
        
        let icon = SKLabelNode(text: "📁")
        icon.fontSize = 24
        icon.position = CGPoint(x: 0, y: GameConstants.portalHeight/2) // On the front face
        icon.zPosition = 1 // Ensure it's in front of faces
        prism.addChild(icon)
        
        statsLabel = SKLabelNode(text: "")
        statsLabel.fontName = "Menlo-Regular"
        statsLabel.fontSize = 8
        statsLabel.fontColor = NSColor(white: 0.9, alpha: 1.0)
        statsLabel.position = CGPoint(x: 0, y: GameConstants.portalHeight + 50)
        addChild(statsLabel)
        
        isUserInteractionEnabled = true
    }
    
    private func portalColor() -> NSColor {
        guard let status = project.gitStatus else {
            // No git status yet (discovered but not scanned) - show neutral gray
            return NSColor(white: 0.5, alpha: 1.0)
        }
        
        if status.hasUncommittedChanges {
            return NSColor(red: 1.0, green: 0.79, blue: 0.24, alpha: 1.0)
        }
        
        return NSColor(red: 0.31, green: 0.8, blue: 0.64, alpha: 1.0)
    }
    
    private func statusColor() -> NSColor {
        guard let status = project.gitStatus else {
            // No status yet - show gray with question mark
            return NSColor(white: 0.6, alpha: 1.0)
        }
        
        if status.hasUncommittedChanges {
            return NSColor(red: 1.0, green: 0.42, blue: 0.42, alpha: 1.0)
        }
        
        if status.outgoingCommits > 0 {
            return NSColor(red: 1.0, green: 0.79, blue: 0.24, alpha: 1.0)
        }
        
        return NSColor(red: 0.31, green: 0.8, blue: 0.64, alpha: 1.0)
    }
    
    func updateStatus() {
        // Re-create prism on status change because updating 3 separate faces is complex without proper reference
        // Optimization: In real game engine we'd update texture/color property. Here we just rebuild.
        if let oldPrism = childNode(withName: "prism") {
            oldPrism.removeAllChildren() // Remove icon
            oldPrism.removeFromParent()
            
            let newPrism = ShapeFactory.createPrism(
                width: GameConstants.portalWidth,
                length: GameConstants.portalWidth,
                height: GameConstants.portalHeight,
                color: portalColor()
            )
            newPrism.name = "prism"
            newPrism.zPosition = 0
            addChild(newPrism)
            
            // Re-add icon
            let icon = SKLabelNode(text: "📁")
            icon.fontSize = 24
            icon.position = CGPoint(x: 0, y: GameConstants.portalHeight/2)
            icon.zPosition = 1
            newPrism.addChild(icon)
            
            // Re-order siblings if needed, but addChild puts it at end. 
            // We want prism behind labels.
            newPrism.zPosition = -1 
        }

        statusIndicator.fillColor = statusColor()
        nameLabel.text = project.name
        
        if let status = project.gitStatus {
            var stats: [String] = []
            if status.hasUncommittedChanges {
                let total = status.modifiedFiles.count + status.untrackedFiles.count + status.stagedFiles.count
                stats.append("\(total) changes")
            }
            if status.pendingPullRequests > 0 {
                stats.append("\(status.pendingPullRequests) PR")
            }
            statsLabel.text = stats.joined(separator: " • ")
        } else {
            // No git status yet - invite user to click
            statsLabel.text = "❓ Click to scan"
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.1),
            SKAction.scale(to: 1.0, duration: 0.1)
        ])
        run(pulse)
        
        onTap?()
    }
    
    func showActivity() {
        let glow = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.6, duration: 0.5),
            SKAction.fadeAlpha(to: 1.0, duration: 0.5)
        ])
        run(SKAction.repeatForever(glow), withKey: "activity")
    }
    
    func hideActivity() {
        removeAction(forKey: "activity")
        alpha = 1.0
    }
}
