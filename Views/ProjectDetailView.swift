import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    let onRefresh: () -> Void

    @State private var showingLLMAnalysis = false
    @State private var showingSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .font(.title)
                        Text(project.name)
                            .font(.title)
                            .fontWeight(.bold)

                        Spacer()

                        Button(action: onRefresh) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }

                    Text(project.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom)

                if project.isGitRepository, let status = project.gitStatus {
                    gitStatusSection(status: status)
                } else {
                    nonGitSection
                }

                // Actions
                actionsSection
            }
            .padding()
        }
        .navigationTitle(project.name)
        .sheet(isPresented: $showingSheet) {
            LLMAnalysisSheet(project: project)
        }
    }

    private func gitStatusSection(status: GitStatus) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Branch Info
            GroupBox(label: Label("Branch Information", systemImage: "git.branch")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Current Branch:")
                            .foregroundColor(.secondary)
                        Text(status.currentBranch)
                            .fontWeight(.semibold)
                    }

                    if let hash = status.lastCommitHash {
                        HStack {
                            Text("Last Commit:")
                                .foregroundColor(.secondary)
                            Text(hash.prefix(8))
                                .font(.system(.caption, design: .monospaced))
                        }
                    }

                    if let message = status.lastCommitMessage {
                        HStack {
                            Text("Message:")
                                .foregroundColor(.secondary)
                            Text(message)
                                .font(.caption)
                                .lineLimit(2)
                        }
                    }
                }
            }

            // Status
            if status.hasUncommittedChanges {
                GroupBox(label: Label("Changes", systemImage: "exclamationmark.triangle.fill")) {
                    VStack(alignment: .leading, spacing: 8) {
                        if !status.modifiedFiles.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Modified:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ForEach(status.modifiedFiles, id: \.self) { file in
                                    HStack {
                                        Image(systemName: "pencil")
                                            .font(.caption2)
                                        Text(file)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }

                        if !status.stagedFiles.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Staged:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ForEach(status.stagedFiles, id: \.self) { file in
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                        Text(file)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }

                        if !status.untrackedFiles.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Untracked:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ForEach(status.untrackedFiles, id: \.self) { file in
                                    HStack {
                                        Image(systemName: "questionmark.circle")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                        Text(file)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Pull Requests
            if status.pendingPullRequests > 0 {
                GroupBox(label: Label("Pull Requests", systemImage: "arrow.triangle.pull")) {
                    HStack {
                        Text("You have \(status.pendingPullRequests) pending PR(s)")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "external.link")
                            .font(.caption)
                    }
                }
            }
        }
    }

    private var nonGitSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Not a Git Repository")
                        .font(.headline)
                }

                Text("This directory is not a Git repository. Only Git repositories will show detailed status information.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var actionsSection: some View {
        GroupBox(label: Label("Actions", systemImage: "bolt.fill")) {
            VStack(spacing: 12) {
                if project.isGitRepository {
                    Button(action: {
                        showingSheet = true
                    }) {
                        Label("Analyze with AI", systemImage: "brain")
                    }
                    .controlSize(.large)

                    Divider()

                    HStack(spacing: 16) {
                        Button(action: {
                            NSWorkspace.shared.open(URL(fileURLWithPath: project.path))
                        }) {
                            Label("Open in Finder", systemImage: "folder")
                        }

                        Button(action: {
                            openInTerminal()
                        }) {
                            Label("Open in Terminal", systemImage: "terminal")
                        }
                    }
                } else {
                    Button(action: {
                        NSWorkspace.shared.open(URL(fileURLWithPath: project.path))
                    }) {
                        Label("Open in Finder", systemImage: "folder")
                    }
                    .controlSize(.large)
                }
            }
        }
    }

    private func openInTerminal() {
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(project.path)'"
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}

#Preview {
    NavigationStack {
        ProjectDetailView(
            project: Project(
                path: "/Users/test/project",
                name: "Test Project"
            ),
            onRefresh: {}
        )
    }
}
