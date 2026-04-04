---
phase: 23-error-handling-robustness-patterns
plan: 02
subsystem: settings-viewmodels
tags: [debt, robustness, caching, state-management]
dependency_graph:
  requires: [23-01]
  provides: [settingsLoaded-pattern, capabilities-cache]
  affects: [RobotSettingsViewModel, RobotDetailViewModel, RobotManager, UpdateService]
tech_stack:
  added: []
  patterns: [Two-Phase-Load, TTL-Cache, Callback-Injection]
key_files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/ViewModels/RobotSettingsViewModel.swift
    - ValetudoApp/ValetudoApp/Views/RobotSettingsView.swift
    - ValetudoApp/ValetudoApp/Views/RobotSettingsSections.swift
    - ValetudoApp/ValetudoApp/Services/RobotManager.swift
    - ValetudoApp/ValetudoApp/Services/UpdateService.swift
    - ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift
decisions:
  - "Two-Phase-Load via settingsLoaded statt isInitialLoad — invertierte Semantik vermeidet false-positives beim Re-Load"
  - "onRebootComplete Callback in UpdateService — minimal-invasiv, kein init-Umbau, keine Call-Site-Aenderungen"
  - "applyCapabilities() als Hilfsmethode extrahiert — Cache-Pfad und API-Pfad nutzen denselben Code"
metrics:
  duration_seconds: 354
  completed: 2026-04-04
  tasks_completed: 2
  files_modified: 6
---

# Phase 23 Plan 02: Two-Phase-Load Pattern und Capabilities TTL Cache Summary

**One-liner:** settingsLoaded-Two-Phase-Pattern ersetzt isInitialLoad, 24h TTL Capabilities-Cache in RobotManager mit OTA-Reboot-Invalidierung via onRebootComplete-Callback.

## Objective

DEBT-05 (isInitialLoad Race-Condition bei Re-Loads) und DEBT-06 (redundante Capabilities API-Calls, kein Refresh nach OTA) beseitigt.

## Tasks Completed

### Task 1: Two-Phase-Load-Pattern (DEBT-05)

**RobotSettingsViewModel.swift:**
- `isInitialLoad = true` ersetzt durch `private(set) var settingsLoaded = false`
- `loadSettings()`: `settingsLoaded = false` am Anfang, `settingsLoaded = true` am Ende via `defer`
- Entfernt: veraltete `isInitialLoad = false` Zeile am Ende von loadSettings()

**RobotSettingsView.swift:**
- 9 onChange-Guards: `!viewModel.isInitialLoad` -> `viewModel.settingsLoaded`
- Zeilen mit Zusatzbedingung: `!isInitialLoad && !newValue.isEmpty` -> `settingsLoaded && !newValue.isEmpty`

**RobotSettingsSections.swift (StationSettingsView):**
- `@State private var isInitialLoad = true` -> `@State private var stationLoaded = false`
- 4 onChange-Guards mit stationLoaded
- `loadSettings()`: stationLoaded = false am Anfang, stationLoaded = true am Ende (explizit, kein defer da @State-View)

### Task 2: Capabilities TTL Cache + OTA Invalidierung (DEBT-06)

**RobotManager.swift:**
- `capabilitiesCache: [UUID: [String]]` und `capabilitiesCacheDate: [UUID: Date]` als @ObservationIgnored
- `capabilitiesTTL: TimeInterval = 86400` (24 Stunden)
- Drei Methoden: `cachedCapabilities(for:)`, `cacheCapabilities(_:for:)`, `invalidateCapabilities(for:)`

**UpdateService.swift:**
- `var onRebootComplete: (() -> Void)?` als optionale Callback-Property
- In `pollUntilReboot()`: `onRebootComplete?()` nach `setPhase(.idle)` bei erfolgreichem Reboot

**RobotDetailViewModel.swift:**
- `loadCapabilities()`: Cache-Check vor API-Call via `robotManager.cachedCapabilities(for:)`
- `applyCapabilities(_ capabilities: [String])` als private Hilfsmethode extrahiert
- `setupUpdateService()`: `onRebootComplete` Callback setzt `robotManager.invalidateCapabilities(for: robot.id)`

**RobotSettingsViewModel.swift:**
- `loadSettings()`: Cache-Check vor `api.getCapabilities()` — gleicher Cache, anderes ViewModel

## Verification

| Check | Result |
|-------|--------|
| `isInitialLoad` in App | 0 matches |
| `settingsLoaded = false` in ViewModel | 1 match (am Anfang loadSettings()) |
| `invalidateCapabilities` in DetailViewModel | 1 match (in onRebootComplete) |
| `onRebootComplete` in UpdateService | 2 matches (property + call) |
| `cachedCapabilities` in ViewModels | 2 matches (Detail + Settings) |
| Xcode Build | BUILD SUCCEEDED |

## Deviations from Plan

None — plan executed exactly as written.

## Commits

| Hash | Task | Description |
|------|------|-------------|
| fef9410 | Task 1 | feat(23-02): replace isInitialLoad with Two-Phase-Load pattern (DEBT-05) |
| a1e895f | Task 2 | feat(23-02): add Capabilities TTL cache and OTA invalidation (DEBT-06) |

## Known Stubs

None.

## Self-Check: PASSED

Files exist:
- ValetudoApp/ValetudoApp/ViewModels/RobotSettingsViewModel.swift — FOUND
- ValetudoApp/ValetudoApp/Views/RobotSettingsView.swift — FOUND
- ValetudoApp/ValetudoApp/Views/RobotSettingsSections.swift — FOUND
- ValetudoApp/ValetudoApp/Services/RobotManager.swift — FOUND
- ValetudoApp/ValetudoApp/Services/UpdateService.swift — FOUND
- ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift — FOUND

Commits exist:
- fef9410 — FOUND
- a1e895f — FOUND
