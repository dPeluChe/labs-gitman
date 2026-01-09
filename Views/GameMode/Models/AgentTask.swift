import Foundation

struct AgentTask: Identifiable, Equatable {
    let id: UUID
    let project: Project
    let createdAt: Date
    
    init(project: Project) {
        self.id = UUID()
        self.project = project
        self.createdAt = Date()
    }
    
    static func == (lhs: AgentTask, rhs: AgentTask) -> Bool {
        lhs.id == rhs.id
    }
}
