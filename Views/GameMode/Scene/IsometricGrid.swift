import Foundation
import CoreGraphics

struct IsometricGrid {
    let tileWidth: CGFloat
    let tileHeight: CGFloat
    
    init(tileWidth: CGFloat = 80, tileHeight: CGFloat = 40) {
        self.tileWidth = tileWidth
        self.tileHeight = tileHeight
    }
    
    func logicalToScreen(x: Int, y: Int) -> CGPoint {
        let screenX = CGFloat(x - y) * tileWidth / 2
        let screenY = CGFloat(x + y) * tileHeight / 2
        return CGPoint(x: screenX, y: screenY)
    }
    
    func screenToLogical(point: CGPoint) -> (x: Int, y: Int) {
        let x = Int((point.x / (tileWidth / 2) + point.y / (tileHeight / 2)) / 2)
        let y = Int((point.y / (tileHeight / 2) - point.x / (tileWidth / 2)) / 2)
        return (x, y)
    }
    
    func zPosition(for logicalY: Int) -> CGFloat {
        return CGFloat(logicalY)
    }
    
    func zPosition(for screenY: CGFloat) -> CGFloat {
        return screenY
    }
}
