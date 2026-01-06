import SwiftUI

struct WorkspaceDetailView: View {
    let workspace: Project
    let onNavigateToProject: (String) -> Void // Callback to navigate to a sub-project
    
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "folder.fill.badge.gearshape")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                        Text(workspace.name)
                            .font(.system(size: 28, weight: .bold))
                    }
                    
                    Text(workspace.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                
                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    statCard(title: "Projects", value: "\(workspace.subProjects.count)", icon: "folder", color: .blue)
                    statCard(title: "Changes", value: "\(projectsWithChanges)", icon: "pencil", color: .orange)
                    statCard(title: "Pending PRs", value: "\(totalPRs)", icon: "arrow.triangle.pull", color: .green)
                }
                
                // Projects List
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Projects in Workspace")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        if !searchText.isEmpty {
                            Text("\(filteredProjects.count) found")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if filteredProjects.isEmpty {
                        Text("No projects found matching '\(searchText)'")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                            ForEach(filteredProjects) { project in
                                Button(action: {
                                    onNavigateToProject(project.id.uuidString)
                                }) {
                                    ProjectSummaryCard(project: project)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle(workspace.name)
        .searchable(text: $searchText, prompt: "Search workspace projects...")
    }
    
    private var filteredProjects: [Project] {
        if searchText.isEmpty {
            return workspace.subProjects
        }
        return workspace.subProjects.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var projectsWithChanges: Int {
        workspace.subProjects.filter { $0.gitStatus?.hasUncommittedChanges == true }.count
    }
    
    private var totalPRs: Int {
        workspace.subProjects.reduce(0) { $0 + ($1.gitStatus?.pendingPullRequests ?? 0) }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.headline).lineLimit(1)
                Text(title).font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct ProjectSummaryCard: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                    Text(project.path)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                
                if let status = project.gitStatus {
                    if status.hasUncommittedChanges {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(.orange)
                    } else if status.pendingPullRequests > 0 {
                        Image(systemName: "arrow.triangle.pull")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue.opacity(0.5))
                    }
                }
            }
            
            Divider()
            
            if let status = project.gitStatus {
                HStack {
                    Label(status.currentBranch, systemImage: "arrow.triangle.branch")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    if let date = status.lastCommitDate {
                        Text(relativeTime(date))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("Not scanned yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
