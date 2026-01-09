import SwiftUI
import AppKit

struct ProjectListView: View {
    @EnvironmentObject private var viewModel: ProjectScannerViewModel
    @StateObject private var settings = SettingsStore()
    @State private var showingAddPathSheet = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var searchText = ""
    @State private var gameModeEnabled = false

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
    
    // Computed property that applies filtering and sorting
    // CRITICAL: This should ONLY process root projects, maintaining hierarchy
    private var processedProjects: [Project] {
        // Start ONLY with root projects to prevent duplication
        let rootProjectsOnly = viewModel.projects.filter { $0.isRoot }

        // Process the hierarchy starting from roots only
        let processed = processProjects(rootProjectsOnly)

        return processed
    }

    var body: some View {
        Group {
            if gameModeEnabled {
                GameModeView(scannerViewModel: viewModel)
            } else {
                traditionalUIView
            }
        }
        .sheet(isPresented: $showingAddPathSheet) {
            AddPathSheet(viewModel: viewModel)
        }
    }
    
    private var traditionalUIView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                // Cache Loading Banner
                if viewModel.isLoadingFromCache {
                    cacheLoadingBanner
                }
                
                // Dependency Warning Banner
                if !viewModel.missingDependencies.isEmpty {
                    dependencyWarningView
                }

                ZStack {
                    // Use List with explicit ID to prevent rendering issues
                    List(selection: $selection) {
                        // Render hierarchy using recursive OutlineGroup
                        ForEach(processedProjects) { rootProject in
                            OutlineGroup(rootProject, children: \.children) { project in
                                NavigationLink(value: SidebarSelection.project(project.id)) {
                                    ProjectRowView(project: project)
                                        .contextMenu {
                                            contextMenuFor(project)
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.sidebar)
                    .searchable(text: $searchText, placement: .sidebar, prompt: "Search projects...")

                    // Filter overlay
                    if viewModel.isApplyingFilter {
                        filteringOverlay
                    }
                }
            }
            .navigationTitle("GitMonitor")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddPathSheet = true }) {
                        Label("Add Path", systemImage: "plus")
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    Toggle(isOn: $gameModeEnabled) {
                        Label("Game Mode", systemImage: "gamecontroller.fill")
                    }
                    .help("Toggle Game Mode (2.5D Office View)")
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
            .onChange(of: filterOption) { _, _ in
                applyFilterWithAnimation()
            }
            .onChange(of: sortOption) { _, _ in
                applyFilterWithAnimation()
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
                DashboardView(projects: processedProjects, isLoading: viewModel.isScanning)
            case .project(let projectId):
                if let project = viewModel.getProject(byId: projectId) {
                    if project.isWorkspace {
                        // Render Workspace Detail
                        WorkspaceDetailView(workspace: project, onNavigateToProject: { subProjectId in
                            if let uuid = UUID(uuidString: subProjectId) {
                                selection = .project(uuid)
                            }
                        })
                        .id(project.id)
                    } else {
                        // Render Project Detail
                        ProjectDetailView(
                            project: project,
                            viewModel: viewModel,
                            onNavigateToProject: { id in
                                if let uuid = UUID(uuidString: id) {
                                    selection = .project(uuid)
                                }
                            },
                            onRefresh: {
                                Task { await viewModel.refreshProjectStatus(project) }
                            },
                            onAppear: {
                                viewModel.markProjectAsReviewed(project)
                            }
                        )
                        .id(project.id)
                    }
                } else {
                    // Project not found
                    Text("Project not found")
                        .font(.title)
                        .foregroundColor(.secondary)
                }
            case nil:
                emptyStateView
            }
        }
    }
    
    // ... existing shortcuts ...

    // ... existing navigateProjects ...

    // ... existing context menus ...

    private var filteredGitRepos: [Project] {
        processProjects(viewModel.gitRepositories.filter { !$0.isWorkspace })
    }
    
    private var filteredNonGit: [Project] {
        // Show Workspaces in "Other Projects" or a new section?
        // Let's put Workspaces in "Other Projects" for now, or create a new section if desired.
        // Actually, Workspaces usually contain Git repos.
        // Let's create a NEW computed property for Workspaces if we want them separate.
        // Or mix them.
        processProjects(viewModel.nonGitProjects)
    }

    private var filteredWorkspaces: [Project] {
        processProjects(viewModel.projects.filter { $0.isWorkspace })
    }
    
    private func processProjects(_ projects: [Project]) -> [Project] {
        // DEBUG: Log input to verify we're only processing roots
        #if DEBUG
        print("🔍 processProjects: Input count = \(projects.count)")
        for (idx, p) in projects.enumerated() {
            print("  [\(idx)] \(p.name) - isRoot:\(p.isRoot) children:\(p.subProjects.count)")
        }
        #endif

        // Recursive function to process a single project (filter/sort children)
        func process(_ project: Project) -> Project? {
            // 1. Process children first
            var processedChildren: [Project] = []
            for child in project.subProjects {
                if let processedChild = process(child) {
                    processedChildren.append(processedChild)
                }
            }
            
            // 2. Sort children
            processedChildren = sortProjects(processedChildren)
            
            // 3. Create a copy with processed children
            var processedProject = project
            processedProject.subProjects = processedChildren
            
            // 4. Filter logic
            // If the project itself matches filter, OR if it has matching children, keep it.
            // If it's a directory/workspace, we usually want to keep it if it contains matches.
            
            let matchesSearch = searchText.isEmpty || project.name.localizedCaseInsensitiveContains(searchText)
            
            var matchesFilter = true
            switch filterOption {
            case .all:
                matchesFilter = true
            case .clean:
                 // Keep if it has no changes (and is a repo) or if it's a container with matching children
                if project.isGitRepository {
                    matchesFilter = !(project.gitStatus?.hasUncommittedChanges ?? false)
                } else {
                    matchesFilter = !processedChildren.isEmpty // Keep container if it has clean children
                }
            case .changes:
                if project.isGitRepository {
                    matchesFilter = project.gitStatus?.hasUncommittedChanges ?? false
                } else {
                    matchesFilter = !processedChildren.isEmpty // Keep container if it has matches
                }
            }
            
            // If search/filter matches, return it.
            // Exception: If it's a workspace/folder that DOESN'T match search itself, but HAS matching children, keep it.
            let hasMatchingChildren = !processedChildren.isEmpty
            
            if (matchesSearch && matchesFilter) || hasMatchingChildren {
                return processedProject
            }
            
            return nil
        }
        
        // 1. Map and compact (filter out nil)
        var result = projects.compactMap { process($0) }

        // 2. Sort top level
        result = sortProjects(result)

        // 3. CRITICAL SAFETY CHECK: Ensure we're only returning root projects
        // This prevents any children from being accidentally promoted to top level
        let rootsOnly = result.filter { $0.isRoot }

        #if DEBUG
        if result.count != rootsOnly.count {
            print("⚠️  WARNING: processProjects filtered out \(result.count - rootsOnly.count) non-root projects!")
            let nonRoots = result.filter { !$0.isRoot }
            for nr in nonRoots {
                print("  - Non-root found: \(nr.name) (isRoot:\(nr.isRoot))")
            }
        }
        print("✅ processProjects: Returning \(rootsOnly.count) root projects")
        #endif

        return rootsOnly
    }
    
    private func sortProjects(_ projects: [Project]) -> [Project] {
        return projects.sorted { p1, p2 in
            // Special handling for Activity sort: ignore type hierarchy
            if sortOption == .activity {
                return sortByActivity(p1, p2: p2)
            }

            // For Name and Recent: respect type hierarchy first
            let priority1 = projectTypePriority(p1)
            let priority2 = projectTypePriority(p2)

            if priority1 != priority2 {
                return priority1 < priority2  // Lower number = higher priority
            }

            // Within same type: Apply selected sort
            switch sortOption {
            case .name:
                return p1.name.localizedCaseInsensitiveCompare(p2.name) == .orderedAscending

            case .recent:
                let date1 = p1.gitStatus?.lastCommitDate ?? p1.lastScanned
                let date2 = p2.gitStatus?.lastCommitDate ?? p2.lastScanned
                return date1 > date2

            case .activity:
                // Already handled above
                return false
            }
        }
    }

    /// Sort projects by activity, ignoring type hierarchy
    /// Priority: Changes > Outgoing > Incoming > Recent > Loading last
    private func sortByActivity(_ p1: Project, p2: Project) -> Bool {
        // Always keep ROOT at top
        if p1.isRoot != p2.isRoot {
            return p1.isRoot
        }

        // Get activity info (considering workspace children)
        let activity1 = getActivityInfo(p1)
        let activity2 = getActivityInfo(p2)

        // 1. Loading projects go to the BOTTOM
        if activity1.isLoading != activity2.isLoading {
            return !activity1.isLoading  // Not loading comes first
        }

        // 2. Projects with uncommitted changes FIRST
        if activity1.hasChanges != activity2.hasChanges {
            return activity1.hasChanges
        }

        // 3. Projects with outgoing commits (push pending)
        if activity1.hasOutgoing != activity2.hasOutgoing {
            return activity1.hasOutgoing
        }

        // 4. Projects with incoming commits (pull needed)
        if activity1.hasIncoming != activity2.hasIncoming {
            return activity1.hasIncoming
        }

        // 5. Most recent activity (DEBUG)
        let result = activity1.lastActivity > activity2.lastActivity

        #if DEBUG
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let date1Str = formatter.localizedString(for: activity1.lastActivity, relativeTo: Date())
        let date2Str = formatter.localizedString(for: activity2.lastActivity, relativeTo: Date())

        print("📅 Compare: \(p1.name) (\(date1Str)) vs \(p2.name) (\(date2Str)) → \(result ? "p1 first" : "p2 first")")
        #endif

        return result
    }

    /// Get activity info for a project (including workspace children)
    private func getActivityInfo(_ project: Project) -> ActivityInfo {
        if project.isWorkspace {
            // For workspaces: aggregate activity from children
            return getWorkspaceActivityInfo(project)
        } else {
            // For repos: use own git status
            return ActivityInfo(
                isLoading: project.isGitRepository && project.gitStatus == nil,
                hasChanges: project.gitStatus?.hasUncommittedChanges ?? false,
                hasOutgoing: (project.gitStatus?.outgoingCommits ?? 0) > 0,
                hasIncoming: (project.gitStatus?.incomingCommits ?? 0) > 0,
                lastActivity: project.gitStatus?.lastCommitDate ?? project.lastScanned
            )
        }
    }

    /// Get aggregated activity info from workspace children
    private func getWorkspaceActivityInfo(_ workspace: Project) -> ActivityInfo {
        var hasChanges = false
        var hasOutgoing = false
        var hasIncoming = false
        var isLoading = false
        var mostRecentActivity: Date?  // Start with nil

        // Recursively check all children
        func checkChildren(_ projects: [Project]) {
            for child in projects {
                if child.isGitRepository {
                    if child.gitStatus == nil {
                        isLoading = true
                    } else {
                        hasChanges = hasChanges || (child.gitStatus?.hasUncommittedChanges ?? false)
                        hasOutgoing = hasOutgoing || ((child.gitStatus?.outgoingCommits ?? 0) > 0)
                        hasIncoming = hasIncoming || ((child.gitStatus?.incomingCommits ?? 0) > 0)

                        if let commitDate = child.gitStatus?.lastCommitDate {
                            if mostRecentActivity == nil || commitDate > mostRecentActivity! {
                                mostRecentActivity = commitDate
                            }
                        }
                    }
                }

                // Recurse into nested workspaces
                if !child.subProjects.isEmpty {
                    checkChildren(child.subProjects)
                }
            }
        }

        checkChildren(workspace.subProjects)

        // If workspace has no git repos or no activity data, use a very old date
        // This pushes empty workspaces to the bottom (after all repos with commits)
        let finalActivity = mostRecentActivity ?? Date.distantPast

        return ActivityInfo(
            isLoading: isLoading,
            hasChanges: hasChanges,
            hasOutgoing: hasOutgoing,
            hasIncoming: hasIncoming,
            lastActivity: finalActivity
        )
    }

    struct ActivityInfo {
        let isLoading: Bool
        let hasChanges: Bool
        let hasOutgoing: Bool
        let hasIncoming: Bool
        let lastActivity: Date
    }
    
    /// Determine project type priority for hierarchical sorting
    /// Lower number = appears first in list
    private func projectTypePriority(_ project: Project) -> Int {
        if project.isRoot {
            return 0  // Monitored paths ALWAYS first
        }
        if project.isWorkspace {
            return 1  // Workspaces second
        }
        if project.isGitRepository {
            return 2  // Git repositories third
        }
        return 3  // Regular folders last
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
    
     // MARK: - Context Menu
    @ViewBuilder
    private func contextMenuFor(_ project: Project) -> some View {
        if project.isGitRepository || project.isWorkspace {
             openInExternalTerminalButton(project)
        }
        openInFinderButton(project)
        Divider()
        copyPathButton(project)
        Divider()
        removeFromListButton(project)
    }

    // MARK: - Context Menu Actions
    
    @ViewBuilder
    private func openInExternalTerminalButton(_ project: Project) -> some View {
        Button {
            openInTerminal(project.path)
        } label: {
            Label("Open in Terminal", systemImage: "terminal")
        }
    }

    @ViewBuilder
    private func openInFinderButton(_ project: Project) -> some View {
        Button {
            NSWorkspace.shared.selectFile(project.path, inFileViewerRootedAtPath: "")
        } label: {
            Label("Show in Finder", systemImage: "folder")
        }
    }

    @ViewBuilder
    private func copyPathButton(_ project: Project) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(project.path, forType: .string)
        } label: {
            Label("Copy Path", systemImage: "doc.on.doc")
        }
    }

    @ViewBuilder
    private func removeFromListButton(_ project: Project) -> some View {
        Button(role: .destructive) {
            viewModel.ignoreProject(project.path)
        } label: {
            Label("Remove from List", systemImage: "trash")
        }
    }

    private func openInTerminal(_ path: String) {
        // Fallback to Terminal.app
        let url = URL(fileURLWithPath: path)
        let configuration = NSWorkspace.OpenConfiguration()
        
        // Try to open with Terminal.app specifically
        if let terminalUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
             NSWorkspace.shared.open([url], withApplicationAt: terminalUrl, configuration: configuration)
        }
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
    
    // MARK: - Loading Indicators
    
    private var cacheLoadingBanner: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            
            Text("Loading from cache...")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
    }
    
    private var filteringOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Applying filter...")
                    .font(.caption)
            }
            .padding(12)
            .background(.regularMaterial)
            .cornerRadius(10)
            .shadow(radius: 5)
            Spacer()
        }
        .transition(.opacity.combined(with: .scale))
    }
    
    private func applyFilterWithAnimation() {
        viewModel.isApplyingFilter = true
        
        // Simulate brief delay for visual feedback
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
            await MainActor.run {
                viewModel.isApplyingFilter = false
            }
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
                        .fontWeight(project.isRoot ? .bold : .medium) // Keep bold for roots
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
        if project.isRoot { return "externaldrive.fill" } // Distinct icon for Monitored Roots
        if project.isWorkspace { return "folder.fill" }   // Distinct icon for Internal Workspaces
        
        guard let status = project.gitStatus else {
            return project.isGitRepository ? "arrow.triangle.2.circlepath" : "doc"
        }
        if status.hasUncommittedChanges { return "pencil" }
        if status.pendingPullRequests > 0 { return "arrow.triangle.pull" }
        return "checkmark"
    }
    
    private var iconColor: Color {
        if project.isRoot { return .indigo } // Distinct color for Monitored Roots
        if project.isWorkspace { return .yellow } // Distinct color for Internal Workspaces
        
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
