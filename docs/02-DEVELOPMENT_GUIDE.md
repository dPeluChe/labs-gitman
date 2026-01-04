# Development Guide - GitMonitor

## 🚀 Getting Started

### Prerequisites

```bash
# Check Swift version
swift --version  # Should be 5.9+

# Check macOS version
sw_vers  # Should be macOS 14.0+

# Optional: Check Xcode
xcodebuild -version  # Should be 26.0+
```

### Installation

```bash
# Clone or navigate to project
cd /Users/peluche/dPeluCheData/PROJECTS/dPeluChe/_code_/labs-gitman

# Verify structure
ls -la
# Should see: Models/, Views/, Services/, etc.
```

---

## 💻 Running the Project

### Option 1: Command Line (SPM)

```bash
# Build
swift build

# Run
swift run GitMonitor

# Or use the script
./run.sh
```

### Option 2: Xcode (RECOMMENDED)

#### Creating Xcode Project from SPM

Since we're using Swift Package Manager (not a traditional Xcode project), here's how to open it:

```bash
# Method 1: Generate Xcode project
cd /Users/peluche/dPeluCheData/PROJECTS/dPeluChe/_code_/labs-gitman
swift package generate-xcodeproj

# This creates GitMonitor.xcodeproj
open GitMonitor.xcodeproj
```

**⚠️ IMPORTANT**: Every time you modify `Package.swift`, regenerate:
```bash
rm -rf GitMonitor.xcodeproj
swift package generate-xcodeproj
open GitMonitor.xcodeproj
```

#### Method 2: Open Package Directly

```bash
# Open SPM package directly in Xcode
open Package.swift
# or
xed .
```

Xcode will open the package and handle dependencies automatically.

---

## 🎯 Xcode Configuration

### Scheme Setup

When you open the package in Xcode:

1. **Select Scheme**: Product → Scheme → GitMonitor
2. **Run Configuration**:
   - Executable: GitMonitor
   - Debug → Run → Custom working directory: Set to project root
3. **Arguments** (if needed):
   - Options → Arguments → Arguments Passed On Launch
   - (Currently no CLI arguments)

### Build Settings

Check these settings:
- **Deployment Target**: macOS 14.0
- **Swift Language Version**: 5.9
- **Swift Compiler - Custom Flags**: `-parse-as-library`

---

## 🔧 Development Workflow

### 1. Make Changes

Edit any `.swift` file in:
- `Models/`
- `Views/`
- `ViewModels/`
- `Services/`

### 2. Build in Xcode

```
⌘ + B  (Build)
```

Or click the Play button ▶️

### 3. Run

```
⌘ + R  (Run)
```

The app window should open.

### 4. Debug

```swift
// Add breakpoints in Xcode by clicking line numbers
// Use LLDB in console:

(lldb) po project.name
(lldb) po viewModel.projects.count
```

---

## 📁 Project Structure Deep Dive

### Models Layer

```swift
// Models/Project.swift
struct Project: Identifiable, Codable {
    let id: UUID
    var path: String
    var name: String
    var isGitRepository: Bool
    var gitStatus: GitStatus?
}

// Usage:
let project = Project(path: "/Users/dev/myapp")
project.statusDescription  // Computed property
```

### Services Layer

```swift
// Services/GitService.swift
actor GitService {
    func getStatus(for project: Project) async throws -> GitStatus {
        // Concurrent operations:
        async let branch = getCurrentBranch(...)
        async let changes = hasUncommittedChanges(...)
        // ...
    }
}

// Usage (from ViewModel):
let status = try await gitService.getStatus(for: project)
```

### ViewModels Layer

```swift
// ViewModels/ProjectScannerViewModel.swift
@MainActor
class ProjectScannerViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var isScanning = false

    func scanAllProjects() async {
        isScanning = true
        // Scan logic...
        isScanning = false
    }
}

// Usage in View:
@StateObject var viewModel = ProjectScannerViewModel()

Button("Scan") {
    Task {
        await viewModel.scanAllProjects()
    }
}
```

### Views Layer

```swift
// Views/ProjectListView.swift
struct ProjectListView: View {
    @StateObject private var viewModel = ProjectScannerViewModel()

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedProject) {
                ForEach(viewModel.projects) { project in
                    ProjectRowView(project: project)
                }
            }
        } detail: {
            // Detail view
            if let project = selectedProject {
                ProjectDetailView(project: project)
            }
        }
    }
}
```

---

## 🔍 Common Tasks

### Adding a New Property to Project

```swift
// 1. Update Model
struct Project {
    var lastChecked: Date  // Add new property
}

// 2. Update ViewModel
viewModel.projects[index].lastChecked = Date()

// 3. Update View (if displaying)
Text(project.lastChecked, style: .relative)
```

### Adding a New AI Analysis Type

```swift
// 1. Add to LLMService
func analyzeTestCoverage(
    projectName: String,
    coverageReport: String
) async throws -> String {
    let prompt = """
    Analyze test coverage for \(projectName)
    Report: \(coverageReport)
    """
    return try await generateResponse(prompt: prompt)
}

// 2. Add to LLMAnalysisViewModel
func analyzeTestCoverage(...) async {
    isAnalyzing = true
    defer { isAnalyzing = false }

    analysisResult = try await llmService.analyzeTestCoverage(...)
}

// 3. Add to LLMAnalysisSheet
case testCoverage = "Test Coverage"
```

### Customizing Git Status Display

```swift
// In ProjectDetailView.swift
private func gitStatusSection(status: GitStatus) -> some View {
    VStack {
        // Add custom visualizations
        if status.hasUncommittedChanges {
            ProgressView(value: changesCount, total: totalFiles)
        }
    }
}
```

---

## 🐛 Debugging Tips

### Console Logging

```swift
import OSLog

// In ViewModels
@MainActor
class MyViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.gitmonitor", category: "MyVM")

    func doSomething() {
        logger.info("Doing something...")
        logger.debug("Debug info: \(someVar)")
        logger.error("Error occurred: \(error)")
    }
}
```

View logs in:
- **Xcode**: Console panel (bottom right)
- **Terminal**: `log stream --predicate 'subsystem == "com.gitmonitor"'`

### Breakpoints

```swift
// In Xcode, click line number to set breakpoint
// When hit, use console:

(lldb) po viewModel.projects
(lldb) po project.gitStatus
(lldb) expr project.name = "Test"
```

### Preview Issues

```swift
// For SwiftUI Previews (not implemented yet)
#Preview {
    ProjectListView()
        .frame(width: 800, height: 600)
}

// Run with: ⌥ + ⌘ + Return (in canvas)
```

---

## 📝 Code Patterns

### Async/Await Pattern

```swift
// ❌ Old way (completion handlers)
func getProjects(completion: @escaping ([Project]) -> Void) {
    // ...
    completion(projects)
}

// ✅ New way (async/await)
func getProjects() async -> [Project] {
    // ...
    return projects
}

// Usage:
Task {
    let projects = await viewModel.getProjects()
}
```

### Actor Isolation

```swift
// ✅ Correct: Access through actor
let status = await gitService.getStatus(for: project)

// ❌ Wrong: Direct access
let status = gitService.getStatus(for: project)  // Compiler error
```

### Published Properties

```swift
// ✅ Use @Published for View binding
@Published var projects: [Project] = []

// ✅ Access from View
Text("\(viewModel.projects.count)")

// ✅ Modifications trigger UI update
viewModel.projects.append(newProject)  // UI refreshes automatically
```

---

## 🧪 Testing (TODO)

When adding tests:

```swift
import XCTest
@testable import GitMonitor

class GitServiceTests: XCTestCase {
    func testGitStatusParsing() async throws {
        let service = GitService()

        let project = Project(path: "/tmp/test")
        let status = try await service.getStatus(for: project)

        XCTAssertNotNil(status)
        XCTAssertEqual(status.currentBranch, "main")
    }
}
```

Run tests: `⌘ + U`

---

## 📦 Building for Distribution

### Release Build

```bash
# Build release version
swift build -c release

# Binary location
.build/release/GitMonitor

# Run
.build/release/GitMonitor
```

### Creating App Bundle

```bash
# Create .app structure
mkdir -p GitMonitor.app/Contents/MacOS
mkdir -p GitMonitor.app/Contents/Resources

# Copy binary
cp .build/release/GitMonitor GitMonitor.app/Contents/MacOS/

# Create Info.plist
cat > GitMonitor.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>GitMonitor</string>
    <key>CFBundleIdentifier</key>
    <string>com.gitmonitor.app</string>
    <key>CFBundleName</key>
    <string>GitMonitor</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
EOF

# Run app
open GitMonitor.app
```

---

## 🔐 Code Signing (Future)

For distribution outside Mac:

```bash
# Request certificate from Apple Developer
# Sign the binary
codesign --force --deep --sign "Developer ID Application: Your Name" GitMonitor.app

# Verify
codesign --verify --verbose GitMonitor.app
```

---

## 📚 Resources

### Documentation

- [Swift Language Guide](https://docs.swift.org/swift-book/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Concurrency in Swift](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

### Tools

- [Xcode](https://developer.apple.com/xcode/)
- [SwiftLint](https://github.com/realm/SwiftLint)
- [SwiftFormat](https://github.com/nicklockwood/SwiftFormat)

### Community

- [Swift Forums](https://forums.swift.org/)
- [r/Sift](https://reddit.com/r/swift)
- [Hacking with Swift](https://www.hackingwithswift.com/)

---

## 🚨 Troubleshooting

### "Command not found: swift"

```bash
# Install Swift
brew install swift

# Or install Xcode from App Store
```

### "Module not found"

```bash
# Clean build
rm -rf .build
swift build
```

### Xcode not opening Package.swift

```bash
# Use xed instead
xed Package.swift

# Or generate Xcode project
swift package generate-xcodeproj
```

### "Cannot find 'git' in PATH"

```bash
# Add to ~/.zshrc
export PATH="/usr/bin:/usr/local/bin:$PATH"

# Reload
source ~/.zshrc
```

---

## ✅ Best Practices

### Swift Style

```swift
// ✅ Good
let projectCount = projects.count

// ❌ Bad
let count = projects.count  // Unclear
```

### Error Handling

```swift
// ✅ Good: Proper error handling
do {
    let status = try await gitService.getStatus(for: project)
} catch {
    logger.error("Failed to get status: \(error)")
}

// ❌ Bad: Silent failure
let status = try? await gitService.getStatus(for: project)
```

### Memory Management

```swift
// ✅ Good: Use value types
struct Project { ... }

// ⚠️ Consider: Reference types when needed
class ConfigStore: ObservableObject { ... }
```

---

*Last updated: 2026-01-04*
