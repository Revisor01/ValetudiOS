---
phase: 29-ux-robustness
plan: "02"
subsystem: networking
tags: [swift, swiftui, robotmanager, polling, sse, multi-robot]

# Dependency graph
requires:
  - phase: 23-error-handling-robustness-patterns
    provides: ErrorRouter and robust error handling patterns used throughout app
provides:
  - activeRobotId property in RobotManager with didSet polling restart
  - HTTP polling restricted to active robot when activeRobotId is set
  - ContentView syncs selectedRobotId to RobotManager.activeRobotId
affects: [30-any-future-multi-robot-phase]

# Tech tracking
tech-stack:
  added: []
  patterns: [activeRobotId didSet pattern for reactive polling control]

key-files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/Services/RobotManager.swift
    - ValetudoApp/ValetudoApp/ContentView.swift

key-decisions:
  - "SSE stays active for all robots — only HTTP fallback polling is restricted to active robot"
  - "activeRobotId=nil falls back to polling all robots (backward compatible default)"

patterns-established:
  - "activeRobotId didSet -> restartRefreshing() pattern for reactive polling control"

requirements-completed: [ROBUST-03]

# Metrics
duration: 8min
completed: 2026-04-04
---

# Phase 29 Plan 02: UX Robustness — Multi-Robot Polling Summary

**HTTP fallback polling restricted to the active robot via activeRobotId property with didSet-triggered restartRefreshing(), reducing unnecessary network load and battery drain in multi-robot setups**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-04T23:35:00Z
- **Completed:** 2026-04-04T23:43:00Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments
- Added `activeRobotId: UUID?` to RobotManager with `didSet` that calls `restartRefreshing()` when the value changes
- Added `restartRefreshing()` private method that cancels the current refresh task and starts a new one
- Modified HTTP polling TaskGroup to use `robotsToPoll` filter — only polls active robot when `activeRobotId != nil`, all robots when `nil`
- ContentView `.onChange(of: selectedRobotId)` now syncs the value to `robotManager.activeRobotId`
- SSE connections remain active for all robots (status/battery updates still flow for non-active robots)

## Task Commits

Each task was committed atomically:

1. **Task 1: activeRobotId in RobotManager + HTTP-Polling beschraenken (ROBUST-03)** - `c6b3494` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `ValetudoApp/ValetudoApp/Services/RobotManager.swift` - Added activeRobotId property, restartRefreshing(), robotsToPoll filter
- `ValetudoApp/ValetudoApp/ContentView.swift` - .onChange syncs selectedRobotId to robotManager.activeRobotId

## Decisions Made
- SSE connections stay active for all robots regardless of activeRobotId — only HTTP fallback polling is restricted. This ensures battery/status attribute updates continue for all robots via the lightweight SSE stream.
- When `activeRobotId == nil` (no robot selected), all robots are polled as before — backward compatible default.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- ROBUST-03 complete: Multi-robot HTTP polling restricted to active robot
- Phase 29 Plan 01 (ErrorRouter wiring) and Plan 03 (Confirmation Dialogs, if any) are independent
- No blockers for subsequent phases

---
*Phase: 29-ux-robustness*
*Completed: 2026-04-04*
