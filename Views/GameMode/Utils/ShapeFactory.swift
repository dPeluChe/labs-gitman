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
