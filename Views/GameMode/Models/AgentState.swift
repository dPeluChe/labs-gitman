import Foundation

enum AgentState: Equatable {
    case idle
    case walkingToPortal(projectId: UUID)
    case enteringPortal
    case working(progress: Float)
    case exitingPortal
    case returningWithReport(GitStatus)
    case presentingReport
    case celebrating
    case alerting
    
    var description: String {
        switch self {
        case .idle:
            return "Idle"
        case .walkingToPortal(let id):
            return "Walking to \(id.uuidString.prefix(8))"
        case .enteringPortal:
            return "Entering portal"
        case .working(let progress):
            return "Working (\(Int(progress * 100))%)"
        case .exitingPortal:
            return "Exiting portal"
        case .returningWithReport:
            return "Returning with report"
        case .presentingReport:
            return "Presenting report"
        case .celebrating:
            return "Celebrating"
        case .alerting:
            return "Alerting"
        }
    }
    
    var isAvailable: Bool {
        if case .idle = self {
            return true
        }
        return false
    }
}
