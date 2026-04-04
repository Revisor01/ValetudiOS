---
phase: 23-error-handling-robustness-patterns
plan: "01"
subsystem: ViewModels / Error Handling
tags: [error-handling, logging, viewmodel, robustness, swift]
dependency_graph:
  requires: []
  provides: [ErrorRouter injection in all three ViewModels, do/catch in user actions]
  affects:
    - ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift
    - ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift
    - ValetudoApp/ValetudoApp/ViewModels/RobotSettingsViewModel.swift
    - ValetudoApp/ValetudoApp/Views/RobotDetailView.swift
    - ValetudoApp/ValetudoApp/Views/MapView.swift
    - ValetudoApp/ValetudoApp/Views/RobotSettingsView.swift
tech_stack:
  added: []
  patterns: [ErrorRouter injection via @Environment, do/catch with logger.error + errorRouter?.show]
key_files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift
    - ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift
    - ValetudoApp/ValetudoApp/ViewModels/RobotSettingsViewModel.swift
    - ValetudoApp/ValetudoApp/Views/RobotDetailView.swift
    - ValetudoApp/ValetudoApp/Views/MapView.swift
    - ValetudoApp/ValetudoApp/Views/RobotSettingsView.swift
decisions:
  - ErrorRouter as Optional property (var errorRouter: ErrorRouter?) injected from View in .task — keeps ViewModels testable without mandatory ErrorRouter dependency
  - logger.error upgraded from logger.debug in capability-loading catch blocks to distinguish network/API errors from expected "not supported" failures
metrics:
  duration: "~7 minutes"
  completed: "2026-04-04"
  tasks_completed: 2
  files_modified: 6
---

# Phase 23 Plan 01: ErrorRouter Injection and Silent Error Elimination Summary

## One-liner

ErrorRouter injected into all three ViewModels with do/catch replacing try? in user actions, and logger.error added to all catch blocks in RobotSettingsViewModel so no API error is silently swallowed.

## What Was Done

### Task 1: ErrorRouter injection + try? replacement (DEBT-03)

Added `var errorRouter: ErrorRouter?` property to:
- `RobotDetailViewModel` (after capability flags)
- `MapViewModel` (in Error State section)
- `RobotSettingsViewModel` (before Computed section)

Replaced all 5 `try?` in user-initiated actions:
1. `locate()` in RobotDetailViewModel: `try? await api.locate()` → `do/catch` with `errorRouter?.show(error)`
2. `joinRooms()` in MapViewModel: two `try? await api.getMap/getSegments()` → `do/catch` each with `errorRouter?.show(error)`
3. `splitRoom()` in MapViewModel: two `try? await api.getMap/getSegments()` → `do/catch` each with `errorRouter?.show(error)`
4. `setVoicePack()` in RobotSettingsViewModel: `try? await api.getVoicePackState()` → `do/catch` with `errorRouter?.show(error)`
5. `restoreMapSnapshot()` in RobotSettingsViewModel: `try? await api.getMapSnapshots()` → `do/catch` with silent logger.error (reload only, no user-facing error)

Injected errorRouter in Views via `.task`:
- `RobotDetailView`: added `@Environment(ErrorRouter.self) var errorRouter`, sets `viewModel.errorRouter = errorRouter` in `.task`
- `MapContentView` (in MapView.swift): added `@Environment(ErrorRouter.self) var errorRouter`, sets `viewModel.errorRouter = errorRouter` in `.task`
- `RobotSettingsView`: added `@Environment(ErrorRouter.self) var errorRouter`, sets `viewModel.errorRouter = errorRouter` in `.task`

Background polling `try? await api.getMap()` in `startMapRefresh()` (MapViewModel line 167) was intentionally left as-is — it's a system background operation, not a user action.

### Task 2: logger.error in all catch blocks (DEBT-04)

Added `logger.error()` to all catch blocks in RobotSettingsViewModel that had no logging:
- `getSpeakerVolume`, `getCarpetMode`, `getPersistentMap`
- `getCapabilities`
- `getKeyLock`, `getObstacleAvoidance`, `getPetObstacleAvoidance`
- `getCarpetSensorMode`, `getCollisionAvoidantNavigation`, `getFloorMaterialNavigation`
- `getMopDockAutoDrying`, `getMopDockWashTemperature`

Upgraded from `logger.debug` to `logger.error` for capability-deactivating catch blocks:
- `getMopDockDryingTime`, `getMapSnapshots`, `getPendingMapChange`, `getVoicePackState`, `getAutoEmptyDockDuration`

RobotDetailViewModel catch blocks were already correct (logger.error present).

## Verification

- `grep "try? await api."` in all three ViewModels returns 0 matches (background polling excepted)
- `grep "var errorRouter: ErrorRouter?"` returns 1 match in each of the three ViewModels
- `grep "viewModel.errorRouter = errorRouter"` returns 1 match in RobotDetailView and MapView
- Build: `BUILD SUCCEEDED` (Xcode, iPhone 16 Pro simulator)

## Deviations from Plan

None — plan executed exactly as written. All 7 try? in user actions replaced, all catch blocks in RobotSettingsViewModel now have logging.

## Known Stubs

None.

## Self-Check: PASSED

Files modified exist and commit 1aaee87 is present in git log.
