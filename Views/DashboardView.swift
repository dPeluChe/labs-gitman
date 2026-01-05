import SwiftUI

struct DashboardView: View {
    let projects: [Project]
    var isLoading: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Loading Indicator
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Refreshing projects...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    .transition(.opacity)
                }

                // Summary Cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    summaryCard(title: "Total Projects", value: "\(projects.count)", icon: "folder.fill", color: .blue)
                    summaryCard(title: "Git Repos", value: "\(gitReposCount)", icon: "arrow.triangle.branch", color: .purple)
                    summaryCard(title: "Changes", value: "\(projectsWithChanges)", icon: "pencil", color: .orange)
                    summaryCard(title: "Pending PRs", value: "\(totalPRs)", icon: "arrow.triangle.pull", color: .green)
                }
                
                // Recent Activity / Timeline
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recent Activity")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    ForEach(recentProjects) { project in
                        HStack(alignment: .top, spacing: 16) {
                            // Status Dot
                            Circle()
                                .fill(statusColor(for: project))
                                .frame(width: 10, height: 10)
                                .offset(y: 6)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(project.name)
                                        .font(.headline)
                                    Spacer()
                                    if let date = project.gitStatus?.lastCommitDate {
                                        Text(relativeTime(date))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                if let status = project.gitStatus {
                                    HStack(spacing: 8) {
                                        Text(status.currentBranch)
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.1))
                                            .cornerRadius(4)
                                        
                                        if let message = status.lastCommitMessage {
                                            Text(message)
                                                .font(.caption)
                                                .lineLimit(1)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                } else {
                                    Text("Scanned " + relativeTime(project.lastScanned))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
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
        .animation(.default, value: isLoading)
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
    
    // Sort by Last Commit Date if available, otherwise Last Scanned (but consistent)
    private var recentProjects: [Project] {
        projects.sorted {
            let date1 = $0.gitStatus?.lastCommitDate ?? $0.lastScanned
            let date2 = $1.gitStatus?.lastCommitDate ?? $1.lastScanned
            return date1 > date2
        }.prefix(10).map { $0 }
    }
    
    private func statusColor(for project: Project) -> Color {
        guard let status = project.gitStatus else { return .gray }
        if status.hasUncommittedChanges { return .orange }
        if status.pendingPullRequests > 0 { return .green }
        return .blue
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
