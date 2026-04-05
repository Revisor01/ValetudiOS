---
phase: 08-test-coverage
plan: "01"
subsystem: testing
tags: [unit-tests, viewmodels, xctest, swift]
dependency_graph:
  requires: []
  provides: [TEST-01]
  affects: [ValetudoAppTests]
tech_stack:
  added: []
  patterns: [XCTestCase, @MainActor-per-method, JSONDecoder-for-structs, direct-property-mutation]
key_files:
  created:
    - ValetudoApp/ValetudoAppTests/RobotDetailViewModelTests.swift
    - ValetudoApp/ValetudoAppTests/RobotSettingsViewModelTests.swift
    - ValetudoApp/ValetudoAppTests/MapViewModelTests.swift
  modified: []
decisions:
  - "@MainActor per test method (not class) — matches existing test pattern, avoids actor isolation issues in XCTest"
  - "RobotStatus constructed directly in tests — struct has memberwise init, no mock needed"
  - "Consumables and RobotAttributes decoded via JSONDecoder — avoids fileprivate init access issues, matches production data flow"
  - "MapViewModel init requires isFullscreen: Bool parameter — not shown in plan interface, read from MapViewModel.swift source"
metrics:
  duration: "2min"
  completed_date: "2026-03-28"
  tasks_completed: 2
  files_created: 3
  files_modified: 0
---

# Phase 8 Plan 1: ViewModel Unit Tests Summary

Three new XCTestCase files covering RobotDetailViewModel state transitions, RobotSettingsViewModel default state, and MapViewModel edit-mode logic — no API mocking required.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | RobotDetailViewModel Tests | 28921d0 | ValetudoAppTests/RobotDetailViewModelTests.swift |
| 2 | RobotSettingsViewModel + MapViewModel Tests | 404574c | ValetudoAppTests/RobotSettingsViewModelTests.swift, ValetudoAppTests/MapViewModelTests.swift |

## What Was Built

- **RobotDetailViewModelTests.swift** (7 tests): Init defaults, capability flags (with DebugConfig guard), `hasConsumableWarning` for empty/low-remaining lists, `isCleaning`/`isPaused`/`isRunning` for "cleaning", "docked", and "returning" status states
- **RobotSettingsViewModelTests.swift** (4 tests): Init default values (volume=80, isLoading=false, empty lists), capability flags guard, voicePacks empty check, mapSnapshots + isRestoringSnapshot checks
- **MapViewModelTests.swift** (5 tests): Init defaults (isLoading=true, map=nil, editMode=.none), capability flags, `cancelEditMode()` resets editMode + drawnZones, isCleaning default, errorMessage settable

## Decisions Made

- `@MainActor` annotation applied per test method (not class) — consistent with existing pattern in MapLayerTests/KeychainStoreTests and avoids Swift concurrency isolation issues in XCTest
- `RobotStatus(isOnline:attributes:info:)` used directly — public memberwise-style init found in RobotManager.swift
- `Consumable` and `RobotAttribute` decoded via JSONDecoder — avoids needing access to internal initializers, matches production data flow
- `MapViewModel` requires `isFullscreen: Bool` in init — not shown in plan interface spec, discovered from MapViewModel.swift source

## Deviations from Plan

### Minor Interface Deviation (No Impact)

**Found during:** Task 2

**Issue:** Plan interface spec showed `MapViewModel.init(robot:robotManager:)` but actual init signature is `init(robot:robotManager:isFullscreen:)`.

**Fix:** Added `isFullscreen: false` parameter to all MapViewModel instantiations in tests.

**Files modified:** ValetudoApp/ValetudoAppTests/MapViewModelTests.swift

No other deviations — plan executed correctly.

## Known Stubs

None. All test files exercise real ViewModel properties; no placeholder data flows to rendering.

## Verification

- `grep -c "func test" RobotDetailViewModelTests.swift` → 7 (plan requires 6+)
- `grep -c "func test" RobotSettingsViewModelTests.swift` → 4 (plan requires 4+)
- `grep -c "func test" MapViewModelTests.swift` → 5 (plan requires 5+)
- All three files contain `@testable import ValetudoApp` and `XCTestCase`
- No existing test files were modified
- No `loadData()`, `loadSettings()`, or async API-calling methods used

## Self-Check: PASSED
