import SpriteKit

class DeskNode: SKNode {
    private var deskShape: SKShapeNode!
    private var nameLabel: SKLabelNode!
    
    init(position: CGPoint, grid: IsometricGrid) {
        super.init()
        self.position = position
        setupDesk()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupDesk() {
        deskShape = ShapeFactory.createIsometricTile(
            width: 120,
            height: 60,
            fillColor: NSColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1.0),
            strokeColor: NSColor(red: 0.3, green: 0.2, blue: 0.1, alpha: 1.0),
            lineWidth: 2
        )
        addChild(deskShape)
        
        nameLabel = SKLabelNode(text: "Manager Desk")
        nameLabel.fontName = "Helvetica-Bold"
        nameLabel.fontSize = 10
        nameLabel.fontColor = .white
        nameLabel.position = CGPoint(x: 0, y: -40)
        addChild(nameLabel)
        
        let icon = SKLabelNode(text: "👤")
        icon.fontSize = 24
        icon.position = CGPoint(x: 0, y: -5)
        addChild(icon)
    }
}
