import SpriteKit

class DebugOverlayNode: SKNode {
    private var backgroundNode: SKShapeNode!
    private var fpsLabel: SKLabelNode!
    private var queueLabel: SKLabelNode!
    private var agentLabels: [SKLabelNode] = []
    private var gridNode: SKNode?
    
    var isVisible: Bool = false {
        didSet {
            self.isHidden = !isVisible
        }
    }
    
    override init() {
        super.init()
        setupUI()
        self.isHidden = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundNode = SKShapeNode(rectOf: CGSize(width: 300, height: 200), cornerRadius: 8)
        backgroundNode.fillColor = NSColor(white: 0.1, alpha: 0.85)
        backgroundNode.strokeColor = NSColor(white: 0.3, alpha: 1.0)
        backgroundNode.lineWidth = 2
        backgroundNode.position = CGPoint(x: 0, y: 0)
        addChild(backgroundNode)
        
        fpsLabel = createLabel(text: "FPS: --", yOffset: 70)
        queueLabel = createLabel(text: "Queue: 0", yOffset: 45)
        
        for i in 0..<2 {
            let label = createLabel(text: "Agent \(i+1): idle", yOffset: CGFloat(20 - i * 25))
            agentLabels.append(label)
        }
    }
    
    private func createLabel(text: String, yOffset: CGFloat) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = "Menlo-Regular"
        label.fontSize = 12
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.position = CGPoint(x: -140, y: yOffset)
        addChild(label)
        return label
    }
    
    func updateFPS(_ fps: Int) {
        fpsLabel.text = "FPS: \(fps)"
    }
    
    func updateQueueLength(_ length: Int) {
        queueLabel.text = "Queue: \(length)"
    }
    
    func updateAgentState(index: Int, state: AgentState) {
        guard index < agentLabels.count else { return }
        agentLabels[index].text = "Agent \(index + 1): \(state.description)"
    }
    
    func showGrid(in scene: SKScene, grid: IsometricGrid, rows: Int, cols: Int) {
        gridNode?.removeFromParent()
        
        let gridContainer = SKNode()
        gridContainer.zPosition = -10
        
        for row in 0..<rows {
            for col in 0..<cols {
                let screenPos = grid.logicalToScreen(x: col, y: row)
                let tile = ShapeFactory.createIsometricTile(
                    width: grid.tileWidth,
                    height: grid.tileHeight,
                    fillColor: NSColor(white: 0.2, alpha: 0.3),
                    strokeColor: NSColor(white: 0.4, alpha: 0.5),
                    lineWidth: 1
                )
                tile.position = screenPos
                gridContainer.addChild(tile)
            }
        }
        
        scene.addChild(gridContainer)
        gridNode = gridContainer
    }
    
    func hideGrid() {
        gridNode?.removeFromParent()
        gridNode = nil
    }
}
