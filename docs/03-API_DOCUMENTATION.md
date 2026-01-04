# API Documentation - GitMonitor

## Overview

GitMonitor doesn't expose a public API, but this document describes the internal APIs used between components.

---

## 📊 Model APIs

### `Project` Struct

```swift
struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var path: String
    var name: String
    var lastScanned: Date
    var isGitRepository: Bool
    var gitStatus: GitStatus?
}
```

**Properties:**
- `id`: Unique identifier
- `path`: Absolute file system path
- `name`: Display name (folder name)
- `lastScanned`: Timestamp of last scan
- `isGitRepository`: Whether .git folder exists
- `gitStatus`: Optional Git status info

**Computed Properties:**
```swift
var statusDescription: String
// Returns human-readable status: "On branch: main • Uncommitted changes • 2 PR(s)"
```

**Methods:**
```swift
init(path: String, name: String? = nil)
// Creates project, defaults name to folder name
```

---

### `GitStatus` Struct

```swift
struct GitStatus: Codable, Hashable {
    var currentBranch: String
    var hasUncommittedChanges: Bool
    var untrackedFiles: [String]
    var modifiedFiles: [String]
    var stagedFiles: [String]
    var pendingPullRequests: Int
    var lastCommitHash: String?
    var lastCommitMessage: String?
}
```

**Properties:**
- `currentBranch`: Git branch name (e.g., "main", "develop")
- `hasUncommittedChanges`: True if any uncommitted changes
- `untrackedFiles`: List of untracked file paths
- `modifiedFiles`: List of modified file paths
- `stagedFiles`: List of staged file paths
- `pendingPullRequests`: Count of open PRs (via GitHub CLI)
- `lastCommitHash`: Git SHA of last commit
- `lastCommitMessage`: Commit message

**Computed Properties:**
```swift
var healthStatus: HealthStatus
// Returns: .clean, .hasPullRequests, or .needsAttention
```

**Enums:**
```swift
enum HealthStatus {
    case clean              // No uncommitted changes
    case hasPullRequests    // Has PRs but no uncommitted changes
    case needsAttention     // Has uncommitted changes
}
```

---

## 🔄 Service APIs

### `GitService` Actor

```swift
actor GitService {
    // MARK: - Detection
    func isGitRepository(at path: String) -> Bool

    // MARK: - Status
    func getStatus(for project: Project) async throws -> GitStatus

    // MARK: - Errors
    enum GitError: Error {
        case notAGitRepository
        case commandFailed(String)
    }
}
```

**Methods:**

#### `isGitRepository(at:)`
Checks if directory contains a `.git` folder.

```swift
let isRepo = await gitService.isGitRepository(at: "/Users/dev/project")
// Returns: true/false
```

#### `getStatus(for:)`
Fetches complete Git status for a project.

```swift
do {
    let status = try await gitService.getStatus(for: project)
    print(status.currentBranch)           // "main"
    print(status.hasUncommittedChanges)    // true
    print(status.modifiedFiles)            // ["src/main.swift"]
} catch {
    print("Error: \(error)")
}
```

**Implementation:**
- Executes multiple Git commands concurrently
- Parses output from:
  - `git rev-parse --abbrev-ref HEAD`
  - `git status --porcelain`
  - `git diff --name-only`
  - `git diff --cached --name-only`
  - `git ls-files --others --exclude-standard`
  - `git log -1 --pretty=%s`
  - `git rev-parse HEAD`
- Optionally calls `gh pr status` for PR count

---

### `LLMService` Singleton

```swift
@MainActor
class LLMService: ObservableObject {
    static let shared = LLMService()

    // Published Properties
    @Published var isGLMAvailable: Bool
    @Published var isOllamaAvailable: Bool
    @Published var glmAPIKey: String
    @Published var ollamaBaseURL: String
    @Published var selectedModel: LLMModel
    @Published var ollamaModel: String

    // MARK: - Analysis Methods
    func analyzeBuildOutput(
        projectName: String,
        buildOutput: String,
        buildStatus: BuildStatus
    ) async throws -> String

    func analyzeCodeQuality(
        projectName: String,
        lintOutput: String,
        language: String
    ) async throws -> String

    func analyzeGitStatus(
        projectName: String,
        branch: String,
        hasChanges: Bool,
        modifiedFiles: [String],
        pendingPRs: Int
    ) async throws -> String

    // MARK: - Configuration
    func saveConfiguration()
}
```

**Enums:**
```swift
enum LLMModel: String, CaseIterable {
    case glm = "GLM-4.7"
    case ollama = "Ollama (Local)"
}

enum BuildStatus: String {
    case success
    case failed
    case warning
}
```

---

#### `analyzeBuildOutput(...)`

Analyzes build errors and provides fix suggestions.

**Parameters:**
- `projectName`: Name of project
- `buildOutput`: Build log output
- `buildStatus`: `.success`, `.failed`, or `.warning`

**Returns:** String with AI analysis

**Example:**
```swift
let result = try await llmService.analyzeBuildOutput(
    projectName: "MyApp",
    buildOutput: "error: value of type 'Int' has no member 'foo'",
    buildStatus: .failed
)
// Returns: "The error indicates you're trying to access a non-existent property..."
```

**Prompt Template:**
```
You are a senior software engineer analyzing build output for project: {projectName}

Build Status: {buildStatus}

Build Output:
{buildOutput}

Please provide:
1. A summary of what went wrong (if applicable)
2. Root cause analysis
3. Specific recommendations to fix the issues
4. Priority level (Critical/High/Medium/Low)

Keep the response concise and actionable.
```

---

#### `analyzeCodeQuality(...)`

Analyzes linting issues and code quality.

**Parameters:**
- `projectName`: Name of project
- `lintOutput`: Linter output
- `language`: Programming language

**Returns:** String with code quality recommendations

**Example:**
```swift
let result = try await llmService.analyzeCodeQuality(
    projectName: "MyApp",
    lintOutput: "warning: 'var' should be 'let'",
    language: "Swift"
)
// Returns: "Most critical issues to address first..."
```

---

#### `analyzeGitStatus(...)`

Provides recommendations for Git workflow.

**Parameters:**
- `projectName`: Name of project
- `branch`: Current branch name
- `hasChanges`: Whether there are uncommitted changes
- `modifiedFiles`: List of modified files
- `pendingPRs`: Count of pending PRs

**Returns:** Git workflow recommendations

**Example:**
```swift
let result = try await llmService.analyzeGitStatus(
    projectName: "MyApp",
    branch: "feature/new-ui",
    hasChanges: true,
    modifiedFiles: ["src/View.swift"],
    pendingPRs: 1
)
// Returns: "Assessment of current branch hygiene..."
```

---

## 🎨 ViewModel APIs

### `ProjectScannerViewModel`

```swift
@MainActor
class ProjectScannerViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var isScanning: Bool = false
    @Published var errorMessage: String?

    // MARK: - Scanning
    func scanAllProjects() async
    func refreshProjectStatus(_ project: Project) async

    // MARK: - Path Management
    func addMonitoredPath(_ path: String)
    func removeMonitoredPath(_ path: String)
    func getMonitoredPaths() -> [String]

    // MARK: - Computed Properties
    var gitRepositories: [Project]
    var nonGitProjects: [Project]
    var projectsNeedingAttention: [Project]
    var projectCount: Int
    var repositoryCount: Int
}
```

**Usage Example:**
```swift
@StateObject var viewModel = ProjectScannerViewModel()

// Scan projects
Task {
    await viewModel.scanAllProjects()
}

// Access results
Text("Found \(viewModel.projectCount) projects")
Text("\(viewModel.repositoryCount) are Git repos")

// Filter
let repos = viewModel.gitRepositories
let needsAttention = viewModel.projectsNeedingAttention
```

---

### `LLMAnalysisViewModel`

```swift
@MainActor
class LLMAnalysisViewModel: ObservableObject {
    @Published var isAnalyzing: Bool = false
    @Published var analysisResult: String? = nil
    @Published var errorMessage: String? = nil

    // MARK: - Analysis
    func analyzeProjectBuild(...) async
    func analyzeCodeQuality(...) async
    func analyzeGitStatus(...) async

    // MARK: - Configuration
    var glmAPIKey: String { get set }
    var ollamaBaseURL: String { get set }
    var selectedModel: LLMModel { get set }
    var ollamaModel: String { get set }

    // MARK: - Service Status
    var isGLMAvailable: Bool
    var isOllamaAvailable: Bool
}
```

**Usage Example:**
```swift
@StateObject var viewModel = LLMAnalysisViewModel()

// Configure
viewModel.glmAPIKey = "sk-..."
viewModel.selectedModel = .glm

// Analyze
await viewModel.analyzeProjectBuild(
    projectName: "MyApp",
    buildOutput: buildLog,
    buildStatus: .failed
)

// Access result
if let result = viewModel.analysisResult {
    Text(result)
}
```

---

## 🔌 External APIs

### GLM-4.7 API

**Endpoint:** `https://open.bigmodel.cn/api/paas/v4/chat/completions`

**Method:** POST

**Headers:**
```http
Authorization: Bearer {API_KEY}
Content-Type: application/json
```

**Request Body:**
```json
{
  "model": "glm-4",
  "messages": [
    {"role": "user", "content": "{prompt}"}
  ],
  "temperature": 0.7,
  "max_tokens": 2000
}
```

**Response:**
```json
{
  "choices": [
    {
      "message": {
        "content": "{AI response}"
      }
    }
  ]
}
```

---

### Ollama API

**Endpoint:** `{OLLAMA_BASE_URL}/api/generate`

**Default Base URL:** `http://localhost:11434`

**Method:** POST

**Headers:**
```http
Content-Type: application/json
```

**Request Body:**
```json
{
  "model": "codellama",
  "prompt": "{prompt}",
  "stream": false,
  "options": {
    "temperature": 0.7,
    "num_predict": 2000
  }
}
```

**Response:**
```json
{
  "response": "{AI response}",
  "model": "codellama",
  "created_at": "2026-01-04T12:00:00Z"
}
```

**Check Availability:**
```bash
curl http://localhost:11434/api/tags
```

---

## 🔧 Process Execution APIs

### `ProcessExecutor` Actor

Internal helper for executing shell commands.

```swift
actor ProcessExecutor {
    func execute(
        command: String,
        arguments: [String],
        directory: String?
    ) async throws -> String
}
```

**Usage (internal):**
```swift
let executor = ProcessExecutor()

let output = try await executor.execute(
    command: "/usr/bin/git",
    arguments: ["status", "--porcelain"],
    directory: "/Users/dev/project"
)
// Returns: "M src/main.swift\nA src/new.swift"
```

**Process:**
1. Creates `Process` instance
2. Sets executable URL and arguments
3. Sets current working directory
4. Creates pipe for stdout/stderr
5. Runs process synchronously
6. Reads output
7. Checks termination status
8. Returns output or throws error

---

## 📝 UserDefaults Keys

### Persistence Keys

```swift
private let pathsKey = "monitoredPaths"
private let glmAPIKeyKey = "glm_api_key"
private let ollamaBaseURLKey = "ollama_base_url"
private let selectedModelKey = "selected_model"
private let ollamaModelKey = "ollama_model"
```

**Storage:**
```swift
UserDefaults.standard.set(paths, forKey: pathsKey)
let paths = UserDefaults.standard.stringArray(forKey: pathsKey)
```

---

## 🎯 Error Handling

### Error Types

```swift
// GitService errors
enum GitError: Error {
    case notAGitRepository
    case commandFailed(String)
}

// LLMService errors
enum LLMError: Error, LocalizedError {
    case noAPIKey
    case serviceUnavailable
    case invalidResponse
    case networkError(Error)
}
```

**Error Handling Pattern:**
```swift
do {
    let status = try await gitService.getStatus(for: project)
} catch GitError.notAGitRepository {
    // Handle specifically
} catch {
    // Handle generic error
    logger.error("Failed: \(error.localizedDescription)")
}
```

---

## 🔄 Async/Await Patterns

### Concurrent Operations

```swift
// Execute multiple operations concurrently
async let branch = getCurrentBranch(...)
async let changes = hasUncommittedChanges(...)
async let files = getModifiedFiles(...)

// Wait for all
let (branch, hasChanges, files) = try await (branch, changes, files)
```

### Actor Isolation

```swift
// Access actor methods
let status = await gitService.getStatus(for: project)

// From @MainActor context
@MainActor
class ViewModel {
    func update() {
        Task {
            let status = await gitService.getStatus(...)
            // Back on main actor
            self.projects[0].gitStatus = status
        }
    }
}
```

---

## 📊 Data Flow Diagrams

### Scan Flow

```
User Action → ViewModel.scanAllProjects()
    ↓
ConfigStore.scanMonitoredPaths()
    ↓
FileSystem scan for .git folders
    ↓
Create Project objects
    ↓
For each project:
    GitService.getStatus() → GitStatus
    ↓
ViewModel.projects updated
    ↓
SwiftUI auto-refreshes
```

### AI Analysis Flow

```
User selects analysis type
    ↓
ViewModel.analyzeBuildOutput()
    ↓
LLMService.generateResponse(prompt)
    ↓
Check selectedModel
    ├─ .glm → callGLMAPI()
    └─ .ollama → callOllamaAPI()
    ↓
HTTP request
    ↓
Parse JSON response
    ↓
Return result string
    ↓
ViewModel.analysisResult updated
    ↓
UI displays result
```

---

## 🔐 Security Considerations

### API Key Storage

**Current:** UserDefaults (NOT secure for production)

```swift
UserDefaults.standard.set(apiKey, forKey: "glm_api_key")
```

**Recommended:** Keychain (future implementation)

```swift
import Security

let query = [
    kSecClass: kSecClassGenericPassword,
    kSecAttrAccount: "glm_api_key",
    kSecValueData: apiKey.data(using: .utf8)!
] as CFDictionary

SecItemAdd(query, nil)
```

### Network Security

- GLM-4.7: HTTPS only
- Ollama: Localhost only (no network exposure)
- No telemetry or analytics
- All code analysis stays local (with Ollama)

---

## 📚 SwiftDocC Format (Future)

For generating official documentation:

```swift
/// Analyzes build output using AI
///
/// - Parameters:
///   - projectName: The name of the project
///   - buildOutput: Build log output to analyze
///   - buildStatus: Status of the build
/// - Returns: AI-generated analysis
/// - Throws: `LLMError` if analysis fails
///
/// # Example
/// ```swift
/// let result = try await llmService.analyzeBuildOutput(
///     projectName: "MyApp",
///     buildOutput: "error: ...",
///     buildStatus: .failed
/// )
/// ```
func analyzeBuildOutput(
    projectName: String,
    buildOutput: String,
    buildStatus: BuildStatus
) async throws -> String
```

---

*Last updated: 2026-01-04*
