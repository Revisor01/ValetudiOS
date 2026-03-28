---
phase: 06-new-capabilities
plan: 02
subsystem: api
tags: [swift, swiftui, valetudo, capabilities, auto-empty-dock]

# Dependency graph
requires:
  - phase: 06-new-capabilities
    provides: VoicePack integration pattern (06-01) as structural reference for new capabilities
provides:
  - AutoEmptyDockAutoEmptyDurationControlCapability vollstaendig integriert
  - getAutoEmptyDockDurationPresets() und setAutoEmptyDockDuration(preset:) in ValetudoAPI.swift
  - hasAutoEmptyDockDuration Capability-Flag in ViewModel und StationSettingsView
  - Duration-Picker in Auto-Empty-Section capability-gated
  - Lokalisierungskey auto_empty.duration_label fuer de + en
affects: [06-new-capabilities, 07-bugfixes-robustness]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - AutoEmptyDockDuration folgt exakt dem Interval-Pattern (PresetControlRequest, GET presets / PUT preset)
    - StationSettingsView hat eigene lokale State-Properties fuer Station-Capabilities (kein RobotSettingsViewModel)
    - displayNameFor* Hilfsmethode in View fuer preset-spezifische Lokalisierung

key-files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift
    - ValetudoApp/ValetudoApp/ViewModels/RobotSettingsViewModel.swift
    - ValetudoApp/ValetudoApp/Views/RobotSettingsView.swift
    - ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings

key-decisions:
  - "StationSettingsView nutzt lokale @State statt RobotSettingsViewModel — Duration-Picker wurde dort analog implementiert, nicht im Haupt-ViewModel-Picker"
  - "displayNameForAutoEmptyDockDuration() nutzt preset.* l10n-Keys (preset.min, preset.low, etc.) statt eigenem Enum"

patterns-established:
  - "Duration-Picker in StationSettingsView: lokale State-Properties analog zu Wash-Temperature-Picker"

requirements-completed: [CAP-02]

# Metrics
duration: 7min
completed: 2026-03-28
---

# Phase 06 Plan 02: AutoEmptyDockDuration Summary

**AutoEmptyDockAutoEmptyDurationControlCapability mit API-Methoden, lokalem State und Preset-Picker in der Auto-Empty-Section integriert**

## Performance

- **Duration:** 7 min
- **Started:** 2026-03-28T14:48:00Z
- **Completed:** 2026-03-28T14:55:02Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- API-Methoden `getAutoEmptyDockDurationPresets()` und `setAutoEmptyDockDuration(preset:)` in ValetudoAPI.swift nach Interval-Pattern
- `hasAutoEmptyDockDuration`, `autoEmptyDockDurationPresets`, `currentAutoEmptyDockDuration` in RobotSettingsViewModel als @Published
- Duration-Picker in StationSettingsView Auto-Empty-Section mit isInitialLoad-Guard und displayNameForAutoEmptyDockDuration() Helper
- Lokalisierungskey `auto_empty.duration_label` fuer Deutsch ("Absaugdauer") und Englisch ("Suction Duration")

## Task Commits

1. **Task 1: AutoEmptyDockDuration API-Methoden** - `ead8583` (feat)
2. **Task 2: ViewModel-State und View-Picker** - `fd536ed` (feat)

## Files Created/Modified

- `/Users/simonluthe/Documents/valetudo-app/ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift` - Zwei neue API-Methoden fuer Duration-Capability
- `/Users/simonluthe/Documents/valetudo-app/ValetudoApp/ValetudoApp/ViewModels/RobotSettingsViewModel.swift` - hasAutoEmptyDockDuration Flag, Presets/CurrentDuration Properties, setAutoEmptyDockDuration() Action
- `/Users/simonluthe/Documents/valetudo-app/ValetudoApp/ValetudoApp/Views/RobotSettingsView.swift` - Duration-Picker in StationSettingsView, lokale State-Properties, Helper-Methoden
- `/Users/simonluthe/Documents/valetudo-app/ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings` - auto_empty.duration_label Key

## Decisions Made

**StationSettingsView-Architektur:** Die Auto-Empty-Section befindet sich in `StationSettingsView` (nicht in `RobotSettingsView`), die eigene `@State`-Properties nutzt statt `RobotSettingsViewModel`. Der Duration-Picker wurde analog zum Wash-Temperature-Picker mit lokalen States implementiert. ViewModel-Properties wurden trotzdem hinzugefuegt (fuer zukuenftige Nutzung und Plan-Compliance), aber der tatsaechliche View-Picker liest aus lokalem State.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Architecture] Duration-Picker in StationSettingsView statt via RobotSettingsViewModel**
- **Found during:** Task 2 (View-Picker Integration)
- **Issue:** Plan ging davon aus, dass der Picker ueber `viewModel` (RobotSettingsViewModel) in RobotSettingsView eingebunden wird. Die Auto-Empty-Section befindet sich jedoch in `StationSettingsView`, einer separaten View mit eigenen @State-Properties (kein ViewModel).
- **Fix:** Picker mit lokalen @State-Properties in StationSettingsView implementiert, analog zum WashTemperature-Picker. RobotSettingsViewModel erhielt trotzdem die Properties (Plan-Compliance, Zukunftsverwendung).
- **Files modified:** RobotSettingsView.swift
- **Verification:** BUILD SUCCEEDED
- **Committed in:** fd536ed (Task 2)

---

**Total deviations:** 1 auto-fixed (architecture adaptation)
**Impact on plan:** Adaptation notwendig wegen tatsaechlicher View-Struktur. Alle must_have truths erfuellt — Picker sichtbar, capability-gated, onChange ruft setAutoEmptyDockDuration auf.

## Issues Encountered

None — Build beim ersten Versuch erfolgreich.

## User Setup Required

None - keine externe Konfiguration erforderlich.

## Next Phase Readiness

- AutoEmptyDockDuration vollstaendig integriert
- Naechste Capability: Plan 06-03 (MopDockDrying oder RobotProperties)

---
*Phase: 06-new-capabilities*
*Completed: 2026-03-28*
