---
phase: 12-state-machine-foundation
plan: "02"
subsystem: ui
tags: [swift, swiftui, updateservice, statemachine, mvvm]

# Dependency graph
requires:
  - phase: 12-01
    provides: UpdateService mit UpdatePhase-State-Machine und checkForUpdates/startDownload/startApply API

provides:
  - RobotDetailViewModel delegiert Update-Operationen an UpdateService
  - ValetudoInfoView liest updateService?.phase statt eigener @State-Kopie
  - RobotSettingsView und RobotDetailView reichen UpdateService durch die View-Hierarchie
  - updateInProgress als Computed Property auf UpdateService.phase (kein @Published mehr)

affects:
  - 12-03 (falls vorhanden — weitere Verdrahtung)
  - 13-state-consolidation (wird diese Properties finalisieren/entfernen)
  - 14-apply-hardening

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "UpdateService per Init-Parameter durch View-Hierarchie durchreichen"
    - "Computed Properties als Proxies auf ObservableObject-Subservice"
    - "Lazy Init von UpdateService via setupUpdateService() im ViewModel"

key-files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift
    - ValetudoApp/ValetudoApp/Views/RobotSettingsSections.swift
    - ValetudoApp/ValetudoApp/Views/RobotSettingsView.swift
    - ValetudoApp/ValetudoApp/Views/RobotDetailView.swift

key-decisions:
  - "ValetudoInfoView erhält UpdateService als optionalen Init-Parameter (nicht als EnvironmentObject) — explizites Ownership"
  - "updaterState @State in ValetudoInfoView entfernt — UpdateService ist jetzt Single Source of Truth (STATE-04)"
  - "updateInProgress als Computed Property — nicht mehr @Published"

patterns-established:
  - "Service-Delegation: ViewModel initialisiert Service lazy (setupUpdateService) vor erstem Gebrauch"
  - "View-Hierarchie Durchreich-Muster: RobotDetailView → RobotSettingsView → ValetudoInfoView per parameter"

requirements-completed:
  - STATE-04

# Metrics
duration: 20min
completed: "2026-04-01"
---

# Phase 12 Plan 02: State-Machine-Foundation Verdrahtung Summary

**UpdateService als Single Source of Truth verdrahtet — RobotDetailViewModel delegiert, ValetudoInfoView liest dieselbe Instanz (STATE-04 erfüllt)**

## Performance

- **Duration:** 20 min
- **Started:** 2026-04-01T17:00:00Z
- **Completed:** 2026-04-01T17:20:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- RobotDetailViewModel hält UpdateService, delegiert checkForUpdate() und startUpdate() daran
- ValetudoInfoView liest UpdateService?.phase statt eigener @State-Kopie — doppelter State eliminiert
- updateInProgress ist jetzt Computed Property auf UpdateService.phase (kein @Published mehr)
- RobotSettingsView und RobotDetailView reichen UpdateService als Parameter durch die View-Hierarchie

## Task Commits

Jeder Task wurde atomar committet:

1. **Task 1: RobotDetailViewModel — UpdateService-Delegation und Proxy-Properties** - `7c13230` (feat)
2. **Task 2: ValetudoInfoView — UpdateService injizieren und eigene State-Kopie entfernen** - `d4ab1be` (feat)

## Files Created/Modified

- `ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift` - UpdateService Property, setupUpdateService(), delegierte checkForUpdate/startUpdate, computed updateInProgress
- `ValetudoApp/ValetudoApp/Views/RobotSettingsSections.swift` - UpdateService Init-Parameter, @State updaterState entfernt, loadInfo() ohne getUpdaterState()
- `ValetudoApp/ValetudoApp/Views/RobotSettingsView.swift` - updateService Property und Init-Parameter, ValetudoInfoView-Aufruf aktualisiert
- `ValetudoApp/ValetudoApp/Views/RobotDetailView.swift` - RobotSettingsView-Aufruf mit viewModel.updateService

## Decisions Made

- ValetudoInfoView erhält UpdateService als optionalen Init-Parameter (nicht EnvironmentObject) — explizites Ownership, klare Abhängigkeit sichtbar
- updaterState @State komplett aus ValetudoInfoView entfernt — UpdateService.phase ist jetzt alleinige Quelle
- updateInProgress als Computed Property (nicht @Published) — reagiert direkt auf UpdateService.phase-Änderungen

## Deviations from Plan

Keine — Plan exakt wie beschrieben umgesetzt.

## Issues Encountered

Kein iPhone 16 Simulator verfügbar — Build mit iPhone 16 Pro (id=B7E34884) ausgeführt. BUILD SUCCEEDED.

## Known Stubs

Keine. updaterState in RobotDetailViewModel bleibt als @Published var mit nil-Wert (wird in Phase 13 entfernt) — das ist laut Plan explizit akzeptiert und kein Stub der Plan-Ziele.

## Next Phase Readiness

- STATE-04 erfüllt: Ein UpdateService als Single Source of Truth, von ViewModel und ValetudoInfoView gelesen
- Phase 12 vollständig abgeschlossen (2/2 Pläne done)
- Phase 13 (State Consolidation) kann updaterState @Published und Proxy-Properties finalisieren/entfernen
- Projekt kompiliert fehlerfrei

---
*Phase: 12-state-machine-foundation*
*Completed: 2026-04-01*
