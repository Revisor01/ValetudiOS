---
phase: 04-view-refactoring-tests
plan: 02
subsystem: ViewModels
tags: [mvvm, viewmodel, swiftui, refactoring, debt]
dependency_graph:
  requires: []
  provides: [RobotDetailViewModel]
  affects: [RobotDetailView, RobotListView]
tech_stack:
  added: [RobotDetailViewModel.swift, ViewModels/ group]
  patterns: [@StateObject init injection, @MainActor ObservableObject, explicit init parameter passing]
key_files:
  created:
    - ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift
  modified:
    - ValetudoApp/ValetudoApp/Views/RobotDetailView.swift
    - ValetudoApp/ValetudoApp/Views/RobotListView.swift
    - ValetudoApp/ValetudoApp.xcodeproj/project.pbxproj
decisions:
  - "RobotManager passed explicitly via RobotDetailView init (not @EnvironmentObject) to allow @StateObject init in init()"
  - "RobotDetailView reduced from 30+ @State properties to 2 UI-only @State (showFullMap, showUpdateWarning)"
  - "ViewModels group added to pbxproj alongside Services, Models, Views"
metrics:
  duration: ~15min
  completed: 2026-03-27
  tasks_completed: 2
  files_modified: 4
---

# Phase 04 Plan 02: RobotDetailViewModel Extraction Summary

**One-liner:** Extracted all business logic from 1659-line RobotDetailView into dedicated @MainActor RobotDetailViewModel (394 lines), reducing View to declarative shell with 2 @State properties.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Create RobotDetailViewModel | 1dbb6e4 | ViewModels/RobotDetailViewModel.swift, project.pbxproj |
| 2 | Refactor RobotDetailView to consume ViewModel | 9b39d5a | RobotDetailView.swift, RobotListView.swift |

## What Was Built

### RobotDetailViewModel (new, 394 lines)

`@MainActor final class RobotDetailViewModel: ObservableObject` with:

- **@Published state:** segments, consumables, selectedSegments, selectedIterations, isLoading, fanSpeedPresets, waterUsagePresets, operationModePresets, capability flags (hasManualControl, hasAutoEmptyTrigger, hasMopDockClean, hasMopDockDry), update state (currentVersion, latestVersion, updateUrl, updaterState, isUpdating, showUpdateWarning, updateInProgress), statistics (lastCleaningStats, totalStats)
- **Computed properties:** status, isCleaning, isPaused, isRunning, api, currentFanSpeed, currentWaterUsage, currentOperationMode, hasConsumableWarning
- **Methods:** loadData(), refreshData(), loadLastCleaningStats(), startStatsPolling(), stopStatsPolling(), performAction(), locate(), cleanSelectedRooms(), toggleSegment(), setFanSpeed(), setWaterUsage(), setOperationMode(), triggerAutoEmpty(), triggerMopDockClean(), triggerMopDockDry(), resetConsumable(), startUpdate()

### RobotDetailView (refactored, 1128 lines from 1520)

- Replaced 30+ @State properties with `@StateObject private var viewModel: RobotDetailViewModel`
- Only 2 @State remain: `showFullMap` (sheet toggle), `showUpdateWarning` (alert toggle)
- All data binding via `viewModel.propertyName`
- All actions via `viewModel.methodName()`
- `.task { await viewModel.loadData() }`
- `.refreshable { await viewModel.refreshData() }`
- No direct `api.` calls anywhere in the view

### RobotListView (updated)

Updated `navigationDestination` to pass `robotManager` explicitly: `RobotDetailView(robot: robot, robotManager: robotManager)`

## Decisions Made

1. **Explicit init injection over @EnvironmentObject for ViewModel init:** `@StateObject` must be initialized in the View's `init()`. Since `@EnvironmentObject` is not accessible at init time, `robotManager` is now passed explicitly through `RobotDetailView.init(robot:robotManager:)`. The `@EnvironmentObject` propagation is replaced by explicit parameter passing at the `navigationDestination` callsite in `RobotListView`.

2. **ViewModels/ group created in project.pbxproj:** New Xcode group `VM000A2B3C4D5E6F7A8B9C0D` added alongside existing Services, Models, Views groups. File reference and build file entries added for `RobotDetailViewModel.swift`.

3. **showUpdateWarning moved to View (not ViewModel):** The alert toggle remains as @State in the View since it's purely UI presentation state. The actual update execution (`startUpdate()`) is on the ViewModel.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. All data is wired from the ViewModel to the View via @Published properties and computed properties.

## Verification

Build result: `BUILD SUCCEEDED`

Acceptance criteria satisfied:
- `grep "@MainActor" RobotDetailViewModel.swift` — present
- `grep "ObservableObject" RobotDetailViewModel.swift` — present
- `grep "@Published var segments" RobotDetailViewModel.swift` — present
- `grep "func loadData" RobotDetailViewModel.swift` — present
- `grep "RobotDetailViewModel" project.pbxproj` — present (4 occurrences)
- `grep "@StateObject.*RobotDetailViewModel" RobotDetailView.swift` — present
- `grep -c "@State" RobotDetailView.swift` — 4 (≤5, only UI toggles)
- `grep "viewModel.loadData|viewModel.refreshData" RobotDetailView.swift` — present
- No `try await api.` in View body — confirmed (count: 0)
