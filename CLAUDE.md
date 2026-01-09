# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🎯 Project Overview

**GitMonitor** is a native macOS application (Swift 5.9+ / SwiftUI) for monitoring multiple Git repositories simultaneously. It features AI-powered analysis (GLM-4.7/Ollama), integrated terminal, visual commit timeline, and comprehensive branch management. The app uses modern Swift concurrency (async/await, actors) and follows MVVM architecture.

## 🛠️ Essential Commands

### Build & Run
```bash
# Quick build and run
./run.sh

# Manual build
swift build

# Run the app
swift run GitMonitor

# Release build
swift build -c release
```

### Testing
```bash
# Run all tests
swift test

# Run specific test
swift test --filter GitServiceTests

# Run with verbose output
swift test --verbose
```

### Xcode Integration
```bash
# Open package directly (recommended)
open Package.swift
# or
xed .

# Generate Xcode project (legacy)
swift package generate-xcodeproj
open GitMonitor.xcodeproj
```

### Cleanup
```bash
# Clean build artifacts
rm -rf .build

# Clean and rebuild
rm -rf .build && swift build
```

## 🏗️ Architecture Overview

### MVVM Pattern with Swift Concurrency

The app uses **MVVM** with modern Swift concurrency primitives:

```
Views (SwiftUI)
    ↓ bindings (@Published)
ViewModels (@MainActor)
    ↓ async calls
Services (actors)
    ↓ Process execution
Git CLI / LLM APIs
```

### Key Architectural Decisions

1. **Services use `actor` for thread safety**
   - `GitService`, `CacheManager`, `ChangeDetector` are actors
   - All Git operations are isolated and thread-safe by compiler
   - Prevents data races without manual locks

2. **ViewModels use `@MainActor` for UI updates**
   - `ProjectScannerViewModel`, `LLMAnalysisViewModel` are @MainActor classes
   - All `@Published` property updates happen on main thread
   - No manual `DispatchQueue.main.async` needed

3. **Models are value types (structs)**
   - `Project`, `GitStatus`, `GitCommit`, `GitBranch` are all structs
   - Immutable by default, thread-safe by design
   - Codable for persistence

4. **Hierarchical Project Structure**
   - Projects can contain sub-projects (workspaces)
   - Root projects (`isRoot=true`) represent monitored paths
   - Workspaces (`isWorkspace=true`) contain multiple git repos
   - Git repos (`isGitRepository=true`) are leaf nodes

### Performance Optimizations

The app implements a **two-tier status fetching strategy**:

1. **Full Status (`getStatus`)**: ~10 git commands
   - Used when: User opens project detail, explicit refresh
   - Fetches: All branches, commit counts, PRs, complete file lists
   - Execution time: ~200-500ms per project

2. **Light Status (`getLightStatus`)**: ~3 git commands
   - Used when: App startup, background refresh, cache loading
   - Fetches: Current branch, basic changes, last commit
   - Reuses cached data for non-critical info
   - Execution time: ~50-100ms per project
   - **When to use**: Always prefer light status for background operations

3. **Change Detection (`ChangeDetector`)**:
   - Filesystem-based change detection (checks `.git/index` timestamps)
   - Avoids running git commands entirely
   - Used to filter which projects need refreshing
   - **Pattern**: `filterChangedProjects()` → only refresh those → `getLightStatus()`

4. **Caching (`CacheManager`)**:
   - Saves projects to `~/Library/Application Support/GitMan/projects.cache`
   - Validates cache based on: age (1 hour), path changes
   - Throttles saves (min 30s between writes)
   - Enables instant app startup with cached data

### Concurrent Processing

Projects are processed in **dynamic batches** based on CPU cores:
```swift
// From ProjectScannerViewModel
private var optimalBatchSize: Int {
    max(5, ProcessInfo.processInfo.activeProcessorCount)
}

// Usage pattern:
for batch in projects.chunked(into: optimalBatchSize) {
    await withTaskGroup(of: Void.self) { group in
        for project in batch {
            group.addTask {
                await self.refreshProjectStatus(project)
            }
        }
    }
}
```

### Project Hierarchy Management

**Critical**: When updating projects, preserve IDs to prevent UI flashing:

```swift
// ✅ CORRECT: Merge pattern (see ProjectScannerViewModel.scanAllProjects)
if let existing = projects.first(where: { $0.path == newProject.path }) {
    var p = newProject
    p.id = existing.id  // Preserve ID!
    p.gitStatus = existing.gitStatus
    p.lastReviewed = existing.lastReviewed
    // ... then replace
}

// ❌ WRONG: Creating new projects with new IDs causes list flashing
projects = discoveredProjects  // Don't do this
```

## 📁 Directory Structure

```
labs-gitman/
├── Models/                       # Data structures (value types)
│   ├── Project.swift             # Core project model with hierarchy
│   ├── ConfigStore.swift         # Path scanning & discovery logic
│   ├── SettingsStore.swift       # App settings persistence
│   └── Theme.swift               # UI theming
│
├── ViewModels/                   # Business logic (@MainActor)
│   ├── ProjectScannerViewModel.swift  # Main orchestrator
│   └── LLMAnalysisViewModel.swift     # AI analysis coordinator
│
├── Views/                        # SwiftUI views
│   ├── ProjectListView.swift    # Main split view with sidebar
│   ├── ProjectDetailView.swift  # Tabs: Overview/Files/Terminal/Branches
│   ├── WorkspaceDetailView.swift # Workspace-specific detail view
│   ├── DashboardView.swift       # Statistics dashboard
│   ├── MenuBarContentView.swift # Menu bar dropdown UI
│   ├── AddPathSheet.swift        # Path selection sheet
│   ├── LLMAnalysisSheet.swift   # AI analysis modal
│   ├── SettingsView.swift        # App preferences
│   └── Components/
│       ├── TerminalView.swift    # Integrated terminal
│       ├── FileExplorerView.swift # File browser
│       └── CodeViewer.swift      # Code syntax viewer
│
├── Services/                     # Backend logic (actors)
│   ├── GitService.swift          # Git CLI integration (actor)
│   ├── LLMService.swift          # AI API integration (@MainActor singleton)
│   ├── CacheManager.swift        # Disk caching (actor)
│   └── ChangeDetector.swift      # Filesystem change detection (actor)
│
├── Tests/                        # Unit tests
│   └── GitMonitorTests/
│       └── GitServiceTests.swift # Git operations tests
│
├── Resources/                    # Assets
│   └── Asset.xcassets/
│
├── docs/                         # Documentation
│   ├── 01-PROJECT_OVERVIEW.md
│   ├── 02-DEVELOPMENT_GUIDE.md
│   └── 03-API_DOCUMENTATION.md
│
├── GitMonitorApp.swift           # App entry point (@main)
├── Package.swift                 # SPM configuration
├── run.sh                        # Quick build & run script
└── README.md                     # User documentation
```

## 🔑 Key Implementation Patterns

### 1. Actor-Based Git Operations

All Git operations use the `GitService` actor for thread safety:

```swift
actor GitService {
    // All methods are async and actor-isolated
    func getStatus(for project: Project) async throws -> GitStatus
    func getLightStatus(for project: Project, cachedStatus: GitStatus?) async throws -> GitStatus
    func switchBranch(path: String, branchName: String) async throws
    func getCommitHistory(path: String, limit: Int) async throws -> [GitCommit]
}

// Usage from ViewModel:
let gitService = GitService()
let status = try await gitService.getStatus(for: project)
```

### 2. Parallel Git Command Execution

For each project, multiple git commands run concurrently:

```swift
// Inside GitService.getStatus():
async let currentBranch = getCurrentBranch(path: path, gitPath: gitPath)
async let hasChanges = hasUncommittedChanges(path: path, gitPath: gitPath)
async let untracked = getUntrackedFiles(path: path, gitPath: gitPath)
async let modified = getModifiedFiles(path: path, gitPath: gitPath)

// Wait for all to complete:
let (branch, changes, untrackedFiles, modifiedFiles) = try await (
    currentBranch, hasChanges, untracked, modified
)
```

### 3. Hierarchical Project Updates

When updating a project in the tree, use recursive updates:

```swift
// Pattern from ProjectScannerViewModel
private func updateProjectRecursively(_ project: Project, targetId: UUID, status: GitStatus) -> Project? {
    if project.id == targetId {
        var p = project
        p.gitStatus = status
        p.lastScanned = Date()
        return p
    }

    // Recurse into sub-projects
    var updatedSubProjects = project.subProjects
    for (index, sub) in project.subProjects.enumerated() {
        if let updated = updateProjectRecursively(sub, targetId: targetId, status: status) {
            updatedSubProjects[index] = updated
            break
        }
    }

    var p = project
    p.subProjects = updatedSubProjects
    return p
}
```

### 4. Smart Caching Strategy

Cache loading happens at app startup with background refresh:

```swift
// Pattern from ProjectScannerViewModel.init()
init() {
    Task {
        await loadFromCache()  // Instant UI with cached data
    }
}

func loadFromCache() async {
    if let cache = try? await cacheManager.loadCache() {
        // Validate cache
        if cacheManager.isCacheValid(cache) && cacheManager.pathsMatch(cache, currentPaths) {
            projects = cache.projects  // Show immediately

            // Background: Refresh changed projects only
            Task {
                await lightRefreshChangedProjects()
            }
        }
    }
}
```

### 5. Process Execution Pattern

All shell commands use `ProcessExecutor` actor:

```swift
// Pattern used throughout GitService
let process = Process()
process.executableURL = URL(fileURLWithPath: command)
process.arguments = arguments
process.currentDirectoryURL = URL(fileURLWithPath: directory)

// Always include PATH for homebrew binaries
var env = ProcessInfo.processInfo.environment
env["PATH"] = (env["PATH"] ?? "") + ":/usr/local/bin:/opt/homebrew/bin"
process.environment = env

try process.run()
process.waitUntilExit()
```

## 🧪 Testing Guidelines

### Writing Tests

1. **Use async/await for actor calls**:
   ```swift
   func testGitStatus() async throws {
       let service = GitService()
       let status = try await service.getStatus(for: project)
       XCTAssertNotNil(status)
   }
   ```

2. **Test with real paths** (current approach):
   - Tests use actual project path: `/Users/peluche/.../labs-gitman`
   - Ensures real-world Git integration works
   - Trade-off: Tests depend on environment

3. **Performance tests use measure blocks**:
   ```swift
   func testPerformance_GetCommitHistory() async throws {
       measure {
           let expectation = expectation(description: "...")
           Task {
               try? await gitService.getCommitHistory(...)
               expectation.fulfill()
           }
           wait(for: [expectation], timeout: 5.0)
       }
   }
   ```

## 🎨 UI Development

### SwiftUI View Structure

Main window uses `NavigationSplitView` for sidebar/detail layout:

```swift
NavigationSplitView {
    // Sidebar: Project list
    ProjectListView()
} detail: {
    // Detail: Project details with tabs
    ProjectDetailView(project: selectedProject)
}
```

### Project Detail Tabs

`ProjectDetailView` uses `Picker` + `switch` for tab navigation:

```swift
Picker("View", selection: $selectedTab) {
    Text("Overview").tag(Tab.overview)
    Text("Files").tag(Tab.files)
    Text("Terminal").tag(Tab.terminal)
    Text("Branches & History").tag(Tab.branches)
}
.pickerStyle(.segmented)

switch selectedTab {
case .overview: OverviewView()
case .files: FileExplorerView()
case .terminal: TerminalView()
case .branches: BranchesView()
}
```

### Keyboard Shortcuts

The app has comprehensive keyboard shortcuts (see `ProjectListView`):
- `⌘R`: Refresh/Scan
- `⌘N`: Add new path
- `⌘K`: Toggle sidebar
- `⌘1-4`: Switch detail tabs
- `ESC`: Close modals/sheets

### Known SwiftUI Issues

**AttributeGraph Cycles** (non-critical):
- Occasional console warnings when switching tabs in `ProjectDetailView`
- Caused by: `Picker` + `switch` pattern with async child views
- Impact: None - app works correctly
- Mitigations applied:
  - Memoization in `.task` blocks (`hasLoadedCommits` flag)
  - Removed explicit animations (SwiftUI handles implicitly)
  - Kept `.id(project.id)` for proper view identity

## 🔧 Common Development Tasks

### Adding a New Git Command

1. Add method to `GitService` (actor):
   ```swift
   actor GitService {
       func yourNewCommand(path: String) async throws -> String {
           let gitPath = await resolveCommandPath("git")
           let output = try await processExecutor.execute(
               command: gitPath,
               arguments: ["your", "git", "args"],
               directory: path
           )
           return output.trimmingCharacters(in: .whitespacesAndNewlines)
       }
   }
   ```

2. Call from ViewModel:
   ```swift
   @MainActor
   class ProjectScannerViewModel {
       func useNewCommand() async {
           let result = try? await gitService.yourNewCommand(path: project.path)
           // Update published properties
       }
   }
   ```

### Adding a New View Tab

1. Add tab enum case to `ProjectDetailView`:
   ```swift
   enum Tab {
       case overview, files, terminal, branches, yourNewTab
   }
   ```

2. Add picker option and switch case:
   ```swift
   Picker("View", selection: $selectedTab) {
       // ... existing tabs
       Text("Your Tab").tag(Tab.yourNewTab)
   }

   switch selectedTab {
       // ... existing cases
       case .yourNewTab: YourNewTabView(project: project)
   }
   ```

3. Implement view with project binding:
   ```swift
   struct YourNewTabView: View {
       let project: Project

       var body: some View {
           // Your UI here
       }
   }
   ```

### Optimizing for Large Repo Counts

When adding features that scale with repo count:

1. **Use light status by default**: `getLightStatus()` instead of `getStatus()`
2. **Batch process**: Use `chunked(into: optimalBatchSize)` pattern
3. **Filter changes first**: Use `ChangeDetector.filterChangedProjects()` before refreshing
4. **Cache aggressively**: Save to `CacheManager` after expensive operations
5. **Consider lazy loading**: Don't fetch all data upfront

Example:
```swift
// ✅ GOOD: Filter changed, then light refresh
let changed = await changeDetector.filterChangedProjects(allProjects)
for project in changed {
    await lightRefreshProjectStatus(project)
}

// ❌ BAD: Full refresh all projects
for project in allProjects {
    await fullRefreshProjectStatus(project)  // Too slow!
}
```

## 🔍 Debugging Tips

### Enable Logging

The app uses `OSLog` for structured logging:

```swift
import OSLog

let logger = Logger(subsystem: "com.gitmonitor", category: "YourCategory")
logger.debug("Debug message: \(variable)")
logger.info("Info message")
logger.error("Error: \(error)")
logger.warning("Warning message")
```

View logs in **Console.app** or terminal:
```bash
# Run and view logs
swift run GitMonitor 2>&1 | grep "com.gitmonitor"

# Filter by category
log stream --predicate 'subsystem == "com.gitmonitor"' --level debug
```

### Common Issues

1. **"Command not found" for git/gh**:
   - Check PATH includes: `/usr/local/bin`, `/opt/homebrew/bin`
   - `ProcessExecutor` adds these by default
   - Verify with: `which git`, `which gh`

2. **AttributeGraph cycle warnings**:
   - Non-critical, ignore unless causing actual UI bugs
   - Already optimized (see "Known SwiftUI Issues")

3. **Cache not loading**:
   - Check: `~/Library/Application Support/GitMan/projects.cache`
   - Validate: Cache age (<1 hour), paths match
   - Clear: `rm -rf ~/Library/Application\ Support/GitMan/`

4. **Slow scanning with many repos**:
   - Use `ChangeDetector` to filter changed projects first
   - Prefer `getLightStatus()` over `getStatus()` for bulk operations
   - Check `optimalBatchSize` - should match CPU cores

## 🚀 Dependencies

### Required
- **macOS 14.0+**: Required for modern SwiftUI features
- **Swift 5.9+**: For actor isolation and async/await
- **Git**: System git (Xcode Command Line Tools)

### Optional
- **GitHub CLI (`gh`)**: For PR status tracking
  ```bash
  brew install gh
  gh auth login
  ```

### AI Backends (Optional)
- **Ollama** (local, recommended):
  ```bash
  brew install ollama
  ollama serve
  ollama pull codellama  # or mistral, deepseek-coder
  ```

- **GLM-4.7** (cloud):
  - Get API key: https://open.bigmodel.cn/
  - Configure in Settings > AI Configuration

## 📝 Code Style Guidelines

1. **Use async/await, not callbacks**:
   ```swift
   // ✅ Good
   let status = try await gitService.getStatus(for: project)

   // ❌ Bad
   gitService.getStatus(for: project) { status in ... }
   ```

2. **Use actors for shared mutable state**:
   ```swift
   // ✅ Good
   actor CacheManager { /* thread-safe by design */ }

   // ❌ Bad
   class CacheManager { /* needs manual locks */ }
   ```

3. **Use @MainActor for ViewModels**:
   ```swift
   // ✅ Good
   @MainActor
   class ViewModel: ObservableObject {
       @Published var data: [Item] = []
   }
   ```

4. **Preserve project IDs when updating**:
   ```swift
   // ✅ Good
   var updated = project
   updated.gitStatus = newStatus

   // ❌ Bad (creates new ID, causes UI flash)
   let updated = Project(path: project.path, ...)
   ```

5. **Use MARK comments for organization**:
   ```swift
   // MARK: - Git Operations
   // MARK: - Cache Management
   // MARK: - Helper Methods
   ```

6. **Document public APIs**:
   ```swift
   /// Get full git status for a project
   /// Executes all git commands for complete information (~10 commands)
   /// Use this when: user opens project detail, explicit refresh
   func getStatus(for project: Project) async throws -> GitStatus
   ```

## 🎯 Project-Specific Conventions

1. **File naming**: Match class/struct name (e.g., `GitService.swift` contains `actor GitService`)
2. **SwiftUI previews**: Add for all views during development (optional in production)
3. **Error handling**: Use `Result` or throw errors, avoid optionals for error states
4. **Persistence**: Use `UserDefaults` for settings, `CacheManager` for project data
5. **Concurrency**: Always mark Git/network operations as `async`, run them in actors

## 📚 Related Documentation

- **README.md**: User-facing documentation with features and screenshots
- **docs/01-PROJECT_OVERVIEW.md**: Architecture diagrams and design decisions
- **docs/02-DEVELOPMENT_GUIDE.md**: Development workflows and debugging
- **docs/03-API_DOCUMENTATION.md**: Internal API documentation
