---
phase: 17-background-monitoring
plan: "02"
subsystem: app-lifecycle
tags: [background-tasks, bgtask, app-delegate, scene-phase, ios-lifecycle]
dependency_graph:
  requires: [17-01]
  provides: [BGTask-Lifecycle-Wiring]
  affects: [ValetudoApp.swift]
tech_stack:
  added: []
  patterns: [BGTaskScheduler-registration-in-didFinishLaunching, ScenePhase-onChange-scheduling]
key_files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/ValetudoApp.swift
decisions:
  - "scenePhase via @Environment nutzen statt applicationDidEnterBackground — SwiftUI App-Lifecycle ruft AppDelegate-Callback nicht auf"
  - "onChange an WindowGroup haengen statt an innere Views — ein einziger Modifier deckt beide hasCompletedOnboarding-Branches ab"
  - "Info.plist Build-Artefakte nicht committen — xcodebuild substituiert Build-Variablen, project.yml ist Source of Truth"
metrics:
  duration: "8 minutes"
  completed: "2026-04-02T08:18:38Z"
  tasks_completed: 2
  files_modified: 1
---

# Phase 17 Plan 02: BGTask Lifecycle Wiring Summary

BGTask-Registrierung und Scheduling in AppDelegate und ValetudoApp struct verdrahtet — BGAppRefreshTask wird beim App-Start registriert, initial eingeplant und bei jedem Hintergrundwechsel via scenePhase neu eingeplant.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | AppDelegate BGTask-Registrierung und Scheduling verdrahten | 5be40b2 | ValetudoApp/ValetudoApp/ValetudoApp.swift |
| 2 | Build-Validierung und Xcode-Projekt-Referenz pruefen | (no file changes) | project.yml verified — glob includes all Swift files |

## What Was Built

- `import BackgroundTasks` in `ValetudoApp.swift`
- `BGTaskScheduler.shared.register(forTaskWithIdentifier: BackgroundMonitorService.taskIdentifier, using: nil)` in `AppDelegate.didFinishLaunchingWithOptions` mit Handler `BackgroundMonitorService.shared.handleBackgroundRefresh(task:)`
- Initiales `BackgroundMonitorService.shared.scheduleBackgroundRefresh()` in `didFinishLaunchingWithOptions`
- `@Environment(\.scenePhase) private var scenePhase` in `ValetudoApp` struct
- `.onChange(of: scenePhase)` an `WindowGroup` mit `scheduleBackgroundRefresh()` bei `.background`

## Verification Results

- `grep "import BackgroundTasks"` — Treffer
- `grep "BGTaskScheduler.shared.register"` — Treffer
- `grep "BackgroundMonitorService.taskIdentifier"` — Treffer
- `grep "BackgroundMonitorService.shared.handleBackgroundRefresh"` — Treffer
- `scheduleBackgroundRefresh` — 2 Treffer (didFinishLaunching + scenePhase)
- `grep "scenePhase"` — 2 Treffer
- `grep "\.background"` — Treffer
- `xcodebuild BUILD SUCCEEDED` — bestaetigt

## Deviations from Plan

None — plan executed exactly as written.

**Task 2 observation:** `xcodebuild` hat `Info.plist` modifiziert (Build-Variablen substituiert, Key-Reihenfolge geaendert). Da `BGTaskSchedulerPermittedIdentifiers` bereits in `project.yml` vorhanden war und der Eintrag nur verschoben wurde (kein inhaltlicher Unterschied), wurde `Info.plist` via `git checkout` wiederhergestellt. `project.yml` ist die Source of Truth.

## Known Stubs

None.

## Self-Check: PASSED

- File exists: `/Users/simonluthe/Documents/valetudo-app/ValetudoApp/ValetudoApp/ValetudoApp.swift` — FOUND
- Commit 5be40b2 exists — FOUND
- Build result: BUILD SUCCEEDED
