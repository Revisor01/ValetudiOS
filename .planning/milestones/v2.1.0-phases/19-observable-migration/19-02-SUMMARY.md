---
phase: 19-observable-migration
plan: "02"
subsystem: Views/ViewModels/Services
tags: [observable, swift-observation, migration, ios17, view-callsites]
dependency_graph:
  requires: [19-01-observable-class-definitions]
  provides: [complete-observable-migration]
  affects: [all-views, build]
tech_stack:
  added: []
  patterns: [@State for VM ownership, @Environment(Type.self) for injection, @Bindable for bindings, plain var for observed passing, @ObservationIgnored on @AppStorage]
key_files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/ValetudoApp.swift
    - ValetudoApp/ValetudoApp/ContentView.swift
    - ValetudoApp/ValetudoApp/Views/RobotDetailView.swift
    - ValetudoApp/ValetudoApp/Views/RobotDetailSections.swift
    - ValetudoApp/ValetudoApp/Views/MapView.swift
    - ValetudoApp/ValetudoApp/Views/MapSheetsView.swift
    - ValetudoApp/ValetudoApp/Views/RobotSettingsView.swift
    - ValetudoApp/ValetudoApp/Views/RobotSettingsSections.swift
    - ValetudoApp/ValetudoApp/Views/SettingsView.swift
    - ValetudoApp/ValetudoApp/Views/SupportView.swift
    - ValetudoApp/ValetudoApp/Views/AddRobotView.swift
    - ValetudoApp/ValetudoApp/Views/RobotListView.swift
    - ValetudoApp/ValetudoApp/Views/DoNotDisturbView.swift
    - ValetudoApp/ValetudoApp/Views/StatisticsView.swift
    - ValetudoApp/ValetudoApp/Views/IntensityControlView.swift
    - ValetudoApp/ValetudoApp/Views/ManualControlView.swift
    - ValetudoApp/ValetudoApp/Views/ConsumablesView.swift
    - ValetudoApp/ValetudoApp/Views/RoomsManagementView.swift
    - ValetudoApp/ValetudoApp/Views/TimersView.swift
    - ValetudoApp/ValetudoApp/Services/SupportManager.swift
    - ValetudoApp/ValetudoApp/Services/NotificationService.swift
    - ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift
    - ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift
decisions:
  - "@Bindable used for SupportView.supportManager (not plain var) because $supportManager.showThankYou binding is required"
  - "@ObservationIgnored added to @AppStorage properties in SupportManager and NotificationService — @Observable macro synthesizes backing storage that conflicts with @AppStorage's own backing"
  - "SupportView uses @Bindable at declaration site (not inline in body) — singleton reference, cleaner than local @Bindable in body"
metrics:
  duration: "~30 minutes"
  completed: "2026-04-01"
  tasks_completed: 2
  files_modified: 23
---

# Phase 19 Plan 02: Observable Migration — View Call-Sites Summary

All 19 View call-sites migrated from legacy ObservableObject patterns to @Observable patterns. @StateObject → @State, @ObservedObject → plain var (or @Bindable where bindings needed), @EnvironmentObject → @Environment(Type.self), .environmentObject() → .environment(). Build compiles successfully with zero legacy patterns remaining.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Kern-Views migrieren | f90244e | ValetudoApp.swift, ContentView.swift, RobotDetailView.swift, RobotDetailSections.swift, MapView.swift, MapSheetsView.swift, RobotSettingsView.swift |
| 2 | Restliche Views + Build-Verifikation | 61d178d | RobotSettingsSections.swift, SettingsView.swift, SupportView.swift, AddRobotView.swift, RobotListView.swift, DoNotDisturbView.swift, StatisticsView.swift, IntensityControlView.swift, ManualControlView.swift, ConsumablesView.swift, RoomsManagementView.swift, TimersView.swift + SupportManager.swift, NotificationService.swift, MapViewModel.swift, RobotDetailViewModel.swift |

## Verification

```
grep -rn "@StateObject" --include="*.swift" ValetudoApp/        → 0 results
grep -rn "@ObservedObject" --include="*.swift" ValetudoApp/     → 0 results
grep -rn "@EnvironmentObject" --include="*.swift" ValetudoApp/  → 0 results
grep -rn ".environmentObject(" --include="*.swift" ValetudoApp/ → 0 results
grep -rn "@Published" --include="*.swift" ValetudoApp/          → 0 results
grep -rn "ObservableObject" --include="*.swift" ValetudoApp/    → 0 results
grep -rn "@Observable" --include="*.swift" ValetudoApp/         → 11 results (1 per class)
grep -rn "@Environment(RobotManager.self)" --include="*.swift" ValetudoApp/ → 25 results
grep -rn ".environment(robotManager)" --include="*.swift" ValetudoApp/ → 3 results
xcodebuild → BUILD SUCCEEDED
```

## Migration Details

### Task 1: Core Views (7 files)

| File | Changes |
|------|---------|
| ValetudoApp.swift | 2x @StateObject → @State, 4x .environmentObject → .environment |
| ContentView.swift | 2x @EnvironmentObject → @Environment(Type.self), preview updated |
| RobotDetailView.swift | @StateObject → @State, StateObject(wrappedValue:) → State(initialValue:) |
| RobotDetailSections.swift | @ObservedObject → plain var (DeviceInfoSection) |
| MapView.swift | 4x @EnvironmentObject → @Environment (MapTabView, MapPreviewView, MapContentView, MapView), @StateObject → @State, StateObject → State, preview updated |
| MapSheetsView.swift | @ObservedObject → plain var (GoToPresetsSheet) |
| RobotSettingsView.swift | @EnvironmentObject → @Environment, @StateObject → @State, State(initialValue:), preview updated |

### Task 2: Remaining Views + Auto-fixes (16 files)

| File | Changes |
|------|---------|
| RobotSettingsSections.swift | 6x @EnvironmentObject → @Environment (AutoEmptyDockSettingsView, QuirksView, WifiSettingsView, MQTTSettingsView, NTPSettingsView, StationSettingsView) |
| SettingsView.swift | 2x @EnvironmentObject → @Environment (SettingsView + CreditsView), @ObservedObject → plain var, preview updated |
| SupportView.swift | @ObservedObject → @Bindable (binding needed for showThankYou alert) |
| AddRobotView.swift | @EnvironmentObject → @Environment, @StateObject → @State, @ObservedObject → plain var, preview updated |
| RobotListView.swift | @EnvironmentObject → @Environment, preview updated |
| DoNotDisturbView.swift | @EnvironmentObject → @Environment, preview updated |
| StatisticsView.swift | @EnvironmentObject → @Environment, preview updated |
| IntensityControlView.swift | @EnvironmentObject → @Environment, preview updated |
| ManualControlView.swift | @EnvironmentObject → @Environment, preview updated |
| ConsumablesView.swift | @EnvironmentObject → @Environment, preview updated |
| RoomsManagementView.swift | 2x @EnvironmentObject → @Environment (RoomsManagementView + RoomDetailView), preview updated |
| TimersView.swift | 2x @EnvironmentObject → @Environment (TimersView + AddTimerView), preview updated |
| SupportManager.swift | @ObservationIgnored on 3x @AppStorage (auto-fix: @Observable conflict) |
| NotificationService.swift | @ObservationIgnored on 5x @AppStorage (auto-fix: @Observable conflict) |
| MapViewModel.swift | Remove remaining @Published var isOffline (auto-fix: missed in Plan 19-01) |
| RobotDetailViewModel.swift | Remove 2x remaining @Published (valetudoVersion, systemHostInfo) (auto-fix: missed in 19-01) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] @Observable + @AppStorage conflict in SupportManager**
- **Found during:** Task 2 (build failure)
- **Issue:** `@Observable` macro synthesizes `_propertyName` backing storage that conflicts with `@AppStorage`'s own synthesized `_propertyName` backing. Results in "invalid redeclaration of synthesized property" compile error.
- **Fix:** Added `@ObservationIgnored` before all 3 `@AppStorage` properties in SupportManager.swift
- **Files modified:** ValetudoApp/ValetudoApp/Services/SupportManager.swift
- **Commit:** 61d178d

**2. [Rule 1 - Bug] @Observable + @AppStorage conflict in NotificationService**
- **Found during:** Task 2 (build failure, same root cause as above)
- **Fix:** Added `@ObservationIgnored` before all 5 `@AppStorage` properties in NotificationService.swift
- **Files modified:** ValetudoApp/ValetudoApp/Services/NotificationService.swift
- **Commit:** 61d178d

**3. [Rule 1 - Bug] Remaining @Published in MapViewModel (isOffline)**
- **Found during:** Task 2 (build failure — `Published<Bool>` type mismatch)
- **Issue:** One `@Published var isOffline` was not removed in Plan 19-01
- **Fix:** Removed `@Published` annotation
- **Files modified:** ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift
- **Commit:** 61d178d

**4. [Rule 1 - Bug] Remaining @Published in RobotDetailViewModel (valetudoVersion, systemHostInfo)**
- **Found during:** Task 2 (build failure — `Published<ValetudoVersion?>` type mismatch)
- **Issue:** Two `@Published` properties not removed in Plan 19-01
- **Fix:** Removed both `@Published` annotations
- **Files modified:** ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift
- **Commit:** 61d178d

**5. [Rule 2 - Missing functionality] SupportView needs @Bindable, not plain var**
- **Found during:** Task 2 (build failure — `$supportManager` not in scope)
- **Issue:** `SupportView` uses `$supportManager.showThankYou` binding. Plain `var` does not provide `$` access. @Bindable is needed.
- **Fix:** Changed `@ObservedObject private var supportManager` to `@Bindable private var supportManager`
- **Files modified:** ValetudoApp/ValetudoApp/Views/SupportView.swift
- **Commit:** 61d178d

**6. [Deviation - Naming] RobotSettingsSections.swift struct names differ from plan**
- **Found during:** Task 2 (inspection)
- **Issue:** Plan referenced VolumeSection/CarpetModeSection etc. but actual struct names are AutoEmptyDockSettingsView/QuirksView/WifiSettingsView/MQTTSettingsView/NTPSettingsView/StationSettingsView. Migration executed correctly against actual code.
- **Impact:** None — replace_all was used, all 6 instances migrated correctly.

## Known Stubs

None.

## Self-Check: PASSED
