---
phase: 22-map-geometry-unification
plan: 02
subsystem: ui
tags: [swiftui, observable, viewmodel, state-management, room-selection]

requires:
  - phase: 22-01
    provides: MapGeometry.swift with unified coordinate math and MapParams struct

provides:
  - Centralized room selection state (roomSelections, iterationSelections) in RobotManager
  - MapViewModel syncs selectedSegmentIds to RobotManager via didSet on every mutation
  - RobotDetailViewModel syncs selectedSegments to RobotManager via didSet on every mutation
  - Both ViewModels load from RobotManager on init — single source of truth

affects: [room-selection, cleaning-order, map-view, detail-view]

tech-stack:
  added: []
  patterns:
    - "didSet sync pattern: stored property mutates locally, didSet writes back to shared manager"
    - "RobotManager per-robot dicts: roomSelections[UUID] and iterationSelections[UUID]"
    - "Init loads from shared state, didSet keeps it synced — no observers or Combine needed"

key-files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/Services/RobotManager.swift
    - ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift
    - ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift

key-decisions:
  - "didSet sync pattern chosen over computed properties — @Binding on $viewModel.selectedSegmentIds requires a stored property; computed property breaks binding in @Observable types"
  - "No Combine/Publisher needed — didSet is synchronous and sufficient for this use case"
  - "clearRoomSelection sets to nil (not empty array) to distinguish 'never selected' from 'cleared'"

patterns-established:
  - "RobotManager is the single source of truth for all per-robot session state (selection, iterations)"
  - "ViewModels are ephemeral read/write adapters — load on init, write on every mutation via didSet"

requirements-completed: [DEBT-02]

duration: 2min
completed: 2026-04-04
---

# Phase 22 Plan 02: Room Selection State Centralization Summary

**RobotManager gains roomSelections and iterationSelections dicts; MapViewModel and RobotDetailViewModel sync via didSet, eliminating the view-switch deselection bug (DEBT-02)**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-04-04T20:21:18Z
- **Completed:** 2026-04-04T20:22:19Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added `roomSelections: [UUID: [String]]` and `iterationSelections: [UUID: Int]` to `RobotManager` with `toggleRoom`, `clearRoomSelection`, `selectedRooms`, and `selectedIterationCount` helper methods
- `MapViewModel.selectedSegmentIds` now has `didSet` that writes to `robotManager.roomSelections[robot.id]`; init loads from RobotManager
- `MapViewModel.selectedIterations` now has `didSet` that writes to `robotManager.iterationSelections[robot.id]`; init loads from RobotManager
- `RobotDetailViewModel.selectedSegments` and `selectedIterations` get identical didSet + init treatment
- `@Binding` on `$viewModel.selectedSegmentIds` in `InteractiveMapView` continues to work because selectedSegmentIds remains a stored property

## Task Commits

1. **Task 1: Add room selection and iteration state to RobotManager** - `987a32b` (feat)
2. **Task 2: Migrate MapViewModel and RobotDetailViewModel to use shared state** - `7fd4295` (feat)

## Files Created/Modified

- `ValetudoApp/ValetudoApp/Services/RobotManager.swift` - Added centralized room selection MARK section with 2 properties and 4 helper methods
- `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift` - selectedSegmentIds and selectedIterations now have didSet; init loads from RobotManager
- `ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift` - selectedSegments and selectedIterations now have didSet; init loads from RobotManager

## Decisions Made

- Used didSet sync pattern instead of computed properties because `InteractiveMapView` receives `$viewModel.selectedSegmentIds` as a `@Binding`. In `@Observable` types, computed properties cannot be used as `@Binding` sources — a stored property is required. The didSet fires on every mutation (including `.removeAll()`, direct assignment, and `toggleSegment`) so no call site changes were needed.
- No Combine or explicit observers needed — didSet is synchronous and fires on every mutation.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- DEBT-02 fully resolved: room selection made in MapView persists when user navigates to RobotDetailView and vice versa
- RobotManager is now the canonical home for all per-robot ephemeral session state
- Phases 23-26 can proceed — the state-centralization foundation from Phase 22 is complete

---
*Phase: 22-map-geometry-unification*
*Completed: 2026-04-04*
