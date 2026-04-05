---
phase: 29-ux-robustness
plan: "01"
subsystem: ViewModels / Error Handling
tags: [error-handling, ux, robustness, swift]
dependency_graph:
  requires: [Phase 23 ErrorRouter injection]
  provides: [errorRouter?.show in all user-initiated actions in RobotDetailViewModel and MapViewModel]
  affects:
    - ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift
    - ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift
tech_stack:
  added: []
  patterns: [errorRouter?.show(error) in every user-initiated action catch block]
key_files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift
    - ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift
decisions:
  - errorMessage property kept in MapViewModel (used by existing test testErrorMessageIsSettable) — cleanSelectedRooms no longer sets it but the property remains for test compatibility
  - Background polling methods (startMapRefresh) intentionally left without errorRouter — system operations, not user-initiated
metrics:
  duration: "~3 minutes"
  completed: "2026-04-05"
  tasks_completed: 2
  files_modified: 2
---

# Phase 29 Plan 01: ErrorRouter Systematically Wired Summary

## One-liner

errorRouter?.show(error) added to all 11 user-initiated action methods in RobotDetailViewModel and 9 in MapViewModel, completing ROBUST-01 so no user action fails silently.

## What Was Done

### Task 1: RobotDetailViewModel — 11 action methods wired

Added `errorRouter?.show(error)` after `logger.error` in every user-initiated action catch block:

1. `performAction(_:)` — basic control (start/stop/pause/home)
2. `cleanSelectedRooms()` — segment cleaning
3. `setFanSpeed(_:)` — fan speed preset
4. `setWaterUsage(_:)` — water usage preset
5. `setOperationMode(_:)` — operation mode preset
6. `triggerAutoEmpty()` — dock auto-empty trigger
7. `triggerMopDockClean()` — mop dock clean trigger
8. `triggerMopDockDry()` — mop dock dry trigger
9. `resetConsumable(_:)` — consumable reset
10. `dismissEvent(_:)` — event dismissal
11. `setCleanRoute(_:)` — clean route selection

`locate()` already had errorRouter wiring from Phase 23 — unchanged.

### Task 2: MapViewModel — 9 action methods wired

Added `errorRouter?.show(error)` in every user-initiated action catch block:

1. `cleanSelectedRooms()` — replaced `errorMessage = error.localizedDescription` with errorRouter?.show(error)
2. `cleanZones()` — zone cleaning
3. `goToPoint(x:y:)` — go-to navigation
4. `renameRoom(id:name:)` — room rename
5. `joinRooms(ids:)` — outer catch (join API failure)
6. `splitRoom(segmentId:start:end:viewSize:)` — outer catch (split API failure)
7. `deleteRestriction(type:index:)` — virtual restriction delete
8. `saveRestrictions()` — virtual restrictions save
9. `confirmEditMode(currentDrawStart:currentDrawEnd:)` — zone case

Inner catches in `joinRooms` and `splitRoom` (map/segment reload after successful API call) already had errorRouter wiring from Phase 23 — unchanged.

## Verification

- `grep -n "errorRouter?.show" RobotDetailViewModel.swift` — 12 matches (11 new + 1 pre-existing locate())
- `grep -n "errorRouter?.show" MapViewModel.swift` — 13 matches (9 new + 4 pre-existing from Phase 23)
- Build: `BUILD SUCCEEDED` (Xcode, iPhone 16 Pro simulator, iOS 18.5)

## Deviations from Plan

None — plan executed exactly as written. `errorMessage` property kept in MapViewModel for test compatibility as expected.

## Known Stubs

None.

## Self-Check: PASSED
