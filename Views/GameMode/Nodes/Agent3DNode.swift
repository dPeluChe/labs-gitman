import SpriteKit
import SceneKit
import ModelIO
import GameplayKit

class Agent3DNode: SKNode, AgentNodeProtocol {
    var agentId: UUID
    var stateMachine: GKStateMachine!

    var isReserved: Bool = false
    var isAvailable: Bool {
        return !isReserved && stateMachine.currentState is AgentIdleState
    }

    private var modelNode: SCNNode?
    private var model3DNode: SK3DNode?
    private var containerNode: SKNode!
    private var shadowNode: SKShapeNode!
    private var nameLabel: SKLabelNode!
    private var selectionRing: SKShapeNode!
    private var progressBar: SKNode?

    private let agentColor: NSColor
    private let modelName: String?

    private static var sceneCache: [String: SCNScene] = [:]

    init(id: UUID, name: String, color: NSColor, position: CGPoint, modelName: String? = nil) {
        self.agentId = id
        self.agentColor = color
        self.modelName = modelName
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
        ])
        stateMachine.enter(AgentIdleState.self)
    }

    private func setupAgent(name: String) {
        selectionRing = ShapeFactory.createCircle(
            radius: 25,
            fillColor: .clear,
            strokeColor: .green,
            lineWidth: 2
        )
        selectionRing.position = CGPoint(x: 0, y: 0)
        selectionRing.zPosition = 100
        selectionRing.isHidden = true
        addChild(selectionRing)

        shadowNode = ShapeFactory.createShadow(width: 30, height: 15)
        shadowNode.position = CGPoint(x: 0, y: -2)
        shadowNode.zPosition = -1
        addChild(shadowNode)

        if let modelName = modelName {
            setup3DModel(named: modelName)
        } else {
            setupFallbackGeometry()
        }

        nameLabel = SKLabelNode(text: name)
        nameLabel.fontName = "Helvetica-Bold"
        nameLabel.fontSize = 10
        nameLabel.fontColor = .white
        nameLabel.position = CGPoint(x: 0, y: 70)
        nameLabel.zPosition = 100
        addChild(nameLabel)
    }

    private func setup3DModel(named modelName: String) {
        var searchPaths: [URL] = []

        if let mainResourcesURL = Bundle.main.resourceURL {
            searchPaths.append(mainResourcesURL)
            let inBundleURL = mainResourcesURL.appendingPathComponent("GitMonitor_GitMonitor.bundle/Contents/Resources")
            searchPaths.append(inBundleURL)
        }

        if let bundlePath = Bundle.main.path(forResource: "GitMonitor_GitMonitor", ofType: "bundle"),
           let bundle = Bundle(path: bundlePath),
           let resourcesURL = bundle.resourceURL {
            searchPaths.append(resourcesURL)
        }

        var foundURL: URL?
        for searchURL in searchPaths {
            // Priority order: DAE (best compatibility) > USDZ (Apple native) > GLB (limited support)
            let daeURL = searchURL.appendingPathComponent("\(modelName).dae")
            let usdzURL = searchURL.appendingPathComponent("\(modelName).usdz")
            let glbURL = searchURL.appendingPathComponent("\(modelName).glb")

            if FileManager.default.fileExists(atPath: daeURL.path) {
                foundURL = daeURL
                break
            } else if FileManager.default.fileExists(atPath: usdzURL.path) {
                foundURL = usdzURL
                break
            } else if FileManager.default.fileExists(atPath: glbURL.path) {
                foundURL = glbURL
                break
            }
        }

        guard let modelURL = foundURL else {
            print("⚠️ Model not found: '\(modelName)'")
            for searchURL in searchPaths {
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: searchURL.path) {
                    let glbFiles = contents.filter { $0.hasSuffix(".glb") || $0.hasSuffix(".usdz") }
                    if !glbFiles.isEmpty {
                        print("   ✓ Found in: \(searchURL.path)")
                        print("   Files: \(glbFiles.joined(separator: ", "))")
                    }
                }
            }
            setupFallbackGeometry()
            return
        }

        print("✅ Loading model: \(modelName) from \(modelURL.lastPathComponent)")

        containerNode = SKNode()
        containerNode.position = CGPoint(x: 0, y: 20)
        containerNode.zPosition = 10

        if let cachedScene = Self.sceneCache[modelName] {
            // Use cached scene
            if let rootNode = cachedScene.rootNode.childNodes.first {
                modelNode = rootNode
                setup3DNodeFromModel(rootNode, in: containerNode)
            }
        } else {
            do {
                // SceneKit has best support for: DAE, USDZ, SCN
                // Limited support for: GLB, OBJ
                // Recommended: Convert GLB to DAE for best compatibility
                let scene = try SCNScene(url: modelURL, options: [
                    SCNSceneSource.LoadingOption.checkConsistency: false,
                    SCNSceneSource.LoadingOption.flattenScene: false
                ])

                Self.sceneCache[modelName] = scene

                if let rootNode = scene.rootNode.childNodes.first {
                    modelNode = rootNode
                    setup3DNodeFromModel(rootNode, in: containerNode)
                    print("✅ Model '\(modelName)' loaded successfully (\(modelURL.pathExtension) format)")
                } else {
                    print("⚠️ Model '\(modelName)' has no child nodes")
                    setupFallbackGeometry()
                }
            } catch {
                print("⚠️ Failed to load model '\(modelName).glb: \(error)")
                if let nsError = error as NSError? {
                    print("   Error Code: \(nsError.code) - Domain: \(nsError.domain)")
                    print("   SceneKit has limited GLB support on macOS")
                    print("   💡 Solution: Convert GLB files to DAE (COLLADA) format")
                    print("   Run: python3 convert_glb_to_dae.py")
                }
                setupFallbackGeometry()
                return
            }
        }

        addChild(containerNode)
    }

    private func setup3DNodeFromModel(_ scnNode: SCNNode, in parent: SKNode) {
        // Calculate scale to fit target size
        let boundingBox = scnNode.boundingBox
        let sizeX = CGFloat(boundingBox.max.x - boundingBox.min.x)
        let sizeY = CGFloat(boundingBox.max.y - boundingBox.min.y)
        let sizeZ = CGFloat(boundingBox.max.z - boundingBox.min.z)
        let maxDimension = max(sizeX, max(sizeY, sizeZ))
        let targetSize: CGFloat = 40
        let scale = targetSize / max(maxDimension, 0.001)

        // Create SK3DNode (SpriteKit's native 3D node)
        let sk3d = SK3DNode(viewportSize: CGSize(width: 80, height: 80))
        sk3d.scnScene = SCNScene()

        // Clone the node to avoid modifying cached version
        let clonedNode = scnNode.clone()
        clonedNode.scale = SCNVector3(Float(scale), Float(scale), Float(scale))

        // Center the model
        let centerX = (CGFloat(boundingBox.min.x) + CGFloat(boundingBox.max.x)) / 2 * scale
        let centerY = (CGFloat(boundingBox.min.y) + CGFloat(boundingBox.max.y)) / 2 * scale
        let centerZ = (CGFloat(boundingBox.min.z) + CGFloat(boundingBox.max.z)) / 2 * scale
        clonedNode.position = SCNVector3(-Float(centerX), -Float(centerY), -Float(centerZ))

        sk3d.scnScene?.rootNode.addChildNode(clonedNode)

        // Add lighting
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = NSColor(white: 0.7, alpha: 1.0)
        sk3d.scnScene?.rootNode.addChildNode(ambientLight)

        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.color = NSColor(white: 0.9, alpha: 1.0)
        directionalLight.position = SCNVector3(x: 2, y: 5, z: 3)
        directionalLight.look(at: SCNVector3(x: 0, y: 0, z: 0))
        sk3d.scnScene?.rootNode.addChildNode(directionalLight)

        // Position and add to parent
        sk3d.position = CGPoint(x: 0, y: 0)
        parent.addChild(sk3d)

        model3DNode = sk3d
    }

    private func setupFallbackGeometry() {
        let bodyNode = ShapeFactory.createRoundedRect(
            size: CGSize(width: 30, height: 40),
            cornerRadius: 8,
            fillColor: agentColor,
            strokeColor: agentColor.blended(withFraction: 0.3, of: .black) ?? agentColor,
            lineWidth: 2
        )
        bodyNode.position = CGPoint(x: 0, y: 20)
        bodyNode.name = "body"
        addChild(bodyNode)

        let headNode = ShapeFactory.createCircle(
            radius: 12,
            fillColor: agentColor.blended(withFraction: 0.2, of: .white) ?? agentColor,
            strokeColor: agentColor.blended(withFraction: 0.3, of: .black) ?? agentColor,
            lineWidth: 2
        )
        headNode.position = CGPoint(x: 0, y: 50)
        headNode.name = "head"
        addChild(headNode)
    }

    func setSelected(_ selected: Bool) {
        selectionRing.isHidden = !selected
        if selected {
            selectionRing.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.5),
                SKAction.scale(to: 1.0, duration: 0.5)
            ])))
        } else {
            selectionRing.removeAllActions()
            selectionRing.setScale(1.0)
        }
    }

    func playIdleAnimation() {
        if containerNode != nil {
            let bob = SKAction.sequence([
                SKAction.moveBy(x: 0, y: 3, duration: 0.6),
                SKAction.moveBy(x: 0, y: -3, duration: 0.6)
            ])
            containerNode.run(SKAction.repeatForever(bob), withKey: "idle")
        } else {
            if let body = childNode(withName: "//body") {
                let bob = SKAction.sequence([
                    SKAction.moveBy(x: 0, y: 3, duration: 0.6),
                    SKAction.moveBy(x: 0, y: -3, duration: 0.6)
                ])
                body.run(SKAction.repeatForever(bob), withKey: "idle")
            }
            if let head = childNode(withName: "//head") {
                let headBob = SKAction.sequence([
                    SKAction.moveBy(x: 0, y: 2, duration: 0.6),
                    SKAction.moveBy(x: 0, y: -2, duration: 0.6)
                ])
                head.run(SKAction.repeatForever(headBob), withKey: "headIdle")
            }
        }
    }

    func stopIdleAnimation() {
        containerNode?.removeAction(forKey: "idle")
        if let body = childNode(withName: "//body") {
            body.removeAction(forKey: "idle")
        }
        if let head = childNode(withName: "//head") {
            head.removeAction(forKey: "headIdle")
        }
    }

    func performMove(to targetPos: CGPoint) async {
        let distance = hypot(targetPos.x - self.position.x, targetPos.y - self.position.y)
        let speed: CGFloat = 200.0
        let duration = TimeInterval(distance / speed)

        let moveAction = SKAction.move(to: targetPos, duration: duration)
        moveAction.timingMode = .easeInEaseOut

        if containerNode != nil {
            let walkBob = SKAction.sequence([
                SKAction.moveBy(x: 0, y: 5, duration: 0.15),
                SKAction.moveBy(x: 0, y: -5, duration: 0.15)
            ])
            containerNode.run(SKAction.repeatForever(walkBob), withKey: "walk")
        }

        await self.runAsync(moveAction)

        containerNode?.removeAction(forKey: "walk")
    }

    func startWorkingAnimation() {
        let bar = ShapeFactory.createProgressBar(
            width: 40,
            height: 6,
            progress: 0.0,
            backgroundColor: NSColor(white: 0.3, alpha: 0.8),
            fillColor: NSColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1.0)
        )
        bar.position = CGPoint(x: 0, y: 50)
        bar.zPosition = 100
        addChild(bar)
        progressBar = bar
    }

    func stopWorkingAnimation() {
        progressBar?.removeFromParent()
        progressBar = nil
    }

    func celebrate() {
        let jump = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 20, duration: 0.2),
            SKAction.moveBy(x: 0, y: -20, duration: 0.2)
        ])
        run(SKAction.repeat(jump, count: 2))

        let sparkle = SKLabelNode(text: "✨")
        sparkle.fontSize = 20
        sparkle.position = CGPoint(x: 0, y: 80)
        sparkle.zPosition = 100
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
        warning.position = CGPoint(x: 0, y: 80)
        warning.zPosition = 100
        addChild(warning)

        let fadeOut = SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ])
        warning.run(fadeOut)
    }

    func commandMove(to target: CGPoint) async {
        await withCheckedContinuation { continuation in
            let movingState = AgentMovingState(agentNode: self, target: target) {
                continuation.resume()
            }
            self.stateMachine = GKStateMachine(states: [
                movingState,
                AgentIdleState(agentNode: self),
                AgentWorkingState(agentNode: self),
                AgentAlertState(agentNode: self)
            ])
            self.stateMachine.enter(AgentMovingState.self)
            self.isReserved = false
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
