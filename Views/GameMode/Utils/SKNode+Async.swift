import SpriteKit

extension SKNode {
    func runAsync(_ action: SKAction) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.run(action) {
                continuation.resume()
            }
        }
    }
}
