# GitMonitor 🚀

A native macOS application for monitoring multiple Git projects with AI-powered analysis.

[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-macOS%2014%2B-blue.svg)](https://developer.apple.com/xcode/swift-ui/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## ✨ Features

- 🎯 **Multi-Project Monitoring** - Scan and monitor multiple project directories simultaneously
- 🌿 **Git Status Integration** - View branch, commits, and pull request status at a glance
- 🔗 **GitHub CLI Integration** - Check pending PRs via `gh` command
- 🤖 **AI-Powered Analysis** - Analyze build output, code quality, and git status with LLMs
- 🔑 **BYOK Support** - Bring Your Own Key (GLM-4.7) or use local Ollama
- 🍎 **Native macOS** - Built with SwiftUI for optimal performance and native look & feel
- ⌨️ **Keyboard Shortcuts** - Comprehensive shortcuts for power users (⌘1-4, ⌘R, ESC, etc.)
- 📊 **MenuBar Integration** - Quick access from menu bar with project summary
- 🔄 **Branch Management** - Switch branches directly from the UI
- 🖥️ **Integrated Terminal** - Built-in terminal with external app integration
- ⚡ **Commit Timeline** - Visual history of commits with detailed information
- 🧪 **Unit Tests** - Comprehensive test coverage for core functionality

## 🎯 Quick Start

### Prerequisites

- macOS 14.0+
- Swift 5.9+ or Xcode 26+
- Git (installed by default on macOS)
- GitHub CLI `gh` (optional, for PR status)

### Installation & Running

```bash
# Clone or navigate to project
cd /Users/peluche/dPeluCheData/PROJECTS/dPeluChe/_code_/labs-gitman

# Build and run
./run.sh

# Or manually
swift build
swift run GitMonitor
```

### Opening in Xcode

```bash
# Method 1: Generate Xcode project
swift package generate-xcodeproj
open GitMonitor.xcodeproj

# Method 2: Open package directly (Recommended)
open Package.swift
# or
xed .
```

Once in Xcode:
1. Select scheme: **GitMonitor**
2. Press **⌘ + R** to run

## 📸 Screenshots

*(Add screenshots here when you run the app)*

## 🎓 Usage Guide

### 1. Add Project Paths

Click the **+ Add Path** button and:
- Choose from suggested paths (~/code, ~/Projects, etc.)
- Or browse to custom location

### 2. Scan Projects

Click **Scan** button to:
- Discover all Git repositories in monitored paths
- Fetch Git status for each repo
- Display branch, changes, and PRs

### 3. View Project Details

Select any project to see:
- **Overview**: Git statistics, changes summary, commit info
- **Files**: Built-in file explorer for the project
- **Terminal**: Integrated terminal with:
  - Auto-focused command input
  - Quick actions (Git Status, Log, List Files, Build)
  - Open in external terminal (uses configured app: Ghostty, iTerm2, etc.)
- **Branches & History**: 
  - View all branches with status indicators
  - Switch branches via context menu
  - Visual commit timeline with author, date, and message
- **Actions**: Open in Finder, AI analysis, external terminal

### 4. AI Analysis

Click **Analyze with AI** and choose:

- **Git Status**: Get workflow recommendations
- **Build Output**: Paste build errors for AI analysis
- **Code Quality**: Review linting issues

## 🧠 AI Configuration

### Option 1: GLM-4.7 (Cloud)

1. Get API key from https://open.bigmodel.cn/
2. Open **Settings > AI Configuration**
3. Select **GLM-4.7**
4. Enter API key
5. Start analyzing!

**Pros:** More powerful models
**Cons:** Requires internet, API costs

### Option 2: Ollama (Local - Recommended)

```bash
# Install Ollama
brew install ollama

# Start service
ollama serve

# Pull a code model
ollama pull codellama
# or
ollama pull mistral
# or
ollama pull deepseek-coder
```

Then in app:
1. Open **Settings > AI Configuration**
2. Select **Ollama (Local)**
3. Default URL: `http://localhost:11434`
4. Model name: `codellama`

**Pros:** 100% offline, privacy-focused, free
**Cons:** Requires local computation

## 📁 Project Structure

```
labs-gitman/
├── Models/                    # Data models
│   ├── Project.swift
│   └── ConfigStore.swift
├── ViewModels/                # Business logic
│   ├── ProjectScannerViewModel.swift
│   └── LLMAnalysisViewModel.swift
├── Views/                     # SwiftUI views
│   ├── ProjectListView.swift
│   ├── ProjectDetailView.swift
│   ├── AddPathSheet.swift
│   ├── LLMAnalysisSheet.swift
│   └── SettingsView.swift
├── Services/                  # Core services
│   ├── GitService.swift
│   └── LLMService.swift
├── Resources/                 # Assets
│   └── Asset.xcassets/
├── docs/                      # Documentation
│   ├── 01-PROJECT_OVERVIEW.md
│   ├── 02-DEVELOPMENT_GUIDE.md
│   └── 03-API_DOCUMENTATION.md
├── GitMonitorApp.swift        # App entry point
├── Package.swift              # SPM configuration
└── run.sh                     # Quick run script
```

## 🛠️ Development

### Building

```bash
# Debug build
swift build

# Release build
swift build -c release
```

### Running

```bash
# Use script
./run.sh

# Or directly
swift run GitMonitor
```

### Testing (TODO)

```bash
# Unit tests coming soon
swift test
```

## 📚 Documentation

- **[Project Overview](docs/01-PROJECT_OVERVIEW.md)** - Architecture, design decisions, and concepts
- **[Development Guide](docs/02-DEVELOPMENT_GUIDE.md)** - Setup, debugging, and workflows
- **[API Documentation](docs/03-API_DOCUMENTATION.md)** - Internal APIs and interfaces

## 🎯 Technology Stack

| Component | Technology |
|-----------|-----------|
| **Language** | Swift 5.9+ |
| **Framework** | SwiftUI (macOS 14+) |
| **Pattern** | MVVM |
| **Concurrency** | async/await, actors |
| **Package Manager** | Swift Package Manager |
| **AI Integration** | GLM-4.7 API, Ollama |
| **Git Operations** | Native git CLI, GitHub CLI |

### Why Swift + SwiftUI?

After extensive research comparing Swift/SwiftUI, Tauri (Rust), and Electron:

✅ **Chosen: Swift + SwiftUI**
- Native performance (<100ms startup)
- Small bundle size (~15MB vs 100MB+ Electron)
- Perfect macOS integration
- Rich AI ecosystem (Ollama, MLX, CoreML)
- Excellent tooling (Xcode)
- Type-safe and modern

❌ **Rejected: Tauri**
- CSS performance issues on macOS
- Webview overhead

❌ **Rejected: Electron**
- 100MB+ bundle size
- High memory usage
- Chromium overhead

## 🚧 Roadmap

### ✅ MVP (Complete)
- [x] Project scanning and Git status
- [x] GitHub CLI integration
- [x] LLM integration (GLM-4.7 + Ollama)
- [x] SwiftUI interface
- [x] Configuration persistence

### ✅ Recent Enhancements (v1.1)
- [x] MenuBarExtra integration with project summary
- [x] Unified Branches & History tab with toggle
- [x] Complete keyboard shortcuts system (⌘1-4, ⌘R, ESC, ⌘K, ⌘N)
- [x] Tooltips on all actionable buttons
- [x] Integrated terminal with auto-focus
- [x] External terminal configuration (Ghostty, iTerm2, Warp, etc.)
- [x] Branch switching from UI
- [x] Unit tests for GitService
- [x] Visual commit timeline
- [x] ESC key to close modals
- [x] Settings persistence with visual feedback

### 🚧 Next Steps
- [ ] Lazy loading for large project sets
- [ ] Git status caching with intelligent invalidation
- [ ] Concurrent scanning with rate limiting
- [ ] Auto-refresh on file changes
- [ ] Custom LLM prompts per project
- [ ] Export analysis reports
- [ ] Notification support for PRs and changes
- [ ] Performance metrics dashboard

## 🐛 Troubleshooting

### Build Errors

```bash
# Clean and rebuild
rm -rf .build
swift build
```

### GitHub CLI Not Found

```bash
# Install
brew install gh

# Authenticate
gh auth login
```

### Ollama Connection Issues

```bash
# Check if running
curl http://localhost:11434/api/tags

# Start
ollama serve

# List models
ollama list

# Pull model
ollama pull codellama
```

### Xcode Issues

If Xcode project is outdated:
```bash
rm -rf GitMonitor.xcodeproj
swift package generate-xcodeproj
open GitMonitor.xcodeproj
```

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add/update tests (when test framework added)
5. Update documentation
6. Submit a pull request

### Code Style

- Follow Swift standard conventions
- Use async/await, not callbacks
- Add `// MARK:` comments for organization
- Document public APIs

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details

## 🌟 Acknowledgments

- **Swift** and **SwiftUI** by Apple
- **Ollama** for local LLM infrastructure
- **GLM-4.7** by Zhipu AI
- **GitHub CLI** for PR status

## 📞 Support

- 📖 **Documentation**: See [docs/](docs/)
- 🐛 **Issues**: [GitHub Issues](https://github.com/yourusername/labs-gitman/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/yourusername/labs-gitman/discussions)

---

<div align="center">

**Built with ❤️ using Swift & SwiftUI**

[⭐ Star](https://github.com/yourusername/labs-gitman) · [🍴 Fork](https://github.com/yourusername/labs-gitman/fork) · [📖 Docs](docs/)

</div>
