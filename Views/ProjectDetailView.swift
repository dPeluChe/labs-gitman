import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    let onRefresh: () -> Void
    let onAppear: () -> Void

    @ObservedObject var viewModel: ProjectScannerViewModel // Added for parent lookup
    let onNavigateToProject: (String) -> Void // Added for navigation
    
    @State private var showingLLMAnalysis = false
    @State private var showingSheet = false
    @State private var selectedTab: DetailTab = .overview
    @State private var isRefreshing = false
    @State private var showingCommitDetails = false
    @State private var showingUncommittedChanges = false
    @Namespace private var tabAnimation

    enum DetailTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case files = "Files"
        case terminal = "Terminal"
        case branches = "Branches & History"
        var id: String { rawValue }
    }

    init(project: Project, viewModel: ProjectScannerViewModel, onNavigateToProject: @escaping (String) -> Void, onRefresh: @escaping () -> Void, onAppear: @escaping () -> Void = {}) {
        self.project = project
        self.viewModel = viewModel
        self.onNavigateToProject = onNavigateToProject
        self.onRefresh = onRefresh
        self.onAppear = onAppear
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding()
                .background(Color(.windowBackgroundColor))

            // Standard TabView for reliable switching
            TabView(selection: $selectedTab) {
                OverviewContent()
                    .tabItem { Text("Overview") }
                    .tag(DetailTab.overview)
                
                FileExplorerView(projectPath: project.path)
                    .tabItem { Text("Files") }
                    .tag(DetailTab.files)
                
                TerminalView(projectPath: project.path)
                    .tabItem { Text("Terminal") }
                    .tag(DetailTab.terminal)
                
                BranchesView(project: project)
                    .tabItem { Text("Branches") }
                    .tag(DetailTab.branches)
            }
            .padding(.top, 0)
        }
        .onAppear {
            onAppear()
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle(project.name)
        .sheet(isPresented: $showingSheet) {
            LLMAnalysisSheet(project: project)
        }
        .sheet(isPresented: $showingCommitDetails) {
            CommitHistorySheet(project: project)
        }
        .sheet(isPresented: $showingUncommittedChanges) {
            UncommittedChangesSheet(project: project)
        }
    }
    
    // Extracted Overview Content
    @ViewBuilder
    private func OverviewContent() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if project.isGitRepository {
                    if let status = project.gitStatus {
                        // Two column layout
                        HStack(alignment: .top, spacing: 20) {
                            // LEFT COLUMN: Commit & Changes related (60%)
                            VStack(alignment: .leading, spacing: 16) {
                                // Uncommitted Changes Section (if any)
                                if status.hasUncommittedChanges {
                                    Button(action: {
                                        showingUncommittedChanges = true
                                    }) {
                                        changesSectionContent(status: status)
                                    }
                                    .buttonStyle(.plain)
                                }

                                // Latest Commit Section (clickable for details)
                                if let hash = status.lastCommitHash {
                                    Button(action: {
                                        showingCommitDetails = true
                                    }) {
                                        VStack(alignment: .leading, spacing: 12) {
                                            HStack {
                                                Text("Latest Commit")
                                                    .font(.headline)
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }

                                            VStack(alignment: .leading, spacing: 8) {
                                                HStack(alignment: .top, spacing: 8) {
                                                    Image(systemName: "signpost.right.and.left")
                                                        .foregroundColor(.secondary)
                                                        .font(.title2)

                                                    VStack(alignment: .leading, spacing: 6) {
                                                        Text(status.lastCommitMessage ?? "No message")
                                                            .font(.body)
                                                            .fontWeight(.medium)
                                                            .lineLimit(8)
                                                            .fixedSize(horizontal: false, vertical: true)

                                                        HStack(spacing: 8) {
                                                            Text(hash.prefix(8))
                                                                .font(.system(.caption, design: .monospaced))
                                                                .padding(.horizontal, 6)
                                                                .padding(.vertical, 2)
                                                                .background(Color.secondary.opacity(0.1))
                                                                .cornerRadius(4)

                                                            if let commitDate = status.lastCommitDate {
                                                                Text(relativeTime(commitDate))
                                                                    .font(.caption)
                                                                    .foregroundColor(.secondary)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.controlBackgroundColor))
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Click to view commit details")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // RIGHT COLUMN: Info & Actions (40%)
                            VStack(alignment: .leading, spacing: 16) {
                                // Branches Info
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Branches")
                                        .font(.headline)
                                        .foregroundColor(.secondary)

                                    VStack(spacing: 8) {
                                        // Current branch
                                        HStack {
                                            Image(systemName: "record.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.caption2)
                                            Text(status.currentBranch)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(6)

                                        // Other branches count
                                        let otherBranchesCount = status.branches.filter { !$0.isCurrent }.count
                                        if otherBranchesCount > 0 {
                                            HStack {
                                                Image(systemName: "circle")
                                                    .foregroundColor(.secondary)
                                                    .font(.caption2)
                                                Text("\(otherBranchesCount) other branch\(otherBranchesCount > 1 ? "es" : "")")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                selectedTab = .branches
                                            }
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(.controlBackgroundColor))
                                .cornerRadius(12)

                                // AI Analysis Button
                                Button(action: {
                                    showingSheet = true
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "brain.head.profile")
                                            .font(.title3)
                                            .foregroundColor(.purple)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Analyze with AI")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Text("Get insights & recommendations")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                .help("Analyze repository with AI")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                    } else {
                        loadingView
                    }

                } else {
                    nonGitView
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Analyzing Repository...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                // Parent Workspace Navigation (Back Button style)
                if let parent = viewModel.getParent(of: project.id) {
                    Button(action: {
                        onNavigateToProject(parent.id.uuidString)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.turn.up.left")
                            Text("Return to \(parent.name)")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 4)
                }

                HStack(spacing: 8) {
                    Text(project.name)
                        .font(.system(size: 28, weight: .bold))

                    // Branch badge
                    if let status = project.gitStatus {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.caption2)
                            Text(status.currentBranch)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(status.hasUncommittedChanges ? Color.yellow.opacity(0.2) : Color.green.opacity(0.15))
                        .foregroundColor(status.hasUncommittedChanges ? .orange : .green)
                        .cornerRadius(6)
                    }

                    // GitHub/Open Repository button (separate from branch badge)
                    if let repoURL = extractRepositoryURL(from: project.path) {
                        Button(action: {
                            NSWorkspace.shared.open(repoURL)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.caption)
                                Text("Open in \(repoURL.host?.contains("github") == true ? "GitHub" : repoURL.host ?? "Repository")")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .foregroundColor(.secondary)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .help("Open repository in browser")
                    }

                    // Uncommitted changes badge
                    if let status = project.gitStatus, status.hasUncommittedChanges {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil.circle")
                                .font(.caption2)
                            Text("Uncommitted")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(6)
                    }
                }

                Button(action: {
                    NSWorkspace.shared.open(URL(fileURLWithPath: project.path))
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.caption2)
                        Text(project.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Divider()
                            .frame(height: 12)

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("Updated: \(relativeTimeShort(project.gitStatus?.lastCommitDate ?? project.lastScanned))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Divider()
                            .frame(height: 12)

                        HStack(spacing: 4) {
                            Image(systemName: "eye")
                                .font(.caption2)
                            Text("Reviewed: \(relativeTimeShort(project.lastReviewed))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Click to open in Finder")
            }

            Spacer()

            Button(action: {
                isRefreshing = true
                onRefresh()
                // Reset refresh state after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isRefreshing = false
                }
            }) {
                ZStack {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.secondary.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .help("Refresh project (⌘R)")
            .disabled(isRefreshing)
        }
    }

    private func changesSectionContent(status: GitStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Calculate total files
            let totalFiles = status.modifiedFiles.count + status.stagedFiles.count + status.untrackedFiles.count

            Label("WIP - \(totalFiles) file\(totalFiles == 1 ? "" : "s") modified", systemImage: "pencil.circle.fill")
                .font(.headline)

            VStack(spacing: 8) {
                if !status.modifiedFiles.isEmpty { fileList(title: "Modified", files: status.modifiedFiles, icon: "pencil", color: .orange) }
                if !status.stagedFiles.isEmpty { fileList(title: "Staged", files: status.stagedFiles, icon: "plus.circle", color: .green) }
                if !status.untrackedFiles.isEmpty { fileList(title: "Untracked", files: status.untrackedFiles, icon: "questionmark.square", color: .gray) }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
        }
    }

    private func fileList(title: String, files: [String], icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundColor(.secondary).fontWeight(.medium)
            ForEach(files.prefix(5), id: \.self) { file in
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.caption2)
                        .frame(width: 16) // Fixed width for alignment
                    Text(file)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                }
            }
            if files.count > 5 { Text("+ \(files.count - 5) more").font(.caption2).foregroundColor(.secondary) }
        }
        .padding(.bottom, 4)
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func relativeTimeShort(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func extractRepositoryURL(from path: String) -> URL? {
        // Try to get remote URL from git config
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["config", "--get", "remote.origin.url"]
        task.currentDirectoryURL = URL(fileURLWithPath: path)

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            // Convert git@github.com:user/repo.git to https://github.com/user/repo
            if output.contains("github.com") {
                let url = output
                    .replacingOccurrences(of: "git@github.com:", with: "https://github.com/")
                    .replacingOccurrences(of: "https://github.com:", with: "https://github.com/")
                    .replacingOccurrences(of: ".git", with: "")
                return URL(string: url)
            }

            // Convert git@gitlab.com:user/repo.git to https://gitlab.com/user/repo
            if output.contains("gitlab.com") {
                let url = output
                    .replacingOccurrences(of: "git@gitlab.com:", with: "https://gitlab.com/")
                    .replacingOccurrences(of: "https://gitlab.com:", with: "https://gitlab.com/")
                    .replacingOccurrences(of: ".git", with: "")
                return URL(string: url)
            }

            // Convert git@bitbucket.org:user/repo.git to https://bitbucket.org/user/repo
            if output.contains("bitbucket.org") {
                let url = output
                    .replacingOccurrences(of: "git@bitbucket.org:", with: "https://bitbucket.org/")
                    .replacingOccurrences(of: "https://bitbucket.org:", with: "https://bitbucket.org/")
                    .replacingOccurrences(of: ".git", with: "")
                return URL(string: url)
            }

            // Generic HTTPS URL
            if output.hasPrefix("https://") || output.hasPrefix("http://") {
                let url = output.replacingOccurrences(of: ".git", with: "")
                return URL(string: url)
            }
        } catch {}

        return nil
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
}

// Separate Branch View Component with integrated History
struct BranchesView: View {
    let project: Project
    @State private var searchText = ""
    @State private var commits: [GitCommit] = []
    @State private var isLoadingCommits = false
    @State private var hasLoadedCommits = false

    var body: some View {
        HStack(spacing: 0) {
            // Left Column: Branches Box
            VStack(alignment: .leading, spacing: 0) {
                Text("Branches")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()
                
                Divider()
                
                branchesList
            }
            .frame(width: 250)
            .background(Color(.controlBackgroundColor))
            
            Divider()
            
            // Right Column: History Timeline (Main)
            VStack(alignment: .leading, spacing: 0) {
                Text("History")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding() // Match branches header
                
                Divider()
                
                commitTimeline
            }
        }
        .task {
            if !hasLoadedCommits {
                await loadCommitHistory()
                hasLoadedCommits = true
            }
        }
    }

    private var branchesList: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let branches = project.gitStatus?.branches {
                    ForEach(filterBranches(branches), id: \.name) { branch in
                        branchRow(branch)
                        Divider()
                    }
                } else {
                    Text("No branch info available")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
    }

    private var commitTimeline: some View {
        Group {
            if isLoadingCommits {
                loadingView
            } else if commits.isEmpty {
                Text("No commits found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    // Use a VStack for better structure
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(commits.enumerated()), id: \.element.hash) { index, commit in
                            HStack(alignment: .top, spacing: 16) {
                                // Timeline Line & Dot Column
                                VStack(spacing: 0) {
                                    // Top Line Segment
                                    Rectangle()
                                        .fill(index == 0 ? Color.clear : Color.secondary.opacity(0.3))
                                        .frame(width: 2, height: 16)
                                    
                                    // Dot
                                    ZStack {
                                        Circle()
                                            .fill(index == 0 ? Color.accentColor : Color.secondary.opacity(0.5))
                                            .frame(width: 10, height: 10)
                                        if index == 0 {
                                            Circle()
                                                .stroke(Color(.windowBackgroundColor), lineWidth: 2)
                                                .frame(width: 10, height: 10)
                                        }
                                    }
                                    
                                    // Bottom Line Segment
                                    Rectangle()
                                        .fill(index == commits.count - 1 ? Color.clear : Color.secondary.opacity(0.3))
                                        .frame(width: 2) // Extends to bottom of row
                                }
                                .frame(width: 16) // Fixed width for alignment column

                                // Commit Data Column
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(commit.message)
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                        
                                        Spacer()
                                        
                                        Text(relativeTime(commit.date))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack(spacing: 8) {
                                        Text(commit.hash.prefix(7))
                                            .font(.system(.caption, design: .monospaced))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.1))
                                            .cornerRadius(4)
                                        
                                        HStack(spacing: 4) {
                                            Image(systemName: "person.circle")
                                            Text(commit.author)
                                        }
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.bottom, 24) // Add spacing for next row
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
    }

    private func branchRow(_ branch: GitBranch) -> some View {
        HStack {
            if branch.isCurrent {
                Image(systemName: "checkmark")
                    .foregroundColor(.green)
                    .font(.caption.bold())
                    .frame(width: 16)
            } else {
                Spacer().frame(width: 16)
            }
            
            Text(branch.name)
                .font(.body)
                .fontWeight(branch.isCurrent ? .semibold : .regular)
                .lineLimit(1)
                
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background(branch.isCurrent ? Color.green.opacity(0.05) : Color.clear)
        .contextMenu {
            Button("Switch to Branch") {
                Task {
                    await switchBranch(branch.name)
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading commit history...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
    }

    private func filterBranches(_ branches: [GitBranch]) -> [GitBranch] {
        if searchText.isEmpty { return branches }
        return branches.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func loadCommitHistory() async {
        isLoadingCommits = true
        defer { isLoadingCommits = false }

        let gitService = GitService()
        do {
            commits = try await gitService.getCommitHistory(path: project.path, limit: 15)
        } catch {
            print("Error loading commits: \(error)")
        }
    }

    @MainActor
    private func switchBranch(_ branchName: String) async {
        let gitService = GitService()
        
        do {
            try await gitService.switchBranch(path: project.path, branchName: branchName)
            // Refresh project status after switching
            // This will be handled by the parent view's refresh mechanism
        } catch GitService.GitError.uncommittedChanges {
            print("Cannot switch: uncommitted changes")
        } catch {
            print("Failed to switch branch: \(error.localizedDescription)")
        }
    }
}

// Commit History Sheet Component
struct CommitHistorySheet: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @State private var commits: [GitCommit] = []
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let status = project.gitStatus, let hash = status.lastCommitHash {
                    // Latest Commit
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Latest Commit")
                            .font(.title2)
                            .fontWeight(.bold)

                        VStack(alignment: .leading, spacing: 12) {
                            // Hash with copy button
                            HStack {
                                Image(systemName: "signpost.right.and.left")
                                    .foregroundColor(.secondary)
                                Text(hash)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(hash, forType: .string)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Copy commit hash")
                            }

                            // Message
                            Text(status.lastCommitMessage ?? "No message provided")
                                .font(.body)
                                .fontWeight(.medium)

                            // Date
                            if let date = status.lastCommitDate {
                                HStack(spacing: 12) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("Committed")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(relativeTime(date))
                                            .font(.caption)
                                    }

                                    Spacer()

                                    Text(DateFormatter.fullDate.string(from: date))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(12)
                    }

                    Divider()

                    // Load More Commits Button
                    Button(action: {
                        loadMoreCommits()
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Load previous 3 commits")
                                    .font(.subheadline)
                                Image(systemName: "chevron.down")
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)

                    // Previous Commits List
                    if !commits.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Previous Commits")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(commits) { commit in
                                    HStack(alignment: .top, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(commit.message)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            HStack(spacing: 8) {
                                                Text(commit.hash.prefix(8))
                                                    .font(.system(.caption, design: .monospaced))
                                                    .foregroundColor(.secondary)
                                                Text(relativeTime(commit.date))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.secondary.opacity(0.05))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .frame(minWidth: 600, minHeight: 400)
        .navigationTitle("Commit History")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
    }

    private func loadMoreCommits() {
        isLoading = true
        let gitService = GitService()
        Task {
            do {
                let currentCount = commits.count
                let newCommits = try await gitService.getCommitHistory(path: project.path, limit: currentCount + 3)
                commits = Array(newCommits.dropFirst()) // Skip first one (already shown)
            } catch {
                print("Error loading commits: \(error)")
            }
            isLoading = false
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Uncommitted Changes Sheet Component
struct UncommittedChangesSheet: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let status = project.gitStatus {
                    Text("Uncommitted Changes")
                        .font(.title2)
                        .fontWeight(.bold)

                    VStack(alignment: .leading, spacing: 16) {
                        if !status.modifiedFiles.isEmpty {
                            fileChangeList(title: "Modified", files: status.modifiedFiles, icon: "pencil", color: .orange, count: status.modifiedFiles.count)
                        }

                        if !status.stagedFiles.isEmpty {
                            fileChangeList(title: "Staged", files: status.stagedFiles, icon: "plus.circle", color: .green, count: status.stagedFiles.count)
                        }

                        if !status.untrackedFiles.isEmpty {
                            fileChangeList(title: "Untracked", files: status.untrackedFiles, icon: "questionmark.square", color: .gray, count: status.untrackedFiles.count)
                        }

                        if !status.modifiedFiles.isEmpty || !status.stagedFiles.isEmpty || !status.untrackedFiles.isEmpty {
                            Divider()
                            Text("Total: \(status.modifiedFiles.count + status.stagedFiles.count + status.untrackedFiles.count) files")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(24)
        }
        .frame(minWidth: 600, minHeight: 400)
        .navigationTitle("Uncommitted Changes")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
    }

    private func fileChangeList(title: String, files: [String], icon: String, color: Color, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Text("(\(count))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(files, id: \.self) { file in
                    HStack {
                        Image(systemName: icon)
                            .foregroundColor(color)
                            .font(.caption)
                            .frame(width: 20)
                        Text(file)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(6)
                }
            }
        }
    }
}

extension DateFormatter {
    static let fullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
