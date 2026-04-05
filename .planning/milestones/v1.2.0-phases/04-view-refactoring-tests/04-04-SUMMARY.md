---
phase: 04-view-refactoring-tests
plan: 04
subsystem: MapView / MapViewModel
tags: [refactoring, viewmodel, mvvm, swiftui]
requirements: [DEBT-02]
dependency_graph:
  requires:
    - ValetudoApp/ValetudoApp/Services/RobotManager.swift
    - ValetudoApp/ValetudoApp/Models/RobotState.swift
    - ValetudoApp/ValetudoApp/Models/RobotMap.swift
    - ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift
  provides:
    - ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift
  affects:
    - ValetudoApp/ValetudoApp/Views/MapView.swift
tech_stack:
  added:
    - MapViewModel (@MainActor, ObservableObject, @StateObject pattern)
  patterns:
    - MVVM: @StateObject ViewModel initialized in View init with dependencies
    - GoToPresetStore moved to ViewModel ownership
    - Gesture state remains View-local (scale, offset, draw points)
key_files:
  created:
    - ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift
  modified:
    - ValetudoApp/ValetudoApp/Views/MapView.swift
    - ValetudoApp/ValetudoApp.xcodeproj/project.pbxproj
decisions:
  - "@StateObject initialized in init(robot:robotManager:isFullscreen:) — robotManager passed from environment to avoid capturing EnvironmentObject in non-view context"
  - "Gesture/drawing state (scale, offset, currentDrawStart/End, isDraggingSplitStart/End) kept View-local — these are frame-dependent and inherently tied to the render loop"
  - "finishDrawing() kept in View — it writes to viewModel.drawnZones etc. but needs currentDrawStart/End which are view-local; bridge method that translates gesture coordinates to ViewModel state"
  - "MapPreviewView unchanged — lightweight polling-only preview with no editing, no ViewModel needed"
  - "splitRoom() passes gesture scale/offset to ViewModel — coordinate calculation requires knowledge of current view transform"
metrics:
  duration: ~25min
  completed: "2026-03-27"
  tasks: 2
  files: 3
---

# Phase 04 Plan 04: MapViewModel Extraction Summary

MapContentView's business logic extracted into a dedicated @MainActor MapViewModel, reducing MapView.swift by ~660 lines while the View becomes a declarative shell with only gesture/drawing state remaining locally.

## What Was Built

**MapViewModel.swift** (473 lines) — new @MainActor final class ObservableObject:
- All @Published state: map, segments, capabilities (hasZoneCleaning, hasGoTo, etc.), editMode, drawn zones/restrictions, room edit state, preset state, go-to state
- loadMap() — fetches capabilities, virtual restrictions, map, and segments
- startMapRefresh() / stopMapRefresh() — 2-second polling loop lifecycle
- cleanSelectedRooms() / cleanZones() — cleaning actions
- goToPoint(x:y:) / saveCurrentLocationAsPreset() — navigation
- renameRoom() / joinRooms() / splitRoom() — room editing with map reload
- deleteRestriction() / saveRestrictions() — restriction CRUD
- cancelEditMode() / confirmEditMode() — edit mode lifecycle

**MapContentView refactored** in MapView.swift:
- `@StateObject private var viewModel: MapViewModel` replaces ~30 @State properties
- `init(robot:robotManager:isFullscreen:)` initializes ViewModel with dependencies
- Gesture state retained locally: scale, lastScale, offset, lastOffset, currentDrawStart/End, isDraggingSplitStart/End, currentViewSize
- MapTabView and MapView (sheet) updated to pass robotManager explicitly
- MapPreviewView untouched

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] streamMapLines() not available in worktree API**
- **Found during:** Task 1
- **Issue:** Worktree is on older branch without Phase 2 SSE additions; `api.streamMapLines()` does not exist in this codebase version
- **Fix:** Replaced SSE+polling hybrid with 2-second polling only (matching MapPreviewView pattern)
- **Files modified:** ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift
- **Commit:** aebfb1b

**2. [Rule 3 - Blocking] MapContentView init requires explicit robotManager**
- **Found during:** Task 2
- **Issue:** ViewModel must be initialized in View's init() before @EnvironmentObject is available; cannot use `@EnvironmentObject var robotManager` directly to initialize `@StateObject`
- **Fix:** Added `robotManager: RobotManager` parameter to MapContentView init; updated MapTabView and MapView (sheet) to pass `robotManager` from their own `@EnvironmentObject`
- **Files modified:** ValetudoApp/ValetudoApp/Views/MapView.swift
- **Commit:** 15cee5c

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | aebfb1b | feat(04-04): Create MapViewModel with extracted state and methods |
| 2 | 15cee5c | feat(04-04): Refactor MapContentView to consume MapViewModel |

## Known Stubs

None — all ViewModel methods are fully implemented. The polling-based map refresh is intentional for this branch version (no SSE available).

## Self-Check: PASSED
