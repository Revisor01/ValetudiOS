---
phase: 07-bugfixes-robustness
plan: 04
subsystem: ui
tags: [swift, swiftui, map, coordinates, rounding]

# Dependency graph
requires:
  - phase: 02-network-layer
    provides: MapLayerCache, MapViewModel, map coordinate transforms
provides:
  - Float-zu-Int-Rundungsfehler in Koordinaten-Transformationen behoben
affects: [map, zone-cleaning, goto-commands]

# Tech tracking
tech-stack:
  added: []
  patterns: [".rounded() vor Int()-Cast bei CGFloat-Pixel-Koordinaten-Umrechnungen"]

key-files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/Views/MapView.swift
    - ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift

key-decisions:
  - ".rounded() auf CGFloat-Division-Ergebnis anwenden vor Int()-Cast — verhindert systematischen Truncation-Versatz von bis zu einem pixelSize-Wert"

patterns-established:
  - "Pixel-Koordinaten-Konversion: Int((cgFloatValue).rounded()) statt Int(cgFloatValue)"

requirements-completed: [FIX-04]

# Metrics
duration: 1min
completed: 2026-03-28
---

# Phase 7 Plan 04: Koordinaten-Rundungsfehler-Fix Summary

**Float-zu-Int-Truncation bei Pixel-Koordinaten-Umrechnung durch `.rounded()` behoben — Zone-Cleaning, GoTo-Marker und Room-Split landen jetzt auf der korrekten API-Position**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-28T15:17:46Z
- **Completed:** 2026-03-28T15:19:32Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- `finishDrawing()` in MapView.swift: 4 pixelStart/EndX/Y-Variablen nutzen `.rounded()` vor Int()-Cast
- GoTo-Marker DragGesture in MapView.swift: pixelX/Y nutzen `.rounded()` vor Int()-Cast
- `splitRoom()` in MapViewModel.swift: 4 pixelA/BX/Y-Variablen nutzen `.rounded()` vor Int()-Cast
- Systematischer Versatz von bis zu einem pixelSize-Wert (5-10 API-Einheiten) bei map scale != 1.0 eliminiert

## Task Commits

1. **Task 1: MapView.swift Koordinaten-Truncation durch rounded() ersetzen** - `aec5418` (fix)
2. **Task 2: MapViewModel.splitRoom() Koordinaten-Truncation durch rounded() ersetzen** - `ca052ae` (fix)

**Plan metadata:** (kommender docs-commit)

## Files Created/Modified
- `ValetudoApp/ValetudoApp/Views/MapView.swift` - GoTo-Drag (Z. 569-570) und finishDrawing (Z. 1492-1495) verwenden `.rounded()`
- `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift` - splitRoom() Z. 323-326 verwenden `.rounded()`

## Decisions Made
- `.rounded()` auf das Divisionsergebnis vor dem Int()-Cast anwenden (nicht auf die Eingabewerte) — entspricht mathematisch korrekter Rundung zur nächsten ganzen Pixel-Koordinate

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Alle Pixel-Koordinaten-Konversionen in MapView und MapViewModel sind jetzt konsistent mit `.rounded()`
- Zone-Cleaning, GoTo-Befehle und Room-Split senden korrekte API-Koordinaten

---
*Phase: 07-bugfixes-robustness*
*Completed: 2026-03-28*
