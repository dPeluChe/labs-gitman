import SpriteKit

class ProjectPortalNode: SKNode {
    let project: Project
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
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupPortal() {
        portalShape = ShapeFactory.createRoundedRect(
            size: CGSize(width: 80, height: 100),
            cornerRadius: 12,
            fillColor: portalColor(),
            strokeColor: portalColor().blended(withFraction: 0.3, of: .black),
            lineWidth: 3
        )
        addChild(portalShape)
        
        statusIndicator = ShapeFactory.createCircle(
            radius: 8,
            fillColor: statusColor(),
            strokeColor: .white,
            lineWidth: 2
        )
        statusIndicator.position = CGPoint(x: 30, y: 40)
        addChild(statusIndicator)
        
        nameLabel = SKLabelNode(text: project.name)
        nameLabel.fontName = "Helvetica-Bold"
        nameLabel.fontSize = 10
        nameLabel.fontColor = .white
        nameLabel.position = CGPoint(x: 0, y: -60)
        nameLabel.preferredMaxLayoutWidth = 100
        nameLabel.numberOfLines = 2
        addChild(nameLabel)
        
        let icon = SKLabelNode(text: "📁")
        icon.fontSize = 32
        icon.position = CGPoint(x: 0, y: -5)
        addChild(icon)
        
        statsLabel = SKLabelNode(text: "")
        statsLabel.fontName = "Menlo-Regular"
        statsLabel.fontSize = 8
        statsLabel.fontColor = NSColor(white: 0.9, alpha: 1.0)
        statsLabel.position = CGPoint(x: 0, y: -30)
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
        portalShape.fillColor = portalColor()
        portalShape.strokeColor = portalColor().blended(withFraction: 0.3, of: .black) ?? portalColor()
        statusIndicator.fillColor = statusColor()
        
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
