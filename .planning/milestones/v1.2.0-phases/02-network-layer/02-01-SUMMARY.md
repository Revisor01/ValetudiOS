---
phase: 02-network-layer
plan: 01
subsystem: network/sse
tags: [sse, streaming, real-time, actor, urlsession, polling-fallback]
dependency_graph:
  requires: []
  provides: [SSEConnectionManager, ValetudoAPI.streamStateLines, ValetudoAPI.streamMapLines]
  affects: [RobotManager.startRefreshing, RobotManager.refreshRobot, RobotManager.removeRobot]
tech_stack:
  added: [URLSession.AsyncBytes, URLSession.bytes(for:).lines]
  patterns: [Swift actor for concurrent SSE stream management, SSE-first with polling fallback, CancellationError-safe reconnect loop]
key_files:
  created:
    - ValetudoApp/ValetudoApp/Services/SSEConnectionManager.swift
  modified:
    - ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift
    - ValetudoApp/ValetudoApp/Services/RobotManager.swift
    - ValetudoApp/ValetudoApp.xcodeproj/project.pbxproj
decisions:
  - ErrorRouter.shared does not exist (no singleton pattern) — SSE connection loss logged via os.Logger instead; polling fallback provides silent recovery without alert spam
  - sseSession implemented as computed property with internal backing var (_sseSession) since Swift actors cannot use lazy stored properties directly
  - refreshRobot() removes checkConnection() pre-flight — errors from getAttributes()/getRobotInfo() treated as offline signal, saving one HTTP round-trip per poll cycle
metrics:
  duration: ~15 minutes
  completed: "2026-03-27"
  tasks: 2
  files_modified: 4
---

# Phase 02 Plan 01: SSE Real-Time Updates Summary

**One-liner:** SSE streaming infrastructure via Swift actor with URLSession.AsyncBytes, integrated into RobotManager as SSE-first with automatic 5s polling fallback.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | SSEConnectionManager actor + ValetudoAPI SSE-Methoden | da43975 | SSEConnectionManager.swift (new), ValetudoAPI.swift |
| 2 | RobotManager SSE-Integration mit Polling-Fallback | 66576d0 | RobotManager.swift |

## What Was Built

### SSEConnectionManager (new actor)

Swift `actor` managing per-robot SSE stream lifecycle:
- `connect(robotId:api:onAttributesUpdate:onConnectionChange:)` — starts a `Task` per robot, cancels existing before replacing
- `streamWithReconnect()` — while-loop connecting via `api.streamStateLines()`, iterating `bytes.lines`, parsing `data:` SSE events as `[RobotAttribute]` JSON, automatic 30s retry on error
- `isSSEActive(for:)` — returns whether robot has live SSE connection
- `disconnect(robotId:)` / `disconnectAll()` — cancel tasks and clear state
- `CancellationError` handled with `break` (not swallowed) to allow clean shutdown
- Logger with category `"SSE"` for all connection events

### ValetudoAPI SSE extensions

- `_sseSession` backing var + computed `sseSession` property with `.infinity` timeouts (request and resource)
- `streamStateLines()` — GET `/api/v2/robot/state/attributes/sse`, Basic Auth, returns `URLSession.AsyncBytes`
- `streamMapLines()` — GET `/api/v2/robot/state/map/sse`, same pattern

### RobotManager integration

- `sseManager = SSEConnectionManager()` property
- `startRefreshing()` rebuilt: each cycle connects SSE for robots without active connection, then polls only robots where `isSSEActive == false`
- `applyAttributeUpdate(_:for:)` — applies SSE attribute events to `robotStates` directly (preserves existing `RobotInfo`, triggers `checkStateChanges` for notifications)
- `sseConnectionChanged(_:for:)` — logs SSE connect/disconnect; polling resumes automatically when SSE drops
- `removeRobot(_:)` disconnects SSE before clearing state
- `refreshRobot(_:)` removes `checkConnection()` pre-flight — errors from API calls treated as offline signal

## Deviations from Plan

### Auto-fixed Issues

None.

### Plan Corrections

**1. [Rule 1 - Bug] ErrorRouter.shared does not exist**
- **Found during:** Task 2
- **Issue:** Plan specified `ErrorRouter.shared.show()` in `sseConnectionChanged()` but `ErrorRouter` has no singleton pattern — it is injected via SwiftUI environment
- **Fix:** SSE connection loss is logged via `os.Logger` with `.warning` level; polling fallback silently resumes. User impact is zero since polling recovers automatically within 5s
- **Files modified:** RobotManager.swift (no ErrorRouter import added)
- **Commit:** 66576d0

**2. [Rule 2 - Deviation] sseSession as computed property instead of lazy stored property**
- **Found during:** Task 1
- **Issue:** Swift actors cannot use `lazy var` with mutation directly (compiler error)
- **Fix:** Used private `_sseSession: URLSession?` backing var with a computed `sseSession: URLSession` that initializes and stores on first access — functionally equivalent

## Known Stubs

None. SSE infrastructure is fully wired: SSEConnectionManager → ValetudoAPI.streamStateLines → RobotManager.startRefreshing → robotStates updates. No placeholder values or mock data flows to the UI.

## Self-Check: PASSED

Files exist:
- FOUND: ValetudoApp/ValetudoApp/Services/SSEConnectionManager.swift
- FOUND: ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift (modified)
- FOUND: ValetudoApp/ValetudoApp/Services/RobotManager.swift (modified)

Commits exist:
- da43975: feat(02-01): add SSEConnectionManager actor and ValetudoAPI SSE streaming methods
- 66576d0: feat(02-01): integrate SSEConnectionManager into RobotManager with polling fallback
