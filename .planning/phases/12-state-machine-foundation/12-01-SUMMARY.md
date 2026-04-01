---
phase: 12-state-machine-foundation
plan: 01
subsystem: service
tags: [swift, state-machine, update-service, concurrency, observable-object]

# Dependency graph
requires:
  - phase: none
    provides: "ValetudoAPI mit getUpdaterState/checkForUpdates/downloadUpdate/applyUpdate Methoden"
provides:
  - "UpdatePhase enum mit 8 Cases als zentrale State-Machine-Definition"
  - "UpdateService class als @MainActor ObservableObject mit Re-Entrancy-Guards"
  - "pollUntilReadyToApply() mit Pitfall-6-Erkennung (unerwarteter idle = Fehler)"
  - "mapUpdaterState() fuer Valetudo-Klassennamen zu UpdatePhase Mapping"
affects: [13-state-machine-consolidation, 14-apply-phase-hardening, 15-ui-wiring]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@MainActor ObservableObject mit @Published private(set) fuer thread-sicheren State"
    - "Pattern-Matching-Guards (guard case .idle = phase) als Re-Entrancy-Schutz"
    - "pollingTask: Task<Void, Never>? fuer cancellable Hintergrundaufgaben"
    - "Catch-Bloecke setzen phase = .error(...) statt stillem Reset"

key-files:
  created:
    - ValetudoApp/ValetudoApp/Services/UpdateService.swift
  modified:
    - ValetudoApp/ValetudoApp.xcodeproj/project.pbxproj

key-decisions:
  - "pollUntilReadyToApply() speichert Task in pollingTask-Property fuer externes Cancel via reset()"
  - "Unerwarteter idle-State im Polling-Loop wird als Fehler ('Download wurde unterbrochen') behandelt (Pitfall 6)"
  - "mapUpdaterState() gibt .idle fuer unbekannte States zurueck (mit logger.warning) statt Error-State — Fehler wird durch catch-Block gehandelt"

patterns-established:
  - "State-Machine-Guard: guard case .expectedState = phase else { logger.warning; return }"
  - "Error-Propagation: jeder catch-Block setzt phase = .error(error.localizedDescription)"
  - "Polling: Task in Property speichern, cancel in deinit und reset()"

requirements-completed: [STATE-01, STATE-02, STATE-03]

# Metrics
duration: 4min
completed: 2026-04-01
---

# Phase 12 Plan 01: State Machine Foundation Summary

**UpdatePhase-Enum (8 Cases) und UpdateService als @MainActor ObservableObject mit Re-Entrancy-Guards, Error-State-Propagation und Polling-Loop mit Pitfall-6-Erkennung**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-01T16:37:06Z
- **Completed:** 2026-04-01T16:40:44Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments
- UpdatePhase enum mit allen 8 Cases definiert (idle, checking, updateAvailable, downloading, readyToApply, applying, rebooting, error(String))
- UpdateService als @MainActor ObservableObject mit @Published private(set) var phase erstellt
- Re-Entrancy-Guards auf checkForUpdates(), startDownload(), startApply() per Pattern-Matching-Guard
- Error-State-Propagation in allen catch-Bloecken (kein stilles Reset)
- Polling-Loop mit Pitfall-6-Erkennung: unerwarteter idle-State waehrend Download setzt phase = .error("Download wurde unterbrochen")
- Valetudo-State-String-Mapping (ValetudoUpdaterIdleState → .idle etc.) in mapUpdaterState()

## Task Commits

1. **Task 1: UpdatePhase-Enum und UpdateService erstellen** - `1c2d42a` (feat)

**Plan metadata:** `21af601` (docs: complete plan)

## Files Created/Modified
- `ValetudoApp/ValetudoApp/Services/UpdateService.swift` - UpdatePhase enum + UpdateService class mit vollstaendiger State-Machine-Logik
- `ValetudoApp/ValetudoApp.xcodeproj/project.pbxproj` - Neue Datei ins Xcode-Target aufgenommen via xcodegen

## Decisions Made
- pollingTask als Property gespeichert damit reset() den Polling von aussen abbrechen kann
- Unbekannte Valetudo-States werden als .idle gemappt (mit Warning-Log) — kein Error-State, da unbekannte States kein Fehler des Update-Prozesses sind
- mapUpdaterState() ist private (nur intern genutzt) und gibt UpdatePhase zurueck (kein throws)

## Deviations from Plan

Keine — Plan exakt wie spezifiziert ausgefuehrt.

## Issues Encountered

Keine.

## User Setup Required

Keine — keine externen Services konfiguriert.

## Next Phase Readiness
- UpdateService.swift ist vollstaendig und kompiliert fehlerfrei
- Phase 13 (State Machine Consolidation) kann UpdateService als Basis fuer die Konsolidierung der bestehenden Update-Logik in RobotDetailViewModel nutzen
- UpdatePhase-Enum ist versioniert und stable — kein Breaking Change erwartet

## Self-Check: PASSED

- UpdateService.swift: FOUND
- 12-01-SUMMARY.md: FOUND
- Commit 1c2d42a: FOUND
- Build: SUCCEEDED

---
*Phase: 12-state-machine-foundation*
*Completed: 2026-04-01*
