# Game Mode Documentation

## 📚 Canonical Documents

This folder contains the official, up-to-date documentation for GitMonitor's Game Mode feature.

### Core Documents

- **[CONCEPT.md](./CONCEPT.md)** - Vision, core metaphor, visual style, MVP scope
- **[TECHNICAL.md](./TECHNICAL.md)** - Architecture, implementation guide, code examples

## 🎯 Quick Start

1. Start with [CONCEPT.md](./CONCEPT.md) to understand the vision
2. Review [TECHNICAL.md](./TECHNICAL.md) for implementation details
3. Follow the Phase 0 → Phase 4 roadmap

## 📖 Background

Game Mode transforms GitMonitor from a traditional macOS app into a game-like "Git Monitoring Office" where:
- You are the manager at your desk
- Workers/agents travel to project portals
- They return with visual Git status reports
- All powered by the existing GitMonitor infrastructure

## 🏗️ Architecture

```
SwiftUI (Navigation, Settings, Detail Views)
    ↓
GameCoordinator (Game Mode ViewModel)
    ↓
SpriteKit Scene (Office, Agents, Portals, Reports)
    ↓
Existing GitMonitor Services (GitService, CacheManager, etc.)
```

## 🔗 Related

- Main project: [../../README.md](../../README.md)
- Development guide: [../../docs/02-DEVELOPMENT_GUIDE.md](../../docs/02-DEVELOPMENT_GUIDE.md)
- Project overview: [../../docs/01-PROJECT_OVERVIEW.md](../../docs/01-PROJECT_OVERVIEW.md)
