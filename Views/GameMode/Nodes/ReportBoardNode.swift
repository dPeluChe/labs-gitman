import SpriteKit

class ReportBoardNode: SKNode {
    private var boardBackground: SKShapeNode!
    private var titleLabel: SKLabelNode!
    private var reportCards: [ReportCardNode] = []
    private var cardStack: SKNode!

    var maxVisibleReports: Int = 3
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
            size: CGSize(width: 380, height: 220),
            cornerRadius: 16,
            fillColor: NSColor(white: 0.12, alpha: 0.95),
            strokeColor: NSColor(white: 0.25, alpha: 1.0),
            lineWidth: 1
        )
        addChild(boardBackground)

        titleLabel = SKLabelNode(text: "📋 Activity Log")
        titleLabel.fontName = "Helvetica-Bold"
        titleLabel.fontSize = 16
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: 90)
        addChild(titleLabel)

        cardStack = SKNode()
        cardStack.position = CGPoint(x: 0, y: -20)
        addChild(cardStack)
    }

    func showReport(_ report: ProjectReport) {
        let card = ReportCardNode(report: report)

        if reportCards.count >= maxVisibleReports {
            let oldCard = reportCards.removeFirst()
            oldCard.removeFromParent()

            for card in reportCards {
                let moveDown = SKAction.moveBy(x: 0, y: -110, duration: 0.3)
                moveDown.timingMode = .easeOut
                card.run(moveDown)
            }
        }

        card.position = CGPoint(x: 0, y: CGFloat(reportCards.count) * 110)
        card.alpha = 0
        card.setScale(0.8)
        card.onTap = { [weak self] in
            self?.onReportTap?(report)
        }

        cardStack.addChild(card)
        reportCards.append(card)

        let appear = SKAction.group([
            SKAction.fadeIn(withDuration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.3)
        ])
        appear.timingMode = .easeOut
        card.run(appear)
    }

    func clearReports() {
        for card in reportCards {
            card.removeFromParent()
        }
        reportCards.removeAll()
    }

    func dismissTopReport() {
        guard let topCard = reportCards.last else { return }

        topCard.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.scale(to: 0.8, duration: 0.2)
            ]),
            SKAction.removeFromParent()
        ]))

        reportCards.removeLast()
    }
}

class ReportCardNode: SKNode {
    let report: ProjectReport
    private var cardBackground: SKShapeNode!
    private var leftBar: SKShapeNode!
    private var projectLabel: SKLabelNode!
    private var branchLabel: SKLabelNode!
    private var statusLine1: SKLabelNode!
    private var statusLine2: SKLabelNode!
    private var iconLabel: SKLabelNode!
    private var agentBadge: SKLabelNode!
    private var timeLabel: SKLabelNode!

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
        let hasIssues = report.hasIssues
        let severity = report.severity

        let barColor = severity.color
        let cardColor = hasIssues ?
            NSColor(red: 0.18, green: 0.15, blue: 0.15, alpha: 0.95) :
            NSColor(red: 0.15, green: 0.18, blue: 0.16, alpha: 0.95)

        let cardWidth: CGFloat = 340
        let cardHeight: CGFloat = 95

        cardBackground = ShapeFactory.createRoundedRect(
            size: CGSize(width: cardWidth, height: cardHeight),
            cornerRadius: 10,
            fillColor: cardColor,
            strokeColor: barColor,
            lineWidth: hasIssues ? 2 : 1
        )
        addChild(cardBackground)

        leftBar = SKShapeNode()
        leftBar.path = CGPath(roundedRect: CGRect(x: -cardWidth/2, y: -cardHeight/2, width: 5, height: cardHeight),
                             cornerWidth: 3, cornerHeight: 3, transform: nil)
        leftBar.fillColor = barColor
        leftBar.strokeColor = .clear
        leftBar.zPosition = 1
        addChild(leftBar)

        iconLabel = SKLabelNode(text: severity.icon)
        iconLabel.fontSize = 22
        iconLabel.position = CGPoint(x: -140, y: 15)
        addChild(iconLabel)

        projectLabel = SKLabelNode(text: truncate(report.project.name, length: 28))
        projectLabel.fontName = "Helvetica-Bold"
        projectLabel.fontSize = 13
        projectLabel.fontColor = .white
        projectLabel.horizontalAlignmentMode = .left
        projectLabel.position = CGPoint(x: -110, y: 25)
        addChild(projectLabel)

        branchLabel = SKLabelNode(text: " \(report.status.currentBranch)")
        branchLabel.fontName = "Menlo-Regular"
        branchLabel.fontSize = 10
        branchLabel.fontColor = NSColor(red: 0.4, green: 0.7, blue: 0.9, alpha: 1.0)
        branchLabel.horizontalAlignmentMode = .left
        branchLabel.position = CGPoint(x: -110, y: 8)
        addChild(branchLabel)

        let (statusText1, statusText2) = formatStatus(report)
        statusLine1 = SKLabelNode(text: statusText1)
        statusLine1.fontName = "Helvetica"
        statusLine1.fontSize = 11
        statusLine1.fontColor = hasIssues ?
            NSColor(red: 1.0, green: 0.6, blue: 0.6, alpha: 1.0) :
            NSColor(red: 0.6, green: 0.9, blue: 0.6, alpha: 1.0)
        statusLine1.horizontalAlignmentMode = .left
        statusLine1.position = CGPoint(x: -110, y: -12)
        addChild(statusLine1)

        statusLine2 = SKLabelNode(text: statusText2)
        statusLine2.fontName = "Helvetica"
        statusLine2.fontSize = 10
        statusLine2.fontColor = NSColor(white: 0.6, alpha: 1.0)
        statusLine2.horizontalAlignmentMode = .left
        statusLine2.position = CGPoint(x: -110, y: -28)
        addChild(statusLine2)

        if let agentName = report.agentName {
            agentBadge = SKLabelNode(text: "🤖 \(agentName)")
            agentBadge.fontName = "Helvetica"
            agentBadge.fontSize = 9
            agentBadge.fontColor = NSColor(white: 0.5, alpha: 1.0)
            agentBadge.position = CGPoint(x: 110, y: 35)
            addChild(agentBadge)
        }

        timeLabel = SKLabelNode(text: timeAgo(report.completedAt))
        timeLabel.fontName = "Helvetica"
        timeLabel.fontSize = 9
        timeLabel.fontColor = NSColor(white: 0.4, alpha: 1.0)
        timeLabel.position = CGPoint(x: 120, y: -38)
        addChild(timeLabel)

        if report.status.pendingPullRequests > 0 {
            let prBadge = SKLabelNode(text: "🔀 \(report.status.pendingPullRequests) PRs")
            prBadge.fontName = "Helvetica"
            prBadge.fontSize = 10
            prBadge.fontColor = NSColor(red: 0.9, green: 0.7, blue: 0.4, alpha: 1.0)
            prBadge.position = CGPoint(x: 80, y: -38)
            addChild(prBadge)
        }

        let chevron = SKLabelNode(text: "›")
        chevron.fontName = "Helvetica-Bold"
        chevron.fontSize = 20
        chevron.fontColor = NSColor(white: 0.3, alpha: 1.0)
        chevron.position = CGPoint(x: 155, y: 0)
        addChild(chevron)

        isUserInteractionEnabled = true
    }

    private func truncate(_ string: String, length: Int) -> String {
        if string.count <= length {
            return string
        }
        return String(string.prefix(length - 2)) + "…"
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else {
            return "\(Int(seconds / 3600))h"
        }
    }

    private func formatStatus(_ report: ProjectReport) -> (String, String) {
        let status = report.status
        let staged = status.stagedFiles.count
        let modified = status.modifiedFiles.count
        let untracked = status.untrackedFiles.count

        if !status.hasUncommittedChanges {
            if let lastCommit = status.lastCommitMessage {
                let commitPreview = truncate(lastCommit, length: 35)
                return ("✅ Clean", commitPreview)
            }
            return ("✅ Clean", "Working directory clean")
        }

        var line1 = ""
        var line2 = ""

        if staged > 0 {
            line1 += "🔴 +\(staged) "
        }
        if modified > 0 {
            line1 += "🟡 ∼\(modified) "
        }
        if untracked > 0 {
            line1 += "❓ \(untracked)"
        }

        if status.pendingPullRequests > 0 {
            line2 = "🔀 \(status.pendingPullRequests) PRs pending"
        } else if let commit = status.lastCommitMessage {
            line2 = "📝 \(truncate(commit, length: 40))"
        }

        return (line1.trimmingCharacters(in: .whitespaces), line2)
    }

    override func mouseDown(with event: NSEvent) {
        let pulse = SKAction.sequence([
            SKAction.scale(to: 0.97, duration: 0.08),
            SKAction.scale(to: 1.0, duration: 0.12)
        ])
        run(pulse)

        let flash = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.7, duration: 0.05),
            SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        ])
        cardBackground.run(flash)

        onTap?()
    }
}

extension ProjectReport {
    var severity: ReportSeverity {
        let totalChanges = status.modifiedFiles.count + status.untrackedFiles.count + status.stagedFiles.count
        let hasStaged = status.stagedFiles.count > 0
        let hasPRs = status.pendingPullRequests > 0

        if hasStaged && totalChanges > 5 {
            return .critical
        } else if hasPRs {
            return .warning
        } else if totalChanges > 10 {
            return .warning
        } else if totalChanges > 0 {
            return .info
        }
        return .success
    }
}

enum ReportSeverity {
    case success
    case info
    case warning
    case critical

    var color: NSColor {
        switch self {
        case .success:
            return NSColor(red: 0.31, green: 0.8, blue: 0.64, alpha: 1.0)
        case .info:
            return NSColor(red: 0.4, green: 0.7, blue: 0.9, alpha: 1.0)
        case .warning:
            return NSColor(red: 1.0, green: 0.65, blue: 0.3, alpha: 1.0)
        case .critical:
            return NSColor(red: 1.0, green: 0.35, blue: 0.35, alpha: 1.0)
        }
    }

    var icon: String {
        switch self {
        case .success:
            return "✅"
        case .info:
            return "📝"
        case .warning:
            return "⚠️"
        case .critical:
            return "🚨"
        }
    }
}
