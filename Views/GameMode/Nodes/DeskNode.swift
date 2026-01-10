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
        // Shadow
        let shadow = ShapeFactory.createShadow(width: 100, height: 40)
        shadow.position = CGPoint(x: 0, y: -20)
        addChild(shadow)

        deskShape = ShapeFactory.createPrism(
            width: 120,
            length: 60,
            height: 40,
            color: NSColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1.0)
        ) as? SKShapeNode // Might be SKNode container
        
        let prism = ShapeFactory.createPrism(
             width: 120,
             length: 60,
             height: 40,
             color: NSColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1.0)
         )
        addChild(prism)
        
        nameLabel = SKLabelNode(text: "Manager Desk")
        nameLabel.fontName = "Helvetica-Bold"
        nameLabel.fontSize = 10
        nameLabel.fontColor = .white
        nameLabel.position = CGPoint(x: 0, y: 50) // Above desk
        nameLabel.zPosition = 1
        addChild(nameLabel)
        
        let icon = SKLabelNode(text: "👤")
        icon.fontSize = 24
        icon.position = CGPoint(x: 0, y: 10) // Front face
        icon.zPosition = 1
        prism.addChild(icon)
    }
}
