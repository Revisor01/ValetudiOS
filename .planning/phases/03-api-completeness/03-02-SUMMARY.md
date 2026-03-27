---
phase: 03-api-completeness
plan: 02
subsystem: notifications, settings-ui
tags: [notifications, map-management, app-delegate, swiftui]
dependency_graph:
  requires: [03-01]
  provides: [notification-actions, map-snapshot-ui, pending-map-change-ui]
  affects: [RobotSettingsView, NotificationService, ValetudoApp]
tech_stack:
  added: [UNUserNotificationCenterDelegate, UIApplicationDelegateAdaptor]
  patterns: [AppDelegate bridge pattern, static weak reference for cross-actor access]
key_files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/ValetudoApp.swift
    - ValetudoApp/ValetudoApp/Services/NotificationService.swift
    - ValetudoApp/ValetudoApp/Views/RobotSettingsView.swift
decisions:
  - "Static weak var robotManagerRef on NotificationService set via onAppear — avoids singleton coupling while staying MainActor-safe"
  - "completionHandler() called immediately in didReceive, Task runs independently — per pitfall 6"
  - "No Map Snapshot create button — snapshots created automatically by firmware (pitfall 3)"
  - "ErrorRouter added as EnvironmentObject to RobotSettingsView — passed via existing ContentView environment chain"
metrics:
  duration: 2min
  completed: 2026-03-27
  tasks_completed: 2
  files_modified: 3
---

# Phase 03 Plan 02: Notification Actions and Map Management UI Summary

**One-liner:** AppDelegate wires UNUserNotificationCenterDelegate to dispatch GO_HOME/LOCATE to ValetudoAPI; RobotSettingsView gains capability-gated Map Snapshot list and Pending Map Change Accept/Reject UI.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Notification-Actions via AppDelegate und NotificationService | 265a6d8 | ValetudoApp.swift, NotificationService.swift |
| 2 | Map-Snapshot und Pending-Map-Change Sections in RobotSettingsView | e80bab0 | RobotSettingsView.swift |

## What Was Built

### Task 1: Notification Actions

- **AppDelegate class** added to `ValetudoApp.swift` implementing `UIApplicationDelegate` and `UNUserNotificationCenterDelegate`
- `UIApplicationDelegateAdaptor(AppDelegate.self)` registered in `ValetudoApp` struct
- `userNotificationCenter(_:didReceive:withCompletionHandler:)` dispatches action identifier to `NotificationService.handleNotificationResponse` via a `@MainActor` Task, then calls `completionHandler()` immediately
- **`handleNotificationResponse(actionIdentifier:)`** added to `NotificationService`: resolves first available robot via `robotManagerRef`, dispatches `basicControl(action: .home)` for GO_HOME and `locate()` for LOCATE
- **`static weak var robotManagerRef: RobotManager?`** set via `.onAppear` in both `ContentView` and `OnboardingView` branches

### Task 2: Map Management UI

- **New `@State` properties** in `RobotSettingsView`: `hasMapSnapshot`, `hasPendingMapChange`, `mapSnapshots`, `pendingMapChangeEnabled`, `isRestoringSnapshot`, `isHandlingMapChange`
- **Capability detection** in `loadSettings()`: checks `MapSnapshotCapability` and `PendingMapChangeHandlingCapability`
- **Data loading**: `getMapSnapshots()` and `getPendingMapChange()` called after capability detection, errors silently ignored
- **Map Snapshots Section**: capability-gated list with per-snapshot Restore button, no create button (firmware creates snapshots automatically)
- **Pending Map Change Section**: shown only when `hasPendingMapChange && pendingMapChangeEnabled`; Accept and Reject buttons call `handlePendingMapChange(action:)` and clear the enabled flag on success
- **`ErrorRouter`** added as `@EnvironmentObject` to `RobotSettingsView` for error presentation

## Deviations from Plan

### Auto-added Missing Functionality

**1. [Rule 2 - Missing] Added ErrorRouter environment object to RobotSettingsView**
- **Found during:** Task 2
- **Issue:** Plan uses `errorRouter.show(error)` in Map Snapshot/Pending Map Change task handlers, but `RobotSettingsView` had no `errorRouter` reference
- **Fix:** Added `@EnvironmentObject var errorRouter: ErrorRouter` — already in environment chain from ContentView
- **Files modified:** `ValetudoApp/ValetudoApp/Views/RobotSettingsView.swift`
- **Commit:** e80bab0

## Known Stubs

None — all UI sections load from API methods implemented in Plan 01. Capability flags gate display; empty snapshot list shows placeholder text.

## Self-Check: PASSED

- [x] ValetudoApp.swift contains `UIApplicationDelegateAdaptor` and `UNUserNotificationCenterDelegate`
- [x] NotificationService.swift contains `handleNotificationResponse`, `GO_HOME`, `LOCATE`, `robotManagerRef`
- [x] RobotSettingsView.swift contains `hasMapSnapshot`, `hasPendingMapChange`, `MapSnapshotCapability`, `PendingMapChangeHandlingCapability`, `restoreMapSnapshot`, `handlePendingMapChange`
- [x] Commits 265a6d8 and e80bab0 exist
- [x] Build compiles cleanly
