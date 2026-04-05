---
phase: 21-cleaning-order
plan: 01
subsystem: ui
tags: [swiftui, mvvm, array, set, cleaning-order, binding]

# Dependency graph
requires:
  - phase: 20-room-tap
    provides: MapInteractiveView mit Canvas Hit-Testing und selectedSegmentIds Binding
provides:
  - selectedSegmentIds als [String] (geordnet) in MapViewModel
  - selectedSegments als [String] (geordnet) in RobotDetailViewModel
  - Array-Binding in MapInteractiveView
  - Reinigungsreihenfolge bleibt bei API-Call erhalten
affects: [21-cleaning-order]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Array statt Set fuer geordnete Segment-Auswahl — append/removeAll(where:) statt insert/remove"

key-files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift
    - ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift
    - ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift
    - ValetudoApp/ValetudoApp/Views/MapControlBarsView.swift

key-decisions:
  - "Set<String> zu [String] migriert — Auswahl-Reihenfolge als Reinigungsreihenfolge beibehalten"
  - "Array()-Wrapper an API-Call-Stellen entfernt — Array direkt uebergeben"

patterns-established:
  - "toggleSegment nutzt append/removeAll(where:) statt insert/remove"

requirements-completed: [ROOM-02]

# Metrics
duration: 12min
completed: 2026-04-04
---

# Phase 21 Plan 01: Set-to-Array Migration Summary

**selectedSegmentIds und selectedSegments von Set<String> zu [String] migriert, damit Auswahl-Reihenfolge als Reinigungsreihenfolge an die Valetudo API uebergeben wird**

## Performance

- **Duration:** 12 min
- **Started:** 2026-04-04T~13:00:00Z
- **Completed:** 2026-04-04T~13:12:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- MapViewModel.selectedSegmentIds ist jetzt [String] — Einfuegereihenfolge als Reinigungsreihenfolge
- RobotDetailViewModel.selectedSegments ist jetzt [String] — gleiche Semantik
- Alle toggleSegment-Implementierungen nutzen append/removeAll(where:) statt Set-Operationen
- Alle Array()-Wrapper an API-Call-Stellen entfernt
- Projekt kompiliert fehlerfrei (BUILD SUCCEEDED)

## Task Commits

Jeder Task wurde atomar committed:

1. **Task 1: Set->Array in ViewModels und API-Calls** - `b3b0f3b` (feat)
2. **Task 2: Binding und Views auf Array-Typ umstellen** - `5a28366` (feat)

## Files Created/Modified

- `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift` — selectedSegmentIds Set->Array, Array()-Wrapper entfernt
- `ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift` — selectedSegments Set->Array, toggleSegment migriert, Array()-Wrapper entfernt
- `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift` — @Binding Set->Array, toggleSegment migriert
- `ValetudoApp/ValetudoApp/Views/MapControlBarsView.swift` — Array()-Wrapper in joinRooms-Call entfernt

## Decisions Made

- Set<String> zu [String] — deterministisch geordnet, Einfuegereihenfolge ist Reinigungsreihenfolge
- Array direkt an cleanSegments/joinRooms uebergeben, kein Array()-Wrapper noetig

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

Build-Ziel "iPhone 16" nicht vorhanden — mit "iPhone 17" Simulator verifiziert. Kein Einfluss auf Ergebnis.

## User Setup Required

None - keine externe Konfiguration erforderlich.

## Next Phase Readiness

- Basis fuer Phase 21-02 bereit: Array-Reihenfolge wird korrekt als Reinigungsreihenfolge an API uebergeben
- Naechster Schritt: Zahlenbadges (1, 2, 3) auf Raumflaechen auf der Karte anzeigen

---
*Phase: 21-cleaning-order*
*Completed: 2026-04-04*
