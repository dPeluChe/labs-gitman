import SwiftUI

struct ProjectListView: View {
    @StateObject private var viewModel = ProjectScannerViewModel()
    @State private var showingAddPathSheet = false
    @State private var selectedProject: Project?

    var body: some View {
        NavigationSplitView {
            // Sidebar with project categories
            List(selection: $selectedProject) {
                Section("Git Repositories") {
                    ForEach(viewModel.gitRepositories) { project in
                        ProjectRowView(project: project)
                            .tag(project)
                    }
                }

                Section("Non-Git Projects") {
                    ForEach(viewModel.nonGitProjects) { project in
                        ProjectRowView(project: project)
                            .tag(project)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 250, ideal: 350)

        } detail: {
            // Detail view
            if let project = selectedProject {
                ProjectDetailView(
                    project: project,
                    onRefresh: {
                        Task {
                            await viewModel.refreshProjectStatus(project)
                        }
                    }
                )
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)

                    Text("Select a project to view details")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    Text("Add paths to monitor your projects")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("GitMonitor")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: {
                    Task {
                        await viewModel.scanAllProjects()
                    }
                }) {
                    if viewModel.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Scan", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isScanning)

                Spacer()

                Button(action: {
                    showingAddPathSheet = true
                }) {
                    Label("Add Path", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPathSheet) {
            AddPathSheet(viewModel: viewModel)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
}

struct ProjectRowView: View {
    let project: Project

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)

                if let status = project.gitStatus {
                    HStack(spacing: 8) {
                        Image(systemName: "git.branch")
                            .font(.caption)
                        Text(status.currentBranch)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if status.hasUncommittedChanges {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundColor(.orange)
                            Text("Uncommitted changes")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }

                        if status.pendingPullRequests > 0 {
                            Image(systemName: "arrow.triangle.pull")
                                .font(.caption)
                            Text("\(status.pendingPullRequests) PR(s)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                } else {
                    Text("Not a Git repository")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        guard let status = project.gitStatus else {
            return .gray
        }

        if status.hasUncommittedChanges {
            return .orange
        }

        if status.pendingPullRequests > 0 {
            return .blue
        }

        return .green
    }
}

#Preview {
    ProjectListView()
}
