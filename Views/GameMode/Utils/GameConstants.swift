import Foundation
import CoreGraphics

struct GameConstants {
    // Scene
    static let sceneWidth: CGFloat = 1200
    static let sceneHeight: CGFloat = 800
    static let floorGridSize = 8
    
    // Portals
    static let maxPortals = 6
    static let portalWidth: CGFloat = 80
    static let portalHeight: CGFloat = 100
    static let portalSpacingX: CGFloat = 120
    static let portalSpacingY: CGFloat = 140
    static let portalStartX: CGFloat = 0.2
    static let portalStartY: CGFloat = 0.65
    
    // Agents
    static let agentBodyWidth: CGFloat = 30
    static let agentBodyHeight: CGFloat = 40
    static let agentHeadRadius: CGFloat = 12
    static let agentCount = 2
    
    // Desk
    static let deskWidth: CGFloat = 120
    static let deskHeight: CGFloat = 60
    static let deskYPosition: CGFloat = 0.3
    
    // Report Board
    static let reportBoardWidth: CGFloat = 350
    static let reportBoardHeight: CGFloat = 150
    static let reportBoardYPosition: CGFloat = 0.75
    
    // Animations
    static let moveDuration: TimeInterval = 1.0
    static let portalEnterDuration: TimeInterval = 0.3
    static let workingStateDuration: TimeInterval = 0.2
    static let reportPresentDuration: TimeInterval = 0.5
    static let celebrationDuration: TimeInterval = 1.0
    
    // Isometric Grid
    static let tileWidth: CGFloat = 80
    static let tileHeight: CGFloat = 40
    
    // Colors
    struct Colors {
        static let officeFloor = (r: 0.09, g: 0.13, b: 0.24, a: 1.0)
        static let officeFloorStroke = (r: 0.12, g: 0.16, b: 0.27, a: 1.0)
        static let background = (r: 0.1, g: 0.1, b: 0.18, a: 1.0)
        
        static let agent1 = (r: 0.91, g: 0.27, b: 0.38, a: 1.0)
        static let agent2 = (r: 0.06, g: 0.21, b: 0.38, a: 1.0)
        
        static let portalClean = (r: 0.31, g: 0.8, b: 0.64, a: 1.0)
        static let portalChanges = (r: 1.0, g: 0.79, b: 0.24, a: 1.0)
        static let portalIssues = (r: 1.0, g: 0.42, b: 0.42, a: 1.0)
        
        static let desk = (r: 0.4, g: 0.3, b: 0.2, a: 1.0)
    }
}
