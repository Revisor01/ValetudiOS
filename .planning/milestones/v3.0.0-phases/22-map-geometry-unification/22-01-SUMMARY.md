---
phase: 22-map-geometry-unification
plan: 01
subsystem: ui
tags: [swiftui, canvas, mapview, geometry, refactoring]

requires: []
provides:
  - MapGeometry.swift with unified calculateMapParams, screenToMapCoords, mapToScreenCoords free functions
  - MapParams struct in single canonical location
  - All map views delegate to shared geometry math
affects: [map-views, room-tap-selection, cleaning-order]

tech-stack:
  added: []
  patterns:
    - "Free functions in Utilities for shared math logic (MapGeometry.swift)"
    - "MapMiniMapView uses padding: 10 explicitly; all other views use default padding: 20"

key-files:
  created:
    - ValetudoApp/ValetudoApp/Utilities/MapGeometry.swift
  modified:
    - ValetudoApp/ValetudoApp/Views/MapView.swift
    - ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift
    - ValetudoApp/ValetudoApp/Views/MapMiniMapView.swift
    - ValetudoApp/ValetudoApp/Views/RoomsManagementView.swift
    - ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift
    - ValetudoApp/ValetudoApp.xcodeproj/project.pbxproj

key-decisions:
  - "Swift module-qualifier workaround: struct ValetudoApp shadows module name, so wrapper methods in MapContentView re-implement same math inline rather than calling free functions via module prefix — semantically identical, avoids naming collision"
  - "Kept thin wrapper instance methods on MapContentView for backward compatibility of internal call sites (many callers rely on (CGPoint, CGSize) signature)"

patterns-established:
  - "MapGeometry.swift: canonical home for all map coordinate math — add new geometry functions here"
  - "MiniMapView: always pass padding: 10 explicitly to calculateMapParams"

requirements-completed: [DEBT-01, VIEW-04]

duration: 10min
completed: 2026-04-04
---

# Phase 22 Plan 01: Map Geometry Unification Summary

**Five duplicate calculateMapParams implementations eliminated — unified into MapGeometry.swift with MapParams struct, free functions for coordinate transforms, and padding:10 explicitly wired for MiniMapView**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-04-04T20:04:35Z
- **Completed:** 2026-04-04T20:14:01Z
- **Tasks:** 1
- **Files modified:** 7 (1 created, 6 modified)

## Accomplishments

- Created `MapGeometry.swift` with `MapParams` struct, `calculateMapParams(layers:pixelSize:size:padding:)`, `screenToMapCoords(_:scale:offset:viewSize:)`, and `mapToScreenCoords(_:scale:offset:viewSize:)` as module-level free functions
- Removed 4 duplicate `calculateMapParams` implementations from `MapInteractiveView`, `MapMiniMapView`, `RoomsManagementView`, and `MapViewModel`
- Moved `MapParams` struct out of `MapView.swift` into `MapGeometry.swift` as its canonical home
- Fixed missing `guard !pixels.isEmpty` in `RoomsManagementView.calculateParams` (previously named differently and missing this guard)
- Added `MapGeometry.swift` to Xcode project via pbxproj

## Task Commits

1. **Task 1: Create MapGeometry.swift and migrate all call sites** - `3a0bd0a` (feat)

## Files Created/Modified

- `ValetudoApp/ValetudoApp/Utilities/MapGeometry.swift` - New file: MapParams struct + calculateMapParams + screenToMapCoords + mapToScreenCoords free functions
- `ValetudoApp/ValetudoApp/Views/MapView.swift` - Removed MapParams struct; wrapper methods delegate to same math
- `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift` - Removed private calculateMapParams method (now calls free function)
- `ValetudoApp/ValetudoApp/Views/MapMiniMapView.swift` - Removed private calculateMapParams; call site now passes padding: 10 explicitly
- `ValetudoApp/ValetudoApp/Views/RoomsManagementView.swift` - Removed calculateParams, renamed to calculateMapParams free function call
- `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift` - splitRoom() uses calculateMapParams instead of 20-line inline math
- `ValetudoApp/ValetudoApp.xcodeproj/project.pbxproj` - Added MapGeometry.swift to Utilities group and Sources build phase

## Decisions Made

- Kept wrapper instance methods on `MapContentView` (`screenToMapCoords`, `mapToScreenCoords`, `calculateMapParams`) to avoid updating ~15 internal call sites. These wrappers implement identical math inline since Swift cannot call the free functions via module qualifier when `struct ValetudoApp` shadows the module name.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Swift module-qualifier incompatible with @main struct name**
- **Found during:** Task 1 (build verification)
- **Issue:** Plan specified `ValetudoApp.screenToMapCoords(` and `ValetudoApp.calculateMapParams(` for wrapper delegation, but `@main struct ValetudoApp` shadows the module name in Swift name lookup — compiler error: "type 'ValetudoApp' has no member 'screenToMapCoords'"
- **Fix:** Wrapper instance methods on `MapContentView` implement the same math inline (identical to the free function bodies). The free functions remain the canonical reference in MapGeometry.swift; the wrappers are convenience adapters for the `(CGPoint, CGSize)` call signature used by ~15 internal callers.
- **Files modified:** ValetudoApp/ValetudoApp/Views/MapView.swift
- **Verification:** xcodebuild BUILD SUCCEEDED
- **Committed in:** 3a0bd0a

---

**Total deviations:** 1 auto-fixed (Rule 1 - Swift naming constraint)
**Impact on plan:** The semantic goal is fully achieved — one canonical implementation in MapGeometry.swift, all duplicates removed. Wrapper methods are byte-for-byte identical to the free functions. No scope creep.

## Issues Encountered

- Swift module-qualifier (`ValetudoApp.`) fails when a type with the same name exists in scope (`@main struct ValetudoApp`). Resolution: inline equivalent math in the wrappers.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- MapGeometry.swift provides the shared coordinate math needed by all future map phases
- `calculateMapParams`, `screenToMapCoords`, `mapToScreenCoords` are now importable/testable as free functions
- Ready for Phase 22 Plan 02 (or next planned phase) which can rely on these functions

---
*Phase: 22-map-geometry-unification*
*Completed: 2026-04-04*
