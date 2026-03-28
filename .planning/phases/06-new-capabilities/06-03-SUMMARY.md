---
phase: 06-new-capabilities
plan: "03"
subsystem: settings
tags: [mop-dock, drying-time, preset-picker, capability-gate]
dependency_graph:
  requires: []
  provides: [MopDockMopDryingTimeControlCapability integration]
  affects: [RobotSettingsView, StationSettingsView, RobotSettingsViewModel, ValetudoAPI]
tech_stack:
  added: []
  patterns: [PresetControlRequest reuse, capability-gated section, isInitialLoad guard]
key_files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift
    - ValetudoApp/ValetudoApp/ViewModels/RobotSettingsViewModel.swift
    - ValetudoApp/ValetudoApp/Views/RobotSettingsView.swift
    - ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings
decisions:
  - "settingsLogger used in StationSettingsView (local view) for drying time error, matching existing pattern in that struct"
metrics:
  duration: 5min
  completed_date: "2026-03-28"
  tasks_completed: 2
  files_modified: 4
requirements: [CAP-03]
---

# Phase 06 Plan 03: MopDockDryingTime Integration Summary

MopDockMopDryingTimeControlCapability preset-picker via GET/PUT endpoints, capability-gated in the Mop-Dock-Section with isInitialLoad guard.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | MopDockDryingTime API-Methoden | bb8fa92 | ValetudoAPI.swift |
| 2 | MopDockDryingTime ViewModel-State und View-Picker | 24911b5 | RobotSettingsViewModel.swift, RobotSettingsView.swift, Localizable.xcstrings |

## What Was Built

### ValetudoAPI.swift
- `getMopDockDryingTimePresets()` — GET `/robot/capabilities/MopDockMopDryingTimeControlCapability/presets`
- `setMopDockDryingTime(preset:)` — PUT `/robot/capabilities/MopDockMopDryingTimeControlCapability/preset`
- Reuses existing `PresetControlRequest` struct

### RobotSettingsViewModel.swift
- `@Published var hasMopDockDryingTime` — capability flag
- `@Published var mopDockDryingTimePresets: [String]`
- `@Published var currentMopDockDryingTime: String`
- Capability check in `loadSettings()`: `capabilities.contains("MopDockMopDryingTimeControlCapability")`
- Preset loading with `PresetSelectionStateAttribute` lookup (`mop_dock_mop_drying_time`)
- `setMopDockDryingTime(_ preset: String) async` action method

### RobotSettingsView.swift (StationSettingsView)
- Local `@State` properties for `hasMopDockDryingTime`, `mopDockDryingTimePresets`, `currentMopDockDryingTime`
- Capability check and preset loading in `loadSettings()`
- `setDryingTime(_ preset: String) async` private action
- DryingTime Picker in Mop-Dock-Section after WashTemperature Picker, double-gated (`hasMopDockDryingTime && !mopDockDryingTimePresets.isEmpty`)
- `onChange` calls `setDryingTime()` with `isInitialLoad` guard
- Section visibility, "no settings", and overlay conditions updated

### Localizable.xcstrings
- `"mop_dock.drying_time_label"` — `"Trocknungszeit"` (de), `"Drying Time"` (en)

## Deviations from Plan

None — plan executed exactly as written. The plan mentioned "RobotSettingsView" in some places, but the Mop-Dock-Section lives in `StationSettingsView` (a private struct in RobotSettingsView.swift). Both the ViewModel-based `RobotSettingsView` "no settings" condition and the local-state `StationSettingsView` were updated accordingly.

## Known Stubs

None.

## Self-Check: PASSED
