# Game Mode (2.5D): Technical Implementation Guide

## Goals
- Add a **Game Mode** surface without rewriting GitMonitor’s core architecture.
- Reuse existing **Models**, **Services**, and **ViewModels** (especially `ProjectScannerViewModel`).
- Build an isometric-ish **2.5D** scene using **geometry-first** nodes.
- Keep the implementation *macOS-correct* (mouse/trackpad events, keyboard shortcuts).

## Integration Strategy (SwiftUI + SpriteKit)

### SwiftUI remains responsible for
- App navigation / windows
- Settings
- Existing detail views (`ProjectDetailView`, sheets)
- Toggle entry/exit for Game Mode

### SpriteKit responsible for
- Office scene rendering (2.5D)
- Agents, portals, report board
- Animation and interactive spatial UX

### Recommended: Hybrid Mode
- Keep traditional UI as a fallback.
- Game Mode shares the same data pipeline.

## Folder Structure (Proposed)

```
Views/GameMode/
├── Core/
│   ├── GameModeView.swift
│   ├── GameCoordinator.swift
│   └── GameSceneStore.swift
├── Scene/
│   ├── OfficeScene.swift
│   ├── IsometricGrid.swift
│   └── DebugOverlayNode.swift
├── Nodes/
│   ├── AgentNode.swift
│   ├── ProjectPortalNode.swift
│   ├── DeskNode.swift
│   └── ReportBoardNode.swift
├── Models/
│   ├── AgentState.swift
│   ├── AgentTask.swift
│   └── ProjectReport.swift
└── Utils/
    ├── SKNode+Async.swift
    └── ShapeFactory.swift
```

## Key Design Decisions

### 1) Scene lifecycle must be stable (avoid recreations)
**Problem:** SwiftUI can re-render frequently. If `OfficeScene()` is created inside `var body`, you’ll lose node state and cause flicker.

**Solution:** Keep a persistent scene instance.

Recommended patterns:
- `GameSceneStore: ObservableObject` stores `OfficeScene` once.
- `@StateObject` for the store in `GameModeView`.

### 2) macOS input handling (no UITouch)
In SpriteKit on macOS:
- Use `mouseDown(with:)`, `mouseMoved(with:)`, `rightMouseDown(with:)`.
- Trackpad gestures (pinch/scroll) can be mapped via `NSResponder` / `NSEvent` or by wrapping an `SKView`.

### 3) Async SpriteKit actions require bridging
SpriteKit uses completion handlers. For clean async/await, add a small wrapper.

Example (conceptual):
- `SKNode.runAsync(SKAction)` using `withCheckedContinuation`.

### 4) Git operations should run off the render loop
- SpriteKit should remain at 60 FPS.
- Git scans should run in Tasks and only publish results back on main actor.

## Coordinator & Data Flow

### Reality check: access to git service
In the current code:
- `ProjectScannerViewModel` owns `private let gitService = GitService()`.

So this call (from the earlier draft) is **not possible**:
- `scannerViewModel.gitService.getStatus(for:)`

**Fix options (choose one):**
1. **Expose a VM method** for Game Mode:
   - `func getStatus(for project: Project) async throws -> GitStatus`
   - internally calls `gitService.getStatus(for:)`
2. **Reuse existing methods** already public:
   - `await scannerViewModel.fullRefreshProjectStatus(project)`
   - and then read `project.gitStatus` via `getProject(byId:)`

Option 1 is cleaner for Game Mode because it returns a typed result for a single mission.

### Coordinator responsibilities
- Own agent pool and task queue.
- Assign tasks to idle agents.
- Publish UI-facing state (active report, queue length, debug flags).

## Agent State Machine

### State model
Design the state machine now, implement minimal visuals in MVP.

Suggested states:
```
idle
walkingToPortal(projectId)
enteringPortal
working(progress)
exitingPortal
returningWithReport(GitStatus)
presentingReport
celebrating (Phase 4)
alerting (Phase 4)
```

### Why it matters
- Prevents invalid transitions.
- Makes debug overlay meaningful.
- Provides hooks for later polish (celebration/alert animations).

## Task Queue (MVP-ready)

### Requirements
- Multiple clicks enqueue tasks.
- If an agent is idle, assign immediately.
- If no agents idle, task stays queued.

### MVP behavior
- 2 agents.
- FIFO queue.
- If user clicks same project repeatedly:
  - either allow duplicates (simple)
  - or dedupe by `projectId` (optional)

## Reports

### MVP
- `maxVisibleReports = 1`
- New report replaces old (fade/slide)

### Scale-up path
- Make `maxVisibleReports` configurable.
- When >1:
  - stack layout or grid on the board
  - `ReportBoardNode` becomes a small layout engine

## 2.5D / Isometric Coordinate Helper

### Goal
Give the illusion of depth without complex 3D.

### Helper approach
- Maintain **logical tile coordinates** (x,y) and map to screen:
  - `screenX = (x - y) * tileWidth/2`
  - `screenY = (x + y) * tileHeight/2`
- Set `zPosition` using `screenY` (or logical y) to ensure correct draw order:
  - lower screenY draws behind, higher draws in front.

### MVP simplification
- Straight-line movement in screen space.
- Optional “snap to grid” only for portals and desk.

## Debug Overlay (Recommended)

Add a toggle that shows:
- agent state per agent
- queue length
- selected portal id
- scene FPS / frame time
- coordinate grid

Implementation options:
- `DebugOverlayNode` built from labels and simple shapes.
- Use `SKView.showsFPS` / `showsNodeCount` during development.

## Performance Guidelines
- Prefer `SKShapeNode` geometry for MVP, but batch carefully:
  - too many shape nodes can be heavy.
- Limit per-frame label updates.
- Avoid allocating nodes during `update(_:)`.
- Keep git tasks out of the render loop.

## Roadmap (Optimized)

### Phase 0 (Setup)
- Create Game Mode module folder structure.
- Add toggle entry point in `ProjectListView`.
- Persistent `OfficeScene`.
- macOS mouse event routing.

### Phase 1 (Core Loop)
- Basic 2.5D office layout (floor + desk + portals).
- Agent node with idle + move + work.
- Task queue + dispatch.
- One visible report.
- Debug overlay.

### Phase 2 (Git Integration)
- Mission triggers a single-project status refresh.
- Agent returns with typed `GitStatus`.
- Portal indicator updates.

### Phase 3 (UX expansion)
- Multiple visible reports (configurable).
- Hover tooltips and click-to-open detail view.
- Camera zoom/pan.

### Phase 4 (Polish)
- Celebrating/alerting animations.
- Simple particles (only if needed; keep them light).
- Sound effects.

## Notes
- SpriteKit is included on Apple platforms; no SPM dependency changes are required.
- Keep the existing caches and change detection logic intact; Game Mode should consume the same data.

## Integration Example (ProjectListView)

To add the Game Mode toggle to the existing UI, modify `ProjectListView.swift`:

```swift
struct ProjectListView: View {
    @EnvironmentObject private var viewModel: ProjectScannerViewModel
    @State private var gameModeEnabled = false
    
    var body: some View {
        Group {
            if gameModeEnabled {
                GameModeView(scannerViewModel: viewModel)
            } else {
                // Traditional UI - keep existing code
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    // ... existing sidebar/list code ...
                } detail: {
                    // ... existing detail view code ...
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Toggle(isOn: $gameModeEnabled) {
                    Label("Game Mode", systemImage: "gamecontroller.fill")
                }
            }
        }
    }
}
```

**Key points:**
- Use `@State` for the toggle flag (local to ProjectListView)
- Wrap both modes in a `Group` to enable conditional rendering
- Keep all existing UI code intact in the `else` branch
- The `GameModeView` will be created in Phase 0

## Learning Resources

### Apple Documentation
- [SpriteKit Programming Guide](https://developer.apple.com/documentation/spritekit)
- [SpriteKit Framework Reference](https://developer.apple.com/documentation/spritekit)
- [SwiftUI Integration with SpriteKit](https://developer.apple.com/documentation/spritekit/skview)

### Tutorials & Examples
- [Ray Wenderlich - SpriteKit Tutorials](https://www.raywenderlich.com/category/spritekit)
- [Hacking with Swift - SpriteKit Examples](https://www.hackingwithswift.com/example-code/games)
- [Apple Developer - Building Your First SpriteKit Game](https://developer.apple.com/documentation/spritekit/building_your_first_spritekit_game)

### Isometric / 2.5D Resources
- [Isometric Projection Explained](https://en.wikipedia.org/wiki/Isometric_projection)
- [Creating Isometric Games with SpriteKit](https://www.raywenderlich.com/6180598-creating-isometric-games-with-spritekit)

## Success Metrics

These metrics will help evaluate whether Game Mode achieves its goals:

### Core Goals
- **Clarity**: You can understand what's happening in the scene at a glance (agent states, portal status, active reports).
- **Responsiveness**: Smooth scene updates (60 FPS) while git tasks run in the background.
- **Delight**: Interaction feels playful and engaging, not distracting or frustrating.
- **Continuity**: Game Mode doesn't break existing workflows; users can toggle back to traditional UI seamlessly.

### Performance Targets
- Maintain 60 FPS during idle animations
- No frame drops during agent movement
- Git operations do not block the UI thread
- Memory usage stays under 150 MB with 2 agents

### User Engagement (Post-MVP)
- Users prefer Game Mode over traditional UI for daily monitoring (survey)
- Users toggle between modes based on task (not stick to one permanently)
- Positive feedback on "delight" elements (animations, personalities)

### Technical Quality
- Zero crashes in Game Mode
- Proper cleanup when toggling modes
- Debug overlay provides useful development information
- Code follows existing GitMonitor conventions (MVVM, actors, etc.)
