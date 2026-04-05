---
phase: 13-state-consolidation
plan: 01
subsystem: UpdateService, RobotDetailViewModel, RobotDetailView, ValetudoInfoView
tags: [refactor, state-consolidation, update-service, clean-01, clean-02]
dependency_graph:
  requires: [Phase 12 UpdateService with UpdatePhase state machine]
  provides: [UpdateService as sole source of truth for version info and update state]
  affects: [RobotDetailView update banners, ValetudoInfoView version display]
tech_stack:
  added: []
  patterns: [Single Source of Truth via UpdateService, @Published private(set) for service properties]
key_files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/Services/UpdateService.swift
    - ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift
    - ValetudoApp/ValetudoApp/Views/RobotDetailView.swift
    - ValetudoApp/ValetudoApp/Views/RobotSettingsSections.swift
decisions:
  - UpdateService.loadVersionInfo() is public and not guarded by idle-state — version info is independent of the state machine
  - ValetudoInfoView retains @State version for commit-hash display; only GitHub release moved to UpdateService
metrics:
  duration: ~8 minutes
  completed: "2026-04-01"
  tasks_completed: 2
  files_modified: 4
---

# Phase 13 Plan 01: State Consolidation Summary

**One-liner:** UpdateService becomes sole source of truth for currentVersion, latestVersion, updateUrl — 6 redundant ViewModel @Published properties and duplicate ValetudoInfoView checkForUpdate() removed.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | UpdateService erweitern + ViewModel-Properties entfernen (CLEAN-01) | 4bed103 | UpdateService.swift, RobotDetailViewModel.swift, RobotDetailView.swift |
| 2 | ValetudoInfoView checkForUpdate() entfernen (CLEAN-02) | 1428123 | RobotSettingsSections.swift |

## What Was Done

### Task 1 (CLEAN-01)
- Added `@Published private(set) var currentVersion`, `latestVersion`, `updateUrl` to UpdateService
- Added `loadVersionInfo()` public method: fetches Valetudo version via API + GitHub latest release via URLSession
- Updated `reset()` to clear all three new properties
- Removed 6 redundant `@Published` properties from RobotDetailViewModel: `currentVersion`, `latestVersion`, `updateUrl`, `updaterState`, `isUpdating`, `showUpdateWarning`
- Replaced ViewModel's `checkForUpdate()` body (which did its own API fetches) with delegation: `setupUpdateService()` → `updateService?.loadVersionInfo()` → `updateService?.checkForUpdates()`
- RobotDetailView rewritten to use `viewModel.updateService?.phase` pattern matching instead of `viewModel.updaterState?.isUpdateAvailable` etc.

### Task 2 (CLEAN-02)
- Removed `@State private var latestRelease: GitHubRelease?` from ValetudoInfoView
- Removed `private func checkForUpdate()` entirely from ValetudoInfoView
- `loadInfo()` now calls `updateService?.loadVersionInfo()` instead of the local method
- `hasUpdate` fallback reads `updateService?.latestVersion` instead of `latestRelease?.tag_name`
- Version Info section "Latest" row reads from `updateService?.latestVersion` and `updateService?.updateUrl`
- Two force-unwraps (`URL(string: latest.html_url)!`) replaced with safe `if let` constructions

## Verification Results

```
grep isUpdating in ViewModels: 0
grep showUpdateWarning in ViewModels: 0
grep @Published var updaterState: 0
grep private func checkForUpdate in RobotSettingsSections: 0
grep currentVersion in UpdateService: 3 (property declaration + assignment + reset)
xcodebuild: BUILD SUCCEEDED
```

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. All version/update data is live from API and GitHub.

## Self-Check

- [x] ValetudoApp/ValetudoApp/Services/UpdateService.swift modified
- [x] ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift modified
- [x] ValetudoApp/ValetudoApp/Views/RobotDetailView.swift modified
- [x] ValetudoApp/ValetudoApp/Views/RobotSettingsSections.swift modified
- [x] Commit 4bed103 exists
- [x] Commit 1428123 exists

## Self-Check: PASSED
