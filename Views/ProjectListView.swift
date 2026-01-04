import SwiftUI
import AppKit

struct ProjectListView: View {
    @StateObject private var viewModel = ProjectScannerViewModel()
    @State private var showingAddPathSheet = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var searchText = ""
    
    // Filtering & Sorting
    @State private var filterOption: FilterOption = .all
    @State private var sortOption: SortOption = .name

    // Selection state handling both Dashboard and Projects
    @State private var selection: SidebarSelection? = .dashboard

    enum SidebarSelection: Hashable {
        case dashboard
        case project(Project)
    }
    
    enum FilterOption {
        case all, clean, changes
    }
    
    enum SortOption {
        case name, recent
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
                                NavigationLink(value: SidebarSelection.project(project)) {
                                    ProjectRowView(project: project)
                                        .contextMenu {
                                            Button {
                                                NSWorkspace.shared.open(URL(fileURLWithPath: project.path))
                                            } label: {
                                                Label("Open in Finder", systemImage: "folder")
                                            }
                                            
                                            Button {
                                                let script = "tell application \"Terminal\" to do script \"cd '\(project.path)'\""
                                                NSAppleScript(source: script)?.executeAndReturnError(nil)
                                            } label: {
                                                Label("Open in Terminal", systemImage: "terminal")
                                            }
                                            
                                            Divider()
                                            
                                            Button {
                                                NSPasteboard.general.clearContents()
                                                NSPasteboard.general.setString(project.path, forType: .string)
                                            } label: {
                                                Label("Copy Path", systemImage: "doc.on.doc")
                                            }
                                        }
                                }
                            }
                        }
                    }

                    if !filteredNonGit.isEmpty {
                        Section(header: sectionHeader("Other Projects", icon: "folder", count: filteredNonGit.count)) {
                            ForEach(filteredNonGit) { project in
                                NavigationLink(value: SidebarSelection.project(project)) {
                                    ProjectRowView(project: project)
                                        .contextMenu {
                                            Button {
                                                NSWorkspace.shared.open(URL(fileURLWithPath: project.path))
                                            } label: {
                                                Label("Open in Finder", systemImage: "folder")
                                            }
                                            
                                            Button {
                                                let script = "tell application \"Terminal\" to do script \"cd '\(project.path)'\""
                                                NSAppleScript(source: script)?.executeAndReturnError(nil)
                                            } label: {
                                                Label("Open in Terminal", systemImage: "terminal")
                                            }
                                            
                                            Divider()
                                            
                                            Button {
                                                NSPasteboard.general.clearContents()
                                                NSPasteboard.general.setString(project.path, forType: .string)
                                            } label: {
                                                Label("Copy Path", systemImage: "doc.on.doc")
                                            }
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
                            Text("Recent Activity").tag(SortOption.recent)
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
                Task { await viewModel.checkDependencies() }
            }
        
        } detail: {
            switch selection {
            case .dashboard:
                DashboardView(projects: viewModel.projects)
            case .project(let project):
                ProjectDetailView(project: project, onRefresh: {
                    Task { await viewModel.refreshProjectStatus(project) }
                })
            case nil:
                emptyStateView
            }
        }
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
        
        // 2. Filter (Only applicable if we have status, but we apply generically)
        switch filterOption {
        case .all:
            break
        case .clean:
            result = result.filter { 
                // Keep if it has no status (loading) or if it has status and is clean
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
            // If scanning never happened, treat as distant past
            result.sort { $0.lastScanned > $1.lastScanned }
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
            Text("\(count)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
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
                        Text(relativeTime(project.lastScanned))
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
