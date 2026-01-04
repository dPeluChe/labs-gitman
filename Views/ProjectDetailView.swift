import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    let onRefresh: () -> Void

    @State private var showingLLMAnalysis = false
    @State private var showingSheet = false
    @State private var selectedTab: DetailTab

    enum DetailTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case files = "Files"
        case terminal = "Terminal"
        var id: String { rawValue }
    }
    
    init(project: Project, initialTab: DetailTab? = nil, onRefresh: @escaping () -> Void) {
        self.project = project
        self.onRefresh = onRefresh
        _selectedTab = State(initialValue: initialTab ?? .overview)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding()
                .background(Color(.windowBackgroundColor))

            // Tab Picker
            Picker("View", selection: $selectedTab) {
                ForEach(DetailTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(Color(.windowBackgroundColor))

            // Tab Content
            switch selectedTab {
            case .overview:
                OverviewContent()
            case .files:
                FileExplorerView(projectPath: project.path)
            case .terminal:
                TerminalView(projectPath: project.path)
            }
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle(project.name)
        .sheet(isPresented: $showingSheet) {
            LLMAnalysisSheet(project: project)
        }
    }
    
    // Extracted Overview Content
    @ViewBuilder
    private func OverviewContent() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if project.isGitRepository, let status = project.gitStatus {
                    // Git Statistics Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        statCard(title: "Branch", value: status.currentBranch, icon: "arrow.triangle.branch", color: .blue)
                        statCard(title: "Status", value: status.healthStatus == .clean ? "Clean" : "Changes", icon: status.healthStatus == .clean ? "checkmark.circle.fill" : "exclamationmark.triangle.fill", color: status.healthStatus == .clean ? .green : .orange)
                    }

                    // Detailed Status Sections
                    if status.hasUncommittedChanges {
                        changesSection(status: status)
                    }

                    if status.pendingPullRequests > 0 {
                        prSection(count: status.pendingPullRequests)
                    }
                    
                    if let hash = status.lastCommitHash {
                        commitSection(hash: hash, message: status.lastCommitMessage, date: status.lastCommitDate)
                    }
                    
                    if status.hasGitHubRemote {
                        githubSection
                    }

                } else {
                    nonGitView
                }

                // Action Buttons
                actionsView
            }
            .padding(20)
        }
    }

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(project.name)
                    .font(.system(size: 28, weight: .bold))
                
                Text(project.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.secondary.opacity(0.1)))
            }
            .buttonStyle(.plain)
        }
    }
    
    private var githubSection: some View {
        HStack {
            Image(systemName: "cloud.fill")
            Text("Connected to GitHub")
                .fontWeight(.medium)
            Spacer()
            Link("View on GitHub", destination: URL(string: "https://github.com")!)
                .font(.caption)
                .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
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

    private func changesSection(status: GitStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Uncommitted Changes", systemImage: "pencil.circle.fill")
                .font(.headline)
            VStack(spacing: 8) {
                if !status.modifiedFiles.isEmpty { fileList(title: "Modified", files: status.modifiedFiles, icon: "pencil", color: .orange) }
                if !status.stagedFiles.isEmpty { fileList(title: "Staged", files: status.stagedFiles, icon: "plus.circle", color: .green) }
                if !status.untrackedFiles.isEmpty { fileList(title: "Untracked", files: status.untrackedFiles, icon: "questionmark.square", color: .gray) }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    private func fileList(title: String, files: [String], icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundColor(.secondary).fontWeight(.medium)
            ForEach(files.prefix(5), id: \.self) { file in
                HStack {
                    Image(systemName: icon).foregroundColor(color).font(.caption2)
                    Text(file).font(.system(.caption, design: .monospaced)).lineLimit(1)
                }
            }
            if files.count > 5 { Text("+ \(files.count - 5) more").font(.caption2).foregroundColor(.secondary) }
        }
        .padding(.bottom, 4)
    }

    private func prSection(count: Int) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Pull Requests").font(.headline)
                Text("\(count) pending review").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Button("View") {}.buttonStyle(.borderedProminent).controlSize(.small)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func commitSection(hash: String, message: String?, date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Latest Commit").font(.headline)
            HStack(alignment: .top) {
                Image(systemName: "signpost.right.and.left").foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(message ?? "No message").font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text(hash.prefix(8)).font(.system(.caption, design: .monospaced)).padding(.horizontal, 6).padding(.vertical, 2).background(Color.secondary.opacity(0.1)).cornerRadius(4)
                        if let date = date {
                            Text(relativeTime(date)).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var nonGitView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark").font(.system(size: 48)).foregroundColor(.secondary)
            Text("Not a Git Repository").font(.title3).fontWeight(.semibold)
            Text("Initialize a repository or select another project to view Git statistics.").font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(16)
    }

    private var actionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions").font(.headline)
            HStack(spacing: 12) {
                if project.isGitRepository {
                    actionButton(title: "Analyze AI", icon: "brain.head.profile", color: .purple) { showingSheet = true }
                }
                actionButton(title: "Finder", icon: "folder", color: .blue) { NSWorkspace.shared.open(URL(fileURLWithPath: project.path)) }
                if project.isGitRepository {
                    actionButton(title: "Terminal", icon: "terminal", color: .gray) { openInTerminal() }
                }
            }
        }
    }
    
    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.title2).foregroundColor(color)
                Text(title).font(.caption).fontWeight(.medium)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12).background(Color(.controlBackgroundColor)).cornerRadius(10).shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func openInTerminal() {
        // This opens the INTERNAL terminal since we are in the detail view
        // Switching tab to terminal
        selectedTab = .terminal
    }
}
