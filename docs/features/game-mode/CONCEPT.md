# GitMonitor: Game Mode (2.5D) — Concept

> **Implementation Status**: ✅ **MVP COMPLETE** (Phases 0-2)  
> **Build Status**: ✅ Successful  
> **Last Updated**: 2026-01-09  
> See [IMPLEMENTATION_STATUS.md](./IMPLEMENTATION_STATUS.md) for details.

---

## Vision
Transform GitMonitor from a traditional macOS app into a game-like “Git Monitoring Office” where you (the manager) dispatch workers/agents to project portals and receive visual reports.

The goal is *not* to replace GitMonitor’s core capabilities, but to provide a more engaging, spatial way to operate the same workflows.

## Core Metaphor: “Office of Reports”
- **You**: the manager at the desk.
- **Agents**: workers that travel to portals, do work, and return with a report.
- **Project portals**: doors/terminals that represent monitored projects.
- **Report board**: where results appear (cards / widgets).

## Interaction Loop (MVP)
1. You click a portal (project).
2. The coordinator assigns an available agent.
3. Agent walks to portal (2.5D movement).
4. Agent “works” (loading state).
5. Agent returns to desk.
6. A report card appears on the report board.

## Visual Style
### 2.5D / Isometric (Chosen)
We’ll start in **2.5D isometric** using **basic geometry** (no external assets required):
- Agent: simple shapes (circle head + rectangle body) or a single rounded rect.
- Portals: colored rounded rectangles with a status indicator.
- Office: flat-shaded isometric surfaces (floor/walls) using SKShapeNode.

### Why geometry-first
- Fast iteration.
- No dependency on art/asset pipeline.
- Lets us validate UX/flow before investing in art.

## MVP Scope vs Later Phases
### MVP (Foundation + Core Loop)
- 2.5D office scene with 2 agents.
- Project portals laid out in the room.
- Click portal → dispatch agent → run git status → return → show report.
- **Reports visible: 1** (simple).
- **Queue enabled**: if you click multiple portals, tasks enqueue.
- Debug overlay toggle.

### Post-MVP (Polish)
- Multiple visible reports (stack/board/grid).
- Agent personalities (celebrating/alerting).
- Particles and SFX.
- Camera controls (zoom/pan) and better layout.

## Agents
### Responsibilities
- Visual presence and animation.
- Travel to target portal.
- Show working state while git operations run.
- Return and “deliver” report.

### Personality states (Phase 4)
- **Celebrating**: for clean repos / successful refresh.
- **Alerting**: for uncommitted changes / high attention.

(We keep the state design from day 1, but only implement the minimum visual behaviors until Phase 4.)

## Reports
### MVP
- One report card visible on the board at a time.
- New report replaces the previous (or fades it out).

### Scalable design
- Support **N reports** via configuration:
  - `maxVisibleReports = 1` for MVP.
  - Later switch to `3` or `unlimited` with layout rules.
- Reports should be clickable to open the existing `ProjectDetailView`.

## Game Mode vs Traditional UI
We keep **Hybrid Mode**:
- Traditional UI remains available as fallback.
- Game Mode becomes an alternate “surface” driven by the same ViewModels/Services.

## Debugging / Dev Experience (Important)
- **Debug overlay** toggle:
  - agent states
  - target portal id
  - current queue length
  - coordinates grid
- **Activity log** (in debug overlay or console): dispatch, completion, errors.
- **Performance metrics**: FPS + average frame time.

## Constraints / Non-goals
- Not building a full game engine or physics-heavy simulation.
- No complex pathfinding in MVP (straight-line + easing).
- No dependency on external 3D assets in MVP.

## Success Criteria
- **Clarity**: you can understand what’s happening at a glance.
- **Responsiveness**: smooth scene updates while git tasks run.
- **Delight**: interaction feels playful but still productive.
- **Continuity**: doesn’t break existing workflows.
