import SwiftUI
import SpriteKit

@MainActor
class GameSceneStore: ObservableObject {
    let scene: OfficeScene
    
    init(coordinator: GameCoordinator) {
        self.scene = OfficeScene(coordinator: coordinator)
        self.scene.scaleMode = .resizeFill
    }
}
