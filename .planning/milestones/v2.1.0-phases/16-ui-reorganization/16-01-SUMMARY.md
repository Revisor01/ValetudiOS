---
phase: 16-ui-reorganization
plan: 01
subsystem: ui
tags: [swiftui, disclosuregroup, viewmodel, localization, robotdetail]

# Dependency graph
requires:
  - phase: 15-ui-wiring
    provides: UpdateService integration, download progress and error banner in RobotDetailView
provides:
  - DeviceInfoSection struct in RobotDetailSections.swift with DisclosureGroup showing Hardware/Valetudo/System data
  - valetudoVersion and systemHostInfo @Published properties on RobotDetailViewModel
  - loadDeviceInfo() async method integrated into loadData()
  - 10 device_info.* localization keys (DE/EN/FR)
  - ValetudoInfoView removed from RobotSettingsSections.swift and RobotSettingsView
affects: [17-background-monitoring, 18-map-cache, 19-observable-migration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Sub-view in RobotDetailSections.swift with @ObservedObject viewModel (Phase 11 decomposition pattern)
    - loadDeviceInfo() async in ViewModel mirrors loadRobotProperties() pattern
    - DisclosureGroup collapsed by default (isExpanded = false) — consistent with Statistics Section

key-files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift
    - ValetudoApp/ValetudoApp/Views/RobotDetailSections.swift
    - ValetudoApp/ValetudoApp/Views/RobotDetailView.swift
    - ValetudoApp/ValetudoApp/Views/RobotSettingsView.swift
    - ValetudoApp/ValetudoApp/Views/RobotSettingsSections.swift
    - ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings

key-decisions:
  - "Used device_info.* keys instead of reusing robot_properties.* — unified section gets its own key namespace"
  - "loadDeviceInfo() fetches version and hostInfo concurrently via async let v/h — mirrors loadRobotProperties pattern"
  - "ValetudoInfoView deleted entirely after migration — no dead code left in codebase"

patterns-established:
  - "Sub-view structs in RobotDetailSections.swift with @ObservedObject RobotDetailViewModel"
  - "DisclosureGroup collapsed by default (isExpanded = false)"

requirements-completed: [REORG-01, REORG-02]

# Metrics
duration: 7min
completed: 2026-04-01
---

# Phase 16 Plan 01: UI Reorganization Summary

**DeviceInfoSection DisclosureGroup (Hardware/Valetudo/System) in RobotDetailView, replacing robotPropertiesSection and deleting ValetudoInfoView from Settings**

## Performance

- **Duration:** ~7 min
- **Started:** 2026-04-01T22:14:29Z
- **Completed:** 2026-04-01T22:21:29Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added `valetudoVersion` and `systemHostInfo` @Published properties + `loadDeviceInfo()` async method to RobotDetailViewModel, concurrent API fetch integrated into `loadData()`
- Created `DeviceInfoSection` struct in RobotDetailSections.swift with collapsible DisclosureGroup showing Model/Manufacturer/Serial, Valetudo Version/Commit, Hostname/Uptime/CPU-Bar/Memory-Bar
- Removed ValetudoInfoView from Settings (NavigationLink + entire struct), replaced robotPropertiesSection with DeviceInfoSection in RobotDetailView

## Task Commits

1. **Task 1: ViewModel erweitern und DeviceInfoSection erstellen** - `aefdbac` (feat)
2. **Task 2: Verdrahtung und Aufraeum-Arbeiten** - `02de908` (feat)

## Files Created/Modified

- `ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift` - Added valetudoVersion/systemHostInfo properties and loadDeviceInfo() method
- `ValetudoApp/ValetudoApp/Views/RobotDetailSections.swift` - Added DeviceInfoSection struct with DisclosureGroup
- `ValetudoApp/ValetudoApp/Views/RobotDetailView.swift` - Replaced robotPropertiesSection with DeviceInfoSection, deleted old property
- `ValetudoApp/ValetudoApp/Views/RobotSettingsView.swift` - Removed ValetudoInfoView NavigationLink
- `ValetudoApp/ValetudoApp/Views/RobotSettingsSections.swift` - Deleted ValetudoInfoView struct (217 lines removed)
- `ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings` - Added 10 device_info.* keys (DE/EN/FR)

## Decisions Made

- Used `device_info.*` localization key namespace instead of reusing `robot_properties.*` keys — the merged section has a different scope and warrants its own namespace
- Deleted ValetudoInfoView entirely after migration — zero dead code policy
- CPU bar normalizes 1-minute load average, clamped to 1.0 (no core count available from API)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

Minor: Initial edit to remove ValetudoInfoView left behind the struct body after replacing only the struct header. Corrected with a line-range deletion script. Build succeeded on first attempt after correction.

## Next Phase Readiness

- Phase 16-01 complete — device info unified in RobotDetailView, Settings cleaned up
- Phases 17-19 can proceed in parallel (background monitoring, map cache, observable migration)
- No blockers

---
*Phase: 16-ui-reorganization*
*Completed: 2026-04-01*

## Self-Check: PASSED

- FOUND: RobotDetailSections.swift with `struct DeviceInfoSection`
- FOUND: RobotDetailViewModel.swift with `valetudoVersion`
- FOUND: 16-01-SUMMARY.md
- FOUND: commit aefdbac (Task 1)
- FOUND: commit 02de908 (Task 2)
- CONFIRMED: 0 remaining `ValetudoInfoView` references in Swift sources
