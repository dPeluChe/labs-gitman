import SwiftUI
import AppKit

struct ProjectListView: View {
    @StateObject private var viewModel = ProjectScannerViewModel()
    @StateObject private var settings = SettingsStore()
    @State private var showingAddPathSheet = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var searchText = ""

    // Filtering & Sorting
    @State private var filterOption: FilterOption = .all
    @State private var sortOption: SortOption = .activity

    // Selection state handling both Dashboard and Projects
    @State private var selection: SidebarSelection? = .dashboard
    @FocusState private var focusedSearch: Bool

    enum SidebarSelection: Hashable {
        case dashboard
        case project(Project.ID) // Removed tab to simplify selection logic
    }
    
    enum FilterOption {
        case all, clean, changes
    }

    enum SortOption {
        case name, recent, activity
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                // Dependency Warning Banner
                if !viewModel.missingDependencies.isEmpty {
                    dependencyWarningView
                }

                List(selection: $selection) {
                    NavigationLink(value: SidebarSelection.dashboard) {
                        Label("Dashboard", systemImage: "square.grid.2x2")
                            .font(.headline)
                            .padding(.vertical, 8)
                    }

                    if !filteredGitRepos.isEmpty {
                        Section(header: sectionHeader("Git Repositories", icon: "arrow.triangle.branch", count: filteredGitRepos.count)) {
                            ForEach(filteredGitRepos) { project in
                                NavigationLink(value: SidebarSelection.project(project.id)) {
                                    ProjectRowView(project: project)
                                        .contextMenu {
                                            openInInternalTerminalButton(project)
                                            openInExternalTerminalButton(project)
                                            openInFinderButton(project)
                                            Divider()
                                            copyPathButton(project)
                                            Divider()
                                            removeFromListButton(project)
                                        }
                                }
                            }
                        }
                    }

                    if !filteredNonGit.isEmpty {
                        Section(header: sectionHeader("Other Projects", icon: "folder", count: filteredNonGit.count)) {
                            ForEach(filteredNonGit) { project in
                                NavigationLink(value: SidebarSelection.project(project.id)) {
                                    ProjectRowView(project: project)
                                        .contextMenu {
                                            openInExternalTerminalButton(project)
                                            openInFinderButton(project)
                                            Divider()
                                            copyPathButton(project)
                                            Divider()
                                            removeFromListButton(project)
                                        }
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .searchable(text: $searchText, placement: .sidebar, prompt: "Search projects...")
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.projects)
            }
            .navigationTitle("GitMonitor")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddPathSheet = true }) {
                        Label("Add Path", systemImage: "plus")
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Picker("Filter", selection: $filterOption) {
                            Text("All").tag(FilterOption.all)
                            Text("Clean").tag(FilterOption.clean)
                            Text("Changes").tag(FilterOption.changes)
                        }
                        
                        Divider()
                        
                        Picker("Sort", selection: $sortOption) {
                            Text("Name").tag(SortOption.name)
                            Text("Last Commit").tag(SortOption.recent)
                            Text("Activity (Files + Commits)").tag(SortOption.activity)
                        }
                    } label: {
                        Label("Filter & Sort", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        Task { await viewModel.scanAllProjects() }
                    }) {
                        if viewModel.isScanning {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Scan", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(viewModel.isScanning)
                }
            }
            .sheet(isPresented: $showingAddPathSheet) {
                AddPathSheet(viewModel: viewModel)
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                if let errorMessage = viewModel.errorMessage { Text(errorMessage) }
            }
            .onAppear {
                Task {
                    await viewModel.checkDependencies()
                    // Auto-scan projects on app launch if:
                    // 1. No projects loaded yet, OR
                    // 2. Projects exist but have no gitStatus (never scanned properly)
                    // 3. Haven't been scanned in last 5 minutes (stale data)
                    let needsScan = viewModel.projects.isEmpty ||
                                   viewModel.projects.allSatisfy { $0.gitStatus == nil } ||
                                   viewModel.projects.contains { $0.gitStatus == nil || $0.lastScanned.timeIntervalSinceNow < -300 }
                    if needsScan {
                        await viewModel.scanAllProjects()
                    }
                }
            }
            // Shortcuts commented out to isolate issue
            // .onAppear {
            //     setupKeyboardShortcuts()
            // }

        } detail: {
            detailContent
                // Shortcuts commented out to isolate issue
                // .onAppear {
                //     setupDetailKeyboardShortcuts()
                // }
        }
    }

    private var detailContent: some View {
        Group {
            switch selection {
            case .dashboard:
                DashboardView(projects: viewModel.projects, isLoading: viewModel.isScanning)
            case .project(let projectId):
                if let project = viewModel.projects.first(where: { $0.id == projectId }) {
                    ProjectDetailView(
                        project: project,
                        onRefresh: {
                            Task { await viewModel.refreshProjectStatus(project) }
                        },
                        onAppear: {
                            viewModel.markProjectAsReviewed(project)
                        }
                    )
                    .id(project.id) // Ensure consistent identity
                } else {
                    // Project not found (maybe deleted)
                    Text("Project not found")
                        .font(.title)
                        .foregroundColor(.secondary)
                }
            case nil:
                emptyStateView
            }
        }
    }

    // MARK: - Keyboard Shortcuts
    // Commented out to isolate issues
    /*
    private func setupKeyboardShortcuts() {
        // Store the monitor reference to avoid duplicates
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }

    private func setupDetailKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            // ... (rest of shortcuts code) ...
            return event
        }
    }
    */

    private enum NavigationDirection {
        case up, down
    }

    private func navigateProjects(direction: NavigationDirection) {
        let allProjects = filteredGitRepos + filteredNonGit

        guard let currentIndex = currentProjectIndex(in: allProjects) else { return }

        let newIndex: Int
        switch direction {
        case .up:
            newIndex = max(0, currentIndex - 1)
        case .down:
            newIndex = min(allProjects.count - 1, currentIndex + 1)
        }

        if newIndex >= 0 && newIndex < allProjects.count {
            let project = allProjects[newIndex]
            selection = .project(project.id)
        }
    }

    private func currentProjectIndex(in projects: [Project]) -> Int? {
        guard case .project(let projectId) = selection else { return nil }
        return projects.firstIndex { $0.id == projectId }
    }

    // MARK: - Context Menu Buttons

    private func openInInternalTerminalButton(_ project: Project) -> some View {
        Button {
             // For now, selecting a project goes to the default view (Overview).
             // Since we removed tab support from SidebarSelection, we just select the project.
             selection = .project(project.id)
        } label: {
             Label("Open in Internal Terminal", systemImage: "desktopcomputer")
        }
    }
    
    private func openInExternalTerminalButton(_ project: Project) -> some View {
        Button {
            openExternalTerminal(path: project.path)
        } label: {
            Label("Open in \(settings.preferredTerminal.rawValue)", systemImage: "terminal")
        }
    }
    
    private func openInFinderButton(_ project: Project) -> some View {
        Button {
            NSWorkspace.shared.open(URL(fileURLWithPath: project.path))
        } label: {
            Label("Open in Finder", systemImage: "folder")
        }
    }
    
    private func copyPathButton(_ project: Project) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(project.path, forType: .string)
        } label: {
            Label("Copy Path", systemImage: "doc.on.doc")
        }
    }
    
    private func removeFromListButton(_ project: Project) -> some View {
        Button(role: .destructive) {
            viewModel.ignoreProject(project.path)
        } label: {
            Label("Remove from List", systemImage: "trash")
        }
    }
    
    private func openExternalTerminal(path: String) {
        let app = settings.preferredTerminal
        let script = "open -a \"\(app.bundleIdentifier)\" \"\(path)\""
        
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", script]
        task.launch()
    }
    
    private var filteredGitRepos: [Project] {
        processProjects(viewModel.gitRepositories)
    }
    
    private var filteredNonGit: [Project] {
        processProjects(viewModel.nonGitProjects)
    }
    
    private func processProjects(_ projects: [Project]) -> [Project] {
        var result = projects
        
        // 1. Search
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        // 2. Filter
        switch filterOption {
        case .all:
            break
        case .clean:
            result = result.filter { 
                guard let status = $0.gitStatus else { return true }
                return !status.hasUncommittedChanges 
            }
        case .changes:
            result = result.filter {
                 guard let status = $0.gitStatus else { return false }
                 return status.hasUncommittedChanges 
            }
        }
        
        // 3. Sort
        switch sortOption {
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .recent:
            result.sort {
                let date1 = $0.gitStatus?.lastCommitDate ?? $0.lastScanned
                let date2 = $1.gitStatus?.lastCommitDate ?? $1.lastScanned
                return date1 > date2
            }
        case .activity:
            // Priority 1: Uncommitted changes (modified files) - highest priority
            // Priority 2: Recent commits - secondary priority
            // Priority 3: Last scan time - fallback
            result.sort { project1, project2 in
                let hasChanges1 = project1.gitStatus?.hasUncommittedChanges ?? false
                let hasChanges2 = project2.gitStatus?.hasUncommittedChanges ?? false

                // If one has uncommitted changes and the other doesn't, prioritize the one with changes
                if hasChanges1 != hasChanges2 {
                    return hasChanges1
                }

                // Both have changes or both don't - compare by last commit date
                let date1 = project1.gitStatus?.lastCommitDate ?? project1.lastScanned
                let date2 = project2.gitStatus?.lastCommitDate ?? project2.lastScanned
                return date1 > date2
            }
        }
        
        return result
    }
    
    private var dependencyWarningView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Missing Tools", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(viewModel.missingDependencies, id: \.self) { dep in
                Text(dep.message)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red)
    }
    
    private func sectionHeader(_ title: String, icon: String, count: Int) -> some View {
        HStack {
            Image(systemName: icon)
            Text(title)
            Spacer()
            // Styled count badge
            Text("\(count)")
                .font(.caption)
                .bold()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.secondary.opacity(0.2)))
                .foregroundColor(.secondary)
        }
        .font(.subheadline)
        .foregroundColor(.primary)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No Project Selected")
                    .font(.title2)
                    .fontWeight(.medium)
                Text("Select a project from the sidebar to view details.")
                    .foregroundColor(.secondary)
            }
            
            Button("Add Monitored Path") {
                showingAddPathSheet = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

struct ProjectRowView: View {
    let project: Project

    var body: some View {
        HStack(spacing: 12) {
            // Icon Container
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
                    .frame(width: 36, height: 36)
                
                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(project.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if let status = project.gitStatus, status.hasGitHubRemote {
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    statusText
                    Spacer()
                    // Relative Timestamp
                    if project.isGitRepository {
                        Text(relativeTime(project.gitStatus?.lastCommitDate ?? project.lastScanned))
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var statusText: some View {
        if let status = project.gitStatus {
            HStack(spacing: 6) {
                Text(status.currentBranch)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .prefixIcon("arrow.triangle.branch")
                
                if status.hasUncommittedChanges {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text("Modified")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                if status.pendingPullRequests > 0 {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text("\(status.pendingPullRequests) PRs")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        } else if project.isGitRepository {
            Text("Loading status...")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        } else {
            Text("Local Folder")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var iconName: String {
        guard let status = project.gitStatus else {
            return project.isGitRepository ? "arrow.triangle.2.circlepath" : "folder"
        }
        if status.hasUncommittedChanges { return "pencil" }
        if status.pendingPullRequests > 0 { return "arrow.triangle.pull" }
        return "checkmark"
    }
    
    private var iconColor: Color {
        guard let status = project.gitStatus else {
            return .secondary
        }
        if status.hasUncommittedChanges { return .orange }
        if status.pendingPullRequests > 0 { return .blue }
        return .green
    }
    
    private var backgroundColor: Color {
        iconColor.opacity(0.15)
    }
}

extension View {
    func prefixIcon(_ name: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: name)
            self
        }
    }
}

#Preview {
    ProjectListView()
}
