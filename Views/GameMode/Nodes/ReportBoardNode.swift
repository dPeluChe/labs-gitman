import SpriteKit

class ReportBoardNode: SKNode {
    private var boardBackground: SKShapeNode!
    private var titleLabel: SKLabelNode!
    private var currentReportCard: ReportCardNode?
    
    var maxVisibleReports: Int = 1
    var onReportTap: ((ProjectReport) -> Void)?
    
    init(position: CGPoint) {
        super.init()
        self.position = position
        setupBoard()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupBoard() {
        boardBackground = ShapeFactory.createRoundedRect(
            size: CGSize(width: 350, height: 150),
            cornerRadius: 12,
            fillColor: NSColor(white: 0.15, alpha: 0.9),
            strokeColor: NSColor(white: 0.3, alpha: 1.0),
            lineWidth: 2
        )
        addChild(boardBackground)
        
        titleLabel = SKLabelNode(text: "📋 Reports")
        titleLabel.fontName = "Helvetica-Bold"
        titleLabel.fontSize = 14
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: 60)
        addChild(titleLabel)
    }
    
    func showReport(_ report: ProjectReport) {
        currentReportCard?.removeFromParent()
        
        let card = ReportCardNode(report: report)
        card.position = CGPoint(x: 0, y: 0)
        card.alpha = 0
        card.setScale(0.8)
        card.onTap = { [weak self] in
            self?.onReportTap?(report)
        }
        addChild(card)
        currentReportCard = card
        
        let appear = SKAction.group([
            SKAction.fadeIn(withDuration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.3)
        ])
        appear.timingMode = .easeOut
        card.run(appear)
    }
    
    func clearReports() {
        currentReportCard?.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ]))
        currentReportCard = nil
    }
}

class ReportCardNode: SKNode {
    let report: ProjectReport
    private var cardBackground: SKShapeNode!
    private var projectLabel: SKLabelNode!
    private var branchLabel: SKLabelNode!
    private var statusLabel: SKLabelNode!
    private var iconLabel: SKLabelNode!
    
    var onTap: (() -> Void)?
    
    init(report: ProjectReport) {
        self.report = report
        super.init()
        setupCard()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCard() {
        let cardColor = report.hasIssues ? 
            NSColor(red: 0.3, green: 0.2, blue: 0.2, alpha: 1.0) :
            NSColor(red: 0.2, green: 0.3, blue: 0.2, alpha: 1.0)
        
        cardBackground = ShapeFactory.createRoundedRect(
            size: CGSize(width: 300, height: 100),
            cornerRadius: 8,
            fillColor: cardColor,
            strokeColor: report.hasIssues ? 
                NSColor(red: 1.0, green: 0.42, blue: 0.42, alpha: 1.0) :
                NSColor(red: 0.31, green: 0.8, blue: 0.64, alpha: 1.0),
            lineWidth: 2
        )
        addChild(cardBackground)
        
        iconLabel = SKLabelNode(text: report.hasIssues ? "⚠️" : "✅")
        iconLabel.fontSize = 24
        iconLabel.position = CGPoint(x: -120, y: -5)
        addChild(iconLabel)
        
        projectLabel = SKLabelNode(text: report.project.name)
        projectLabel.fontName = "Helvetica-Bold"
        projectLabel.fontSize = 12
        projectLabel.fontColor = .white
        projectLabel.horizontalAlignmentMode = .left
        projectLabel.position = CGPoint(x: -90, y: 20)
        addChild(projectLabel)
        
        branchLabel = SKLabelNode(text: "🌿 \(report.status.currentBranch)")
        branchLabel.fontName = "Menlo-Regular"
        branchLabel.fontSize = 10
        branchLabel.fontColor = NSColor(white: 0.8, alpha: 1.0)
        branchLabel.horizontalAlignmentMode = .left
        branchLabel.position = CGPoint(x: -90, y: 0)
        addChild(branchLabel)
        
        var statusText = ""
        if report.status.hasUncommittedChanges {
            let total = report.status.modifiedFiles.count + report.status.untrackedFiles.count + report.status.stagedFiles.count
            statusText = "\(total) uncommitted changes"
        } else {
            statusText = "Clean working directory"
        }
        
        statusLabel = SKLabelNode(text: statusText)
        statusLabel.fontName = "Helvetica"
        statusLabel.fontSize = 9
        statusLabel.fontColor = NSColor(white: 0.7, alpha: 1.0)
        statusLabel.horizontalAlignmentMode = .left
        statusLabel.position = CGPoint(x: -90, y: -20)
        addChild(statusLabel)
        
        isUserInteractionEnabled = true
    }
    
    override func mouseDown(with event: NSEvent) {
        let pulse = SKAction.sequence([
            SKAction.scale(to: 0.95, duration: 0.1),
            SKAction.scale(to: 1.0, duration: 0.1)
        ])
        run(pulse)
        
        onTap?()
    }
}
