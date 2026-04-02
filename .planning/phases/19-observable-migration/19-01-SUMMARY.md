---
phase: 19-observable-migration
plan: "01"
subsystem: ViewModels/Services/Models
tags: [observable, swift-observation, migration, ios17]
dependency_graph:
  requires: []
  provides: [observable-viewmodels, observable-services, observable-models]
  affects: [all-views-using-@StateObject-@ObservedObject-@EnvironmentObject]
tech_stack:
  added: [Observation framework (built-in iOS 17+)]
  patterns: [@Observable macro, @ObservationIgnored, property-level observation tracking]
key_files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/Models/RobotState.swift
    - ValetudoApp/ValetudoApp/Helpers/ErrorRouter.swift
    - ValetudoApp/ValetudoApp/Services/NotificationService.swift
    - ValetudoApp/ValetudoApp/Services/SupportManager.swift
    - ValetudoApp/ValetudoApp/Services/NWBrowserService.swift
    - ValetudoApp/ValetudoApp/Services/NetworkScanner.swift
    - ValetudoApp/ValetudoApp/Services/UpdateService.swift
    - ValetudoApp/ValetudoApp/Services/RobotManager.swift
    - ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift
    - ValetudoApp/ValetudoApp/ViewModels/RobotSettingsViewModel.swift
    - ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift
decisions:
  - "@ObservationIgnored applied to private var Task properties, private let sseManager, and static weak var robotManagerRef — private let constants do not need it"
  - "presetStore in MapViewModel stays as plain var (no @Published needed) — nested @Observable is auto-tracked"
  - "private(set) access modifiers preserved exactly as-is on UpdateService phase, currentVersion, latestVersion, updateUrl, downloadProgress"
metrics:
  duration: "~20 minutes"
  completed: "2026-04-01"
  tasks_completed: 2
  files_modified: 11
---

# Phase 19 Plan 01: Observable Migration — Class Definitions Summary

All 11 ObservableObject classes migrated to @Observable macro using `import Observation`, removing `ObservableObject` conformance, removing all `@Published` annotations, and adding `@ObservationIgnored` to infrastructure properties.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Leaf-Klassen migrieren | 6a133ef | RobotState.swift, ErrorRouter.swift, NotificationService.swift, SupportManager.swift, NWBrowserService.swift |
| 2 | Service/ViewModel-Klassen migrieren | 58f9219 | NetworkScanner.swift, UpdateService.swift, RobotManager.swift, RobotDetailViewModel.swift, RobotSettingsViewModel.swift, MapViewModel.swift |

## Verification

```
grep -rn "ObservableObject" --include="*.swift" ValetudoApp/  → 0 results
grep -rn "@Published" --include="*.swift" ValetudoApp/        → 0 results
grep -rn "@Observable" --include="*.swift" ValetudoApp/       → 11 results (1 per class)
grep -rn "import Observation" --include="*.swift" ValetudoApp/ → 11 results (all migrated files)
```

## Migration Details

### Task 1: Leaf Classes (5 classes)

| Class | File | Changes |
|-------|------|---------|
| GoToPresetStore | Models/RobotState.swift | `class GoToPresetStore: ObservableObject` → `@Observable class GoToPresetStore`, 1x @Published removed |
| ErrorRouter | Helpers/ErrorRouter.swift | `final class ErrorRouter: ObservableObject` → `@Observable final class ErrorRouter`, 1x @Published removed |
| NotificationService | Services/NotificationService.swift | `class NotificationService: ObservableObject` → `@Observable class NotificationService`, 1x @Published removed, `@ObservationIgnored` on `static weak var robotManagerRef` |
| SupportManager | Services/SupportManager.swift | `class SupportManager: ObservableObject` → `@Observable class SupportManager`, 4x @Published removed |
| NWBrowserService | Services/NWBrowserService.swift | `final class NWBrowserService: ObservableObject` → `@Observable final class NWBrowserService`, 2x @Published removed, `private(set)` preserved, `@ObservationIgnored` on `browser: NWBrowser?` |

### Task 2: Service and ViewModel Classes (6 classes)

| Class | File | Changes |
|-------|------|---------|
| NetworkScanner | Services/NetworkScanner.swift | 3x @Published removed, `@ObservationIgnored` on scanTask + browserService |
| UpdateService | Services/UpdateService.swift | 5x `@Published private(set)` → `private(set)` (access modifier preserved), `@ObservationIgnored` on pollingTask + backgroundTaskID + lastCheckDate |
| RobotManager | Services/RobotManager.swift | 3x @Published removed, `@ObservationIgnored` on apis + refreshTask + previousStates + lastConsumableCheck + sseManager |
| RobotDetailViewModel | ViewModels/RobotDetailViewModel.swift | 17x @Published removed, `@ObservationIgnored` on statsPollingTask |
| RobotSettingsViewModel | ViewModels/RobotSettingsViewModel.swift | ~45x @Published removed |
| MapViewModel | ViewModels/MapViewModel.swift | ~35x @Published removed, `@ObservationIgnored` on refreshTask, presetStore stays as plain var |

## Decisions Made

1. **@ObservationIgnored scope**: Applied to `var` infrastructure properties (Task handles, NWBrowser, SSEManager, dictionaries). Not applied to `let` constants — they are never mutated so they don't trigger observation regardless.

2. **presetStore in MapViewModel**: Kept as plain `var presetStore = GoToPresetStore()` without any wrapper. With `@Observable`, nested `@Observable` instances are auto-tracked by SwiftUI.

3. **private(set) on UpdateService**: The `@Published private(set)` pattern splits into just `private(set)` — access modifier is orthogonal to `@Published` and must be preserved.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — this is a pure mechanical migration of class definitions. No UI wiring, no new data sources.

## Next Steps (Plan 19-02)

View call sites must be updated atomically:
- `@StateObject` → `@State` (8 sites)
- `@ObservedObject` → plain `var` (4 sites)
- `@EnvironmentObject` → `@Environment(Type.self)` (15+ sites)
- `.environmentObject()` → `.environment()` (injection sites)

Note: Views still compile with deprecation warnings until Plan 19-02 is complete.

## Self-Check: PASSED
