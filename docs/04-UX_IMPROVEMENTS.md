# UI/UX Improvements Roadmap - GitMonitor

## 🎨 Overview

This document outlines comprehensive UI/UX improvements for GitMonitor, organized by priority and implementation complexity.

---

## 🚀 Priority 1: High Impact Improvements

### 1. 🎨 Theme Management System

#### Current State
- No theme support
- Hardcoded colors throughout

#### Proposed Solution

```swift
// Models/Theme.swift
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    @available(macOS 14.0, *)
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
class ThemeManager: ObservableObject {
    @Published var selectedTheme: AppTheme = .system {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme")
        }
    }

    init() {
        if let saved = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: saved) {
            selectedTheme = theme
        }
    }
}
```

**Usage in Views:**
```swift
@StateObject private var themeManager = ThemeManager()

var body: some View {
    ProjectListView()
        .preferredColorScheme(themeManager.selectedTheme.colorScheme)
}
```

**Benefits:**
- Respects system preference by default
- User can override
- Persists across sessions
- Easy to test

---

### 2. ⏱️ Status Indicators with Timestamps

#### Current State
- Simple colored circles
- No temporal context

#### Proposed Solution

```swift
// Models/Project+Extensions.swift
extension Project {
    var lastUpdatedText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastScanned, relativeTo: Date())
    }

    var healthIndicator: some View {
        GroupBox {
            HStack(spacing: 12) {
                // Status Circle with Animation
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                    .shadow(color: statusColor.opacity(0.3), radius: 3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusText)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("Updated \(lastUpdatedText)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Trend Indicator
                if let previousStatus = previousGitStatus {
                    Image(systemName: trendIcon(from: previousStatus, to: gitStatus))
                        .font(.caption)
                        .foregroundColor(trendColor)
                }
            }
        }
    }

    private var statusColor: Color {
        guard let status = gitStatus else { return .gray }

        if status.hasUncommittedChanges {
            return .orange
        } else if status.pendingPullRequests > 0 {
            return .blue
        } else {
            return .green
        }
    }

    private var statusText: String {
        guard let status = gitStatus else { return "No status" }

        if status.hasUncommittedChanges {
            return "Has uncommitted changes"
        } else if status.pendingPullRequests > 0 {
            return "\(status.pendingPullRequests) PR(s) pending"
        } else {
            return "Clean"
        }
    }

    private func trendIcon(from: GitStatus?, to: GitStatus?) -> String {
        guard let from = from, let to = to else { return "minus" }

        let fromCount = from.modifiedFiles.count
        let toCount = to.modifiedFiles.count

        if toCount > fromCount {
            return "arrow.up.circle.fill"
        } else if toCount < fromCount {
            return "arrow.down.circle.fill"
        } else {
            return "equal.circle.fill"
        }
    }

    private var trendColor: Color {
        // Implement based on trend
        return .secondary
    }
}
```

**Visual Result:**
```
┌─────────────────────────────────────────┐
│ 🟢 Clean                                │
│    Updated 2 minutes ago           ↑     │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ 🟡 Has uncommitted changes              │
│    Updated 5 minutes ago           →     │
└─────────────────────────────────────────┘
```

---

### 3. 🎬 Smooth Animations

#### Current State
- No transitions
- Abrupt state changes

#### Proposed Solution

```swift
// Views/AnimatedComponents.swift
import SwiftUI

struct AnimatedContentButton<Content: View>: View {
    let content: Content
    let action: () -> Void

    @State private var isPressed = false

    init(@ViewBuilder content: () -> Content, action: @escaping () -> Void) {
        self.content = content()
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            content
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// Usage:
AnimatedContentButton {
    Label("Scan Projects", systemImage: "arrow.clockwise")
} action: {
    Task {
        await viewModel.scanAllProjects()
    }
}

// List Item Animation
struct AnimatedProjectRow: View {
    let project: Project
    @State private var isVisible = false

    var body: some View {
        ProjectRowView(project: project)
            .opacity(isVisible ? 1 : 0)
            .offset(x: isVisible ? 0 : -20)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
            .onAppear {
                isVisible = true
            }
    }
}

// Scanning Animation
struct ScanningOverlay: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor, lineWidth: 2)
                .opacity(isAnimating ? 0 : 1)

            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor, lineWidth: 2)
                .opacity(isAnimating ? 1 : 0)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}
```

---

### 4. 🚦 Advanced Status Semaphores

#### Current State
- Simple color coding
- No severity levels

#### Proposed Solution

```swift
// Models/StatusSemaphores.swift
import SwiftUI

struct StatusIndicator: View {
    let status: StatusLevel
    let size: CGFloat

    enum StatusLevel {
        case critical
        case warning
        case success
        case info
        case neutral

        var color: Color {
            switch self {
            case .critical: return .red
            case .warning: return .orange
            case .success: return .green
            case .info: return .blue
            case .neutral: return .gray
            }
        }

        var icon: String {
            switch self {
            case .critical: return "exclamationmark.octagon.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .success: return "checkmark.circle.fill"
            case .info: return "info.circle.fill"
            case .neutral: return "circle.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(status.color.opacity(0.2))
                .frame(width: size * 1.5, height: size * 1.5)
                .blur(radius: 3)

            // Inner circle
            Circle()
                .fill(status.color)
                .frame(width: size, height: size)

            // Pulsing animation for critical/warning
            if status == .critical || status == .warning {
                Circle()
                    .stroke(status.color, lineWidth: 2)
                    .frame(width: size, height: size)
                    .scaleEffect(pulseScale)
                    .opacity(2 - pulseScale)
                    .onAppear {
                        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                            pulseScale = 2
                        }
                    }
            }
        }
    }

    @State private var pulseScale: CGFloat = 1.0
}

// Usage:
HStack {
    StatusIndicator(status: .critical, size: 12)
    Text("Critical: \(criticalCount) projects need attention")
}

// Status Badge
struct StatusBadge: View {
    let text: String
    let status: StatusIndicator.StatusLevel

    var body: some View {
        Label(text, systemImage: status.icon)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.15))
            .foregroundColor(status.color)
            .cornerRadius(12)
    }
}

// Usage:
HStack(spacing: 8) {
    StatusBadge(text: "\(viewModel.projectsNeedingAttention.count) Issues", status: .warning)
    StatusBadge(text: "\(viewModel.repositoryCount) Repos", status: .info)
}
```

---

## 🎯 Priority 2: Medium Impact Improvements

### 5. 📊 Dashboard Overview

```swift
// Views/DashboardView.swift
struct DashboardView: View {
    @ObservedObject var viewModel: ProjectScannerViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary Cards
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 16) {
                    SummaryCard(
                        title: "Total Projects",
                        value: "\(viewModel.projectCount)",
                        icon: "folder.fill",
                        color: .blue
                    )

                    SummaryCard(
                        title: "Git Repositories",
                        value: "\(viewModel.repositoryCount)",
                        icon: "git.branch",
                        color: .green
                    )

                    SummaryCard(
                        title: "Need Attention",
                        value: "\(viewModel.projectsNeedingAttention.count)",
                        icon: "exclamationmark.triangle.fill",
                        color: .orange
                    )

                    SummaryCard(
                        title: "Pending PRs",
                        value: "\(totalPendingPRs)",
                        icon: "arrow.triangle.pull",
                        color: .purple
                    )
                }

                // Activity Timeline
                ActivitySection(projects: viewModel.projects)

                // Quick Actions
                QuickActionsSection()
            }
            .padding()
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)

                Spacer()

                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// Activity Timeline
struct ActivitySection: View {
    let projects: [Project]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)

            LazyVStack(spacing: 8) {
                ForEach(projects.sorted(by: { $0.lastScanned > $1.lastScanned }).prefix(5)) { project in
                    ActivityRow(project: project)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct ActivityRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: 12) {
            // Status
            Circle()
                .fill(project.statusColor)
                .frame(width: 8, height: 8)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(project.lastUpdatedText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Badge
            if let status = project.gitStatus, status.hasUncommittedChanges {
                Text("\(status.modifiedFiles.count) changes")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
}
```

---

### 6. 🎭 Interactive Transitions

```swift
// Views/Transitions.swift
import SwiftUI

extension View {
    func slideTransition() -> some View {
        self.transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    func scaleTransition() -> some View {
        self.transition(.scale.combined(with: .opacity))
    }
}

// Usage in ProjectListView:
List(selection: $selectedProject) {
    ForEach(viewModel.projects) { project in
        ProjectRowView(project: project)
            .tag(project)
            .transition(.slideTransition())
    }
}
.animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.projects)
```

---

### 7. 🔍 Search and Filter

```swift
// Views/ProjectFilterView.swift
struct ProjectFilterView: View {
    @ObservedObject var viewModel: ProjectScannerViewModel
    @State private var searchText = ""
    @State private var filterStatus: FilterStatus = .all

    enum FilterStatus {
        case all
        case needsAttention
        case hasPRs
        case clean
    }

    var filteredProjects: [Project] {
        viewModel.projects.filter { project in
            let matchesSearch = searchText.isEmpty ||
                project.name.localizedCaseInsensitiveContains(searchText)

            let matchesFilter: Bool
            switch filterStatus {
            case .all:
                matchesFilter = true
            case .needsAttention:
                matchesFilter = project.gitStatus?.hasUncommittedChanges ?? false
            case .hasPRs:
                matchesFilter = (project.gitStatus?.pendingPullRequests ?? 0) > 0
            case .clean:
                matchesFilter = !(project.gitStatus?.hasUncommittedChanges ?? false)
            }

            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search projects...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)

            // Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterPill(title: "All", isSelected: filterStatus == .all) {
                        filterStatus = .all
                    }
                    FilterPill(title: "Needs Attention", isSelected: filterStatus == .needsAttention) {
                        filterStatus = .needsAttention
                    }
                    FilterPill(title: "Has PRs", isSelected: filterStatus == .hasPRs) {
                        filterStatus = .hasPRs
                    }
                    FilterPill(title: "Clean", isSelected: filterStatus == .clean) {
                        filterStatus = .clean
                    }
                }
            }
        }
        .padding()
    }
}

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.controlBackgroundColor))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}
```

---

## 🎨 Priority 3: Polish & Delight

### 8. ✨ Micro-interactions

```swift
// Hover Effects
struct HoverButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
            .foregroundColor(isHovering ? .accentColor : .primary)
            .cornerRadius(6)
            .animation(.easeInOut(duration: 0.2), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// Success Feedback
struct SuccessToast: View {
    let message: String
    @State private var isVisible = false

    var body: some View {
        if isVisible {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(message)
                    .font(.subheadline)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            .shadow(radius: 4)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        isVisible = false
                    }
                }
            }
        }
    }
}
```

---

### 9. 🎯 Contextual Menus

```swift
// Context Menu for Projects
struct ProjectRowWithContextMenu: View {
    let project: Project

    var body: some View {
        ProjectRowView(project: project)
            .contextMenu {
                Button(action: {
                    NSWorkspace.shared.open(URL(fileURLWithPath: project.path))
                }) {
                    Label("Open in Finder", systemImage: "folder")
                }

                Button(action: {
                    openInTerminal(project.path)
                }) {
                    Label("Open in Terminal", systemImage: "terminal")
                }

                Divider()

                if project.isGitRepository {
                    Button(action: {
                        // Copy branch name
                        if let branch = project.gitStatus?.currentBranch {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(branch, forType: .string)
                        }
                    }) {
                        Label("Copy Branch Name", systemImage: "doc.on.doc")
                    }

                    Button(action: {
                        // View on GitHub
                        if let url = gitHubURL(for: project) {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Label("View on GitHub", systemImage: "link")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    // Remove from monitoring
                } label: {
                    Label("Stop Monitoring", systemImage: "trash")
                }
            }
    }

    func openInTerminal(_ path: String) {
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(path)'"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(nil)
        }
    }

    func gitHubURL(for project: Project) -> URL? {
        // Parse git remote to get GitHub URL
        return URL(string: "https://github.com/user/repo")
    }
}
```

---

## 📱 Implementation Priority

### Phase 1 (Week 1-2)
1. ✅ Theme Management
2. ✅ Status Indicators with Timestamps
3. ✅ Basic Animations

### Phase 2 (Week 3-4)
4. ✅ Dashboard Overview
5. ✅ Search & Filter
6. ✅ Advanced Semaphores

### Phase 3 (Week 5-6)
7. ✅ Interactive Transitions
8. ✅ Micro-interactions
9. ✅ Contextual Menus

---

## 🛠️ Required Dependencies

No external packages needed! All native SwiftUI:
- `SwiftUI` framework
- `Combine` framework (for publishers)
- `Foundation` (for formatters)

---

## 📚 Resources

- [SwiftUI Animations](https://developer.apple.com/documentation/swiftui/animation)
- [SF Symbols](https://developer.apple.com/sf-symbols/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)
- [SwiftUI Lab](https://developer.apple.com/videos/swiftui)

---

*Last updated: 2026-01-04*
