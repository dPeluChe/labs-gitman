import SwiftUI

struct DashboardView: View {
    let projects: [Project]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Summary Cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    summaryCard(title: "Total Projects", value: "\(projects.count)", icon: "folder.fill", color: .blue)
                    summaryCard(title: "Git Repos", value: "\(gitReposCount)", icon: "git.branch", color: .purple)
                    summaryCard(title: "Changes", value: "\(projectsWithChanges)", icon: "pencil", color: .orange)
                    summaryCard(title: "Pending PRs", value: "\(totalPRs)", icon: "arrow.triangle.pull", color: .green)
                }
                
                // Recent Activity / Timeline (Simulated for now based on lastScanned)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recent Activity")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    ForEach(recentProjects) { project in
                        HStack(alignment: .top, spacing: 16) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 10, height: 10)
                                .offset(y: 6)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.name)
                                    .font(.headline)
                                Text("Scanned " + relativeTime(project.lastScanned))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                if let status = project.gitStatus {
                                    Text(status.currentBranch + (status.hasUncommittedChanges ? " • Has Changes" : ""))
                                        .font(.caption)
                                        .padding(4)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        Divider()
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding(24)
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle("Dashboard")
    }
    
    private var gitReposCount: Int {
        projects.filter { $0.isGitRepository }.count
    }
    
    private var projectsWithChanges: Int {
        projects.filter { $0.gitStatus?.hasUncommittedChanges == true }.count
    }
    
    private var totalPRs: Int {
        projects.reduce(0) { $0 + ($1.gitStatus?.pendingPullRequests ?? 0) }
    }
    
    private var recentProjects: [Project] {
        projects.sorted { $0.lastScanned > $1.lastScanned }.prefix(5).map { $0 }
    }
    
    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
