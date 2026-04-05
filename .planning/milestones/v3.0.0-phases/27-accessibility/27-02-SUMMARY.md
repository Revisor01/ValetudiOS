---
phase: 27-accessibility
plan: 02
subsystem: ui
tags: [swiftui, accessibility, voiceover, a11y, map, canvas]

requires:
  - phase: 27-01-accessibility
    provides: Non-map accessibility labels (robot controls, status, consumables, timers)

provides:
  - accessibilityElement(children: .ignore) + summary label on Map Canvas
  - accessibilityLabel + accessibilityHint on Room-Tap-Target Buttons
  - accessibilityLabel on tag/reset/xmark Buttons in MapView toolbar
  - accessibilityLabel on splitRoomBar Reset-Button in MapControlBarsView
  - accessibilityLabel on alle drei Restriction-Delete-Buttons in MapOverlayViews
  - 11 map.* Lokalisierungskeys (DE/EN) in Localizable.xcstrings

affects: [28-test-coverage-expansion, 29-ux-robustness]

tech-stack:
  added: []
  patterns:
    - Canvas bekommt .accessibilityElement(children: .ignore) um komplexes Drawing als ein VoiceOver-Element zu kapseln
    - Room-Buttons erhalten .accessibilityHint mit Auswahl-Kontext (select vs. deselect)
    - Icon-only-Buttons erhalten .accessibilityLabel auf Button-Ebene (nicht Image-Ebene)

key-files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings
    - ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift
    - ValetudoApp/ValetudoApp/Views/MapView.swift
    - ValetudoApp/ValetudoApp/Views/MapControlBarsView.swift
    - ValetudoApp/ValetudoApp/Views/MapOverlayViews.swift

key-decisions:
  - "children: .ignore auf Canvas statt .combine - Canvas hat keine sinnvollen VoiceOver-Kinder"
  - "accessibilityHint mit Auswahl-Kontext auf Room-Buttons - VoiceOver liest aktuellen Status vor"

patterns-established:
  - "Canvas-Accessibility: .accessibilityElement(children: .ignore) + .accessibilityLabel als Summary"
  - "Icon-Button-Accessibility: .accessibilityLabel auf Button-Ebene, nicht auf Image-Ebene"

requirements-completed: [A11Y-04, A11Y-05]

duration: 10min
completed: 2026-04-05
---

# Phase 27 Plan 02: Map Accessibility Labels Summary

**VoiceOver-Labels fuer Map-Canvas (children: .ignore), Room-Chips (name + select/deselect hint) und 7 Icon-only-Buttons in MapView, MapControlBarsView und MapOverlayViews**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-04-05T00:22:00Z
- **Completed:** 2026-04-05T00:32:55Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- MapInteractiveView: Canvas als einzelnes VoiceOver-Element mit Summary-Label "Grundriss mit Roboterposition"
- MapInteractiveView: Room-Tap-Target-Buttons mit Raumname als Label und Auswahl-Kontext als Hint
- MapView: tag-Button, reset-Button und xmark-Button mit beschreibenden accessibilityLabels
- MapControlBarsView: splitRoomBar Reset-Button mit accessibilityLabel "Splitlinie zuruecksetzen"
- MapOverlayViews: alle drei Restriction-Delete-Buttons mit kontextspezifischen Labels (virtual wall / no-go / no-mop)
- Localizable.xcstrings: 11 neue map.* Keys (DE + EN) fuer alle Map-Accessibility-Texte

## Task Commits

1. **Task 1: Map-Keys + Canvas + Room-Chips** - `9442abd` (feat)
2. **Task 2: Toolbar + ControlBars + Overlays** - `13413d7` (feat)

## Files Created/Modified

- `ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings` - 11 neue map.* Accessibility-Keys (DE/EN)
- `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift` - Canvas accessibilityElement, Room-Button Labels/Hints
- `ValetudoApp/ValetudoApp/Views/MapView.swift` - tag/reset/xmark Button accessibilityLabels
- `ValetudoApp/ValetudoApp/Views/MapControlBarsView.swift` - splitRoomBar Reset-Button accessibilityLabel
- `ValetudoApp/ValetudoApp/Views/MapOverlayViews.swift` - Restriction-Delete-Buttons accessibilityLabels

## Decisions Made

- `children: .ignore` auf dem Canvas: Canvas rendert keine semantisch sinnvollen Kind-Elemente fuer VoiceOver — ein einziges Summary-Element ist korrekter als kombinierter Leerinhalt.
- accessibilityHint statt Label fuer den Auswahl-Kontext bei Room-Buttons: Der Raumname ist das Label, der Hint erklaert die Aktion.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

xcodebuild erforderte korrekte Simulator-ID (B7E34884) statt "iPhone 16" als Name — kein Code-Problem.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 27 (Accessibility) vollstaendig: alle Map-Views und Non-Map-Views haben VoiceOver-Labels
- Bereit fuer Phase 28 (Test Coverage) und Phase 29 (UX Robustness)

---
*Phase: 27-accessibility*
*Completed: 2026-04-05*
