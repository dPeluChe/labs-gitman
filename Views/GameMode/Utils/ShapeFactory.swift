import SpriteKit

enum ShapeFactory {
    static func createRoundedRect(size: CGSize, cornerRadius: CGFloat, fillColor: NSColor, strokeColor: NSColor? = nil, lineWidth: CGFloat = 2.0) -> SKShapeNode {
        let rect = CGRect(origin: CGPoint(x: -size.width/2, y: -size.height/2), size: size)
        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        
        let node = SKShapeNode(path: path.cgPath)
        node.fillColor = fillColor
        node.strokeColor = strokeColor ?? .clear
        node.lineWidth = lineWidth
        
        return node
    }
    
    static func createCircle(radius: CGFloat, fillColor: NSColor, strokeColor: NSColor? = nil, lineWidth: CGFloat = 2.0) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: radius)
        node.fillColor = fillColor
        node.strokeColor = strokeColor ?? .clear
        node.lineWidth = lineWidth
        
        return node
    }
    
    static func createTriangle(size: CGFloat, fillColor: NSColor, strokeColor: NSColor? = nil, lineWidth: CGFloat = 2.0) -> SKShapeNode {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: 0, y: size/2))
        path.line(to: CGPoint(x: -size/2, y: -size/2))
        path.line(to: CGPoint(x: size/2, y: -size/2))
        path.close()
        
        let node = SKShapeNode(path: path.cgPath)
        node.fillColor = fillColor
        node.strokeColor = strokeColor ?? .clear
        node.lineWidth = lineWidth
        
        return node
    }
    
    static func createIsometricTile(width: CGFloat, height: CGFloat, fillColor: NSColor, strokeColor: NSColor? = nil, lineWidth: CGFloat = 1.0) -> SKShapeNode {
        let path = NSBezierPath()
        let halfWidth = width / 2
        let halfHeight = height / 2
        
        path.move(to: CGPoint(x: 0, y: halfHeight))
        path.line(to: CGPoint(x: halfWidth, y: 0))
        path.line(to: CGPoint(x: 0, y: -halfHeight))
        path.line(to: CGPoint(x: -halfWidth, y: 0))
        path.close()
        
        let node = SKShapeNode(path: path.cgPath)
        node.fillColor = fillColor
        node.strokeColor = strokeColor ?? NSColor(white: 0.3, alpha: 0.5)
        node.lineWidth = lineWidth
        
        return node
    }
    
    static func createProgressBar(width: CGFloat, height: CGFloat, progress: Float, backgroundColor: NSColor, fillColor: NSColor) -> SKNode {
        let container = SKNode()
        
        let background = createRoundedRect(size: CGSize(width: width, height: height), cornerRadius: height/2, fillColor: backgroundColor)
        container.addChild(background)
        
        let fillWidth = CGFloat(progress) * width
        if fillWidth > 0 {
            let fill = createRoundedRect(size: CGSize(width: fillWidth, height: height), cornerRadius: height/2, fillColor: fillColor)
            fill.position = CGPoint(x: -(width - fillWidth)/2, y: 0)
            container.addChild(fill)
        }
        
        return container
    }
    
    /// Creates a 2.5D Isometric Prism (Block)
    /// - Parameters:
    ///   - width: Horizontal width (isometric X)
    ///   - length: Horizontal depth (isometric Y)
    ///   - height: Vertical height (Z in 3D, Y in screen)
    ///   - color: Base color
    static func createPrism(width: CGFloat, length: CGFloat, height: CGFloat, color: NSColor) -> SKNode {
        let container = SKNode()
        
        // Colors for shading
        let topColor = color.blended(withFraction: 0.1, of: .white) ?? color
        let rightColor = color.blended(withFraction: 0.3, of: .black) ?? color
        let leftColor = color.blended(withFraction: 0.5, of: .black) ?? color
        
        // Dimensions (Screen Space Projection)
        // Isometric angle ~30 deg means width/2 step X corresponds to length/4 step Y?
        // Let's match the IsometricGrid logic roughly:
        // x -> (x - y) * tileW/2
        // y -> (x + y) * tileH/2
        
        let w = width
        let l = length
        let h = height
        
        // Top Face (Diamond)
        // Vertices relative to top-center of the block
        let topPath = NSBezierPath()
        topPath.move(to: CGPoint(x: 0, y: h)) // Top Center
        topPath.line(to: CGPoint(x: w/2, y: h - l/4)) // Right
        topPath.line(to: CGPoint(x: 0, y: h - l/2)) // Bottom
        topPath.line(to: CGPoint(x: -w/2, y: h - l/4)) // Left
        topPath.close()
        
        let topNode = SKShapeNode(path: topPath.cgPath)
        topNode.fillColor = topColor
        topNode.strokeColor = topColor.blended(withFraction: 0.2, of: .black) ?? .black
        topNode.lineWidth = 1
        container.addChild(topNode)
        
        // Right Face
        let rightPath = NSBezierPath()
        rightPath.move(to: CGPoint(x: 0, y: h - l/2)) // Top Left (of face)
        rightPath.line(to: CGPoint(x: w/2, y: h - l/4)) // Top Right
        rightPath.line(to: CGPoint(x: w/2, y: -l/4)) // Bottom Right
        rightPath.line(to: CGPoint(x: 0, y: -l/2)) // Bottom Left
        rightPath.close()
        
        let rightNode = SKShapeNode(path: rightPath.cgPath)
        rightNode.fillColor = rightColor
        rightNode.strokeColor = rightColor.blended(withFraction: 0.2, of: .black) ?? .black
        rightNode.lineWidth = 1
        container.addChild(rightNode)
        
        // Left Face
        let leftPath = NSBezierPath()
        leftPath.move(to: CGPoint(x: 0, y: h - l/2)) // Top Right (of face)
        leftPath.line(to: CGPoint(x: -w/2, y: h - l/4)) // Top Left
        leftPath.line(to: CGPoint(x: -w/2, y: -l/4)) // Bottom Left
        leftPath.line(to: CGPoint(x: 0, y: -l/2)) // Bottom Right
        leftPath.close()
        
        let leftNode = SKShapeNode(path: leftPath.cgPath)
        leftNode.fillColor = leftColor
        leftNode.strokeColor = leftColor.blended(withFraction: 0.2, of: .black) ?? .black
        leftNode.lineWidth = 1
        container.addChild(leftNode)
        
        return container
    }
    
    static func createShadow(width: CGFloat, height: CGFloat) -> SKShapeNode {
        let node = SKShapeNode(ellipseOf: CGSize(width: width, height: height))
        node.fillColor = NSColor.black.withAlphaComponent(0.3)
        node.strokeColor = .clear
        return node
    }
}

extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        
        for i in 0 ..< self.elementCount {
            let type = self.element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addCurve(to: points[1], control1: points[0], control2: points[0])
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }
        
        return path
    }
}
