import SpriteKit
import GameplayKit

// MARK: - Base State
class AgentBaseState: GKState {
    unowned let agentNode: AgentNode
    
    init(agentNode: AgentNode) {
        self.agentNode = agentNode
        super.init()
    }
}

// MARK: - Idle State
class AgentIdleState: AgentBaseState {
    override func didEnter(from previousState: GKState?) {
        agentNode.playIdleAnimation()
    }
    
    override func willExit(to nextState: GKState) {
        agentNode.stopIdleAnimation()
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass is AgentMovingState.Type || stateClass is AgentAlertState.Type
    }
}

// MARK: - Moving State
class AgentMovingState: AgentBaseState {
    let targetPosition: CGPoint
    let completion: () -> Void
    
    init(agentNode: AgentNode, target: CGPoint, completion: @escaping () -> Void = {}) {
        self.targetPosition = target
        self.completion = completion
        super.init(agentNode: agentNode)
    }
    
    override func didEnter(from previousState: GKState?) {
        Task {
            await agentNode.performMove(to: targetPosition)
            completion()
        }
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass is AgentWorkingState.Type || 
               stateClass is AgentIdleState.Type ||
               stateClass is AgentPresentingState.Type ||
               stateClass is AgentMovingState.Type // Can change destination
    }
}

// MARK: - Working State
class AgentWorkingState: AgentBaseState {
    override func didEnter(from previousState: GKState?) {
        agentNode.startWorkingAnimation()
    }
    
    override func willExit(to nextState: GKState) {
        agentNode.stopWorkingAnimation()
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass is AgentMovingState.Type
    }
}

// MARK: - Presenting State (Report)
class AgentPresentingState: AgentBaseState {
    let report: ProjectReport
    
    init(agentNode: AgentNode, report: ProjectReport) {
        self.report = report
        super.init(agentNode: agentNode)
    }
    
    override func didEnter(from previousState: GKState?) {
        // Trigger specific animation for presenting
        if report.status.hasUncommittedChanges {
             agentNode.stateMachine.enter(AgentAlertState.self)
        } else {
             agentNode.celebrate()
             // Auto transition back to idle after celebration
             Task {
                 try? await Task.sleep(nanoseconds: 2_000_000_000)
                 await MainActor.run {
                     agentNode.stateMachine.enter(AgentIdleState.self)
                 }
             }
        }
    }
}

// MARK: - Alert State
class AgentAlertState: AgentBaseState {
    override func didEnter(from previousState: GKState?) {
        agentNode.alert()
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                agentNode.stateMachine.enter(AgentIdleState.self)
            }
        }
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass is AgentIdleState.Type
    }
}
