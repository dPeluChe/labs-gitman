import Foundation

struct ProjectReport: Identifiable, Equatable {
    let id: UUID
    let project: Project
    let status: GitStatus
    let completedAt: Date
    
    init(project: Project, status: GitStatus) {
        self.id = UUID()
        self.project = project
        self.status = status
        self.completedAt = Date()
    }
    
    var hasIssues: Bool {
        status.hasUncommittedChanges
    }
    
    var needsAttention: Bool {
        status.hasUncommittedChanges || status.pendingPullRequests > 0
    }
    
    static func == (lhs: ProjectReport, rhs: ProjectReport) -> Bool {
        lhs.id == rhs.id
    }
}
