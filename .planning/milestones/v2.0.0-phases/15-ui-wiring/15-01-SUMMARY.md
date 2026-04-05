---
phase: 15-ui-wiring
plan: "01"
subsystem: update-ui
tags: [update, progress, error-handling, throttling, localization]
dependency_graph:
  requires: [14-01, 14-02]
  provides: [UI-01, UI-02, UI-03]
  affects: [RobotDetailView, UpdateService]
tech_stack:
  added: []
  patterns: [SwiftUI-ProgressView-linear, if-else-chain-ordering, throttle-via-Date]
key_files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/Services/UpdateService.swift
    - ValetudoApp/ValetudoApp/Views/RobotDetailView.swift
    - ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings
decisions:
  - if-else-chain reordered so .downloading is checked before updateInProgress — ensures linear ProgressView renders instead of generic spinner
  - downloadProgress reset to 0.0 in setPhase() via pattern-match on .downloading — avoids stale progress on error/retry
  - lastCheckDate reset to nil in reset() — enables retry after error triggers a fresh check within the same hour
metrics:
  duration: "~20min"
  completed: "2026-04-01"
  tasks_completed: 2
  files_modified: 3
---

# Phase 15 Plan 01: UI Wiring Summary

**One-liner:** Linear ProgressView mit Prozentzahl waehrend Download, rotes Error-Banner mit Retry-Button, und 1-Stunden-Throttle fuer Update-Checks.

## Tasks Completed

| # | Task | Commit | Key Changes |
|---|------|--------|-------------|
| 1 | UpdateService: downloadProgress + Throttle | c37fc60 | @Published downloadProgress, lastCheckDate throttle (3600s), setPhase() Reset-Logik |
| 2 | RobotDetailView: Progress + Error-Banner | 05e56e4 | Lineare ProgressView mit %, Error-Banner mit Retry, if-else-Kette umstrukturiert, 2 Lokalisierungskeys |

## What Was Built

### Task 1 — UpdateService (UI-01, UI-03)

`downloadProgress` (`Double`, 0.0–1.0) wird in `pollUntilReadyToApply()` nach jedem `getUpdaterState()`-Aufruf aus `state.metaData?.progress` berechnet. In `setPhase()` wird der Wert zurueckgesetzt wenn die neue Phase nicht `.downloading` ist. In `reset()` werden sowohl `downloadProgress` als auch `lastCheckDate` auf ihre Initialwerte gesetzt.

`lastCheckDate` (`Date?`) throttelt `checkForUpdates()`: Wenn weniger als 3600 Sekunden seit dem letzten Check vergangen sind, kehrt die Methode sofort zurueck. Nach erfolgreichem `setPhase(.checking)` wird `lastCheckDate = Date()` gesetzt. `reset()` setzt es auf `nil`, damit nach einem Fehler ein Retry moeglich ist.

### Task 2 — RobotDetailView (UI-01, UI-02)

**if-else-Kette neu geordnet** (vorher: updateInProgress zuerst — blockierte .downloading-Details):
1. `.updateAvailable` — Install-Button
2. `.downloading` — lineare ProgressView + Prozentzahl + "Nicht trennen" Hinweis
3. `.readyToApply` — Apply-Button
4. `updateInProgress` — generisches Spinner-Banner (checking/applying/rebooting)
5. `.error(let message)` — rotes Banner + Fehlermeldung + Retry-Button
6. GitHub-Fallback — Link zu GitHub-Release

**Error-Banner:** `exclamationmark.triangle.fill` Icon (rot), Fehlermeldung als `.caption`, Retry-Button ruft `viewModel.updateService?.reset()` auf.

**Lokalisierung:** `update.error` (de: "Update-Fehler") und `update.retry` (de: "Erneut versuchen") hinzugefuegt.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — downloadProgress ist real mit echter Roboter-API verdrahtet. Error-Banner zeigt echte Fehlermeldung aus der State Machine.

## Self-Check: PASSED

Files exist:
- FOUND: ValetudoApp/ValetudoApp/Services/UpdateService.swift
- FOUND: ValetudoApp/ValetudoApp/Views/RobotDetailView.swift
- FOUND: ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings

Commits exist:
- c37fc60 feat(15-01): add downloadProgress and lastCheckDate throttle to UpdateService
- 05e56e4 feat(15-01): wire download progress and error banner in RobotDetailView

Build: SUCCEEDED (iPhone 16 Simulator, iOS 18.5)
