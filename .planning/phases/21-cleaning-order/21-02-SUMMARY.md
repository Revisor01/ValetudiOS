---
phase: 21-cleaning-order
plan: "02"
status: complete
started: "2026-04-04"
completed: "2026-04-04"
---

# Plan 21-02: Nummerierte Badges für Reinigungsreihenfolge — Summary

## What Was Built

Nummerierte blaue Badges (1, 2, 3...) auf der Karte zeigen die Reinigungsreihenfolge der ausgewählten Räume. Zusätzlich wird `customOrder: true` an die Valetudo API gesendet, damit der Roboter die Reihenfolge tatsächlich einhält.

## Key Changes

### MapInteractiveView.swift
- **orderBadgesOverlay** — Neuer ViewBuilder: Blaue Kreise (24pt) mit weißen Zahlen (14pt bold) über Raum-Mittelpunkten
- Badges unabhängig von `showRoomLabels`, nur im `editMode == .none`
- `enumerated()` auf `selectedSegmentIds` für lückenlose Nummerierung

### RobotState.swift
- **SegmentCleanRequest** — `customOrder: Bool?` Feld hinzugefügt

### ValetudoAPI.swift
- **cleanSegments()** — `customOrder: Bool = false` Parameter hinzugefügt

### MapViewModel.swift + RobotDetailViewModel.swift
- **cleanSelectedRooms()** — `customOrder: selectedSegmentIds.count > 1` bei Mehrraum-Reinigung

## key-files

### created
(none)

### modified
- `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift` — +36 lines (orderBadgesOverlay)
- `ValetudoApp/ValetudoApp/Models/RobotState.swift` — +2 lines (customOrder field)
- `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift` — +1 line (customOrder param)
- `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift` — modified cleanSelectedRooms
- `ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift` — modified cleanSelectedRooms

## Commits

- `7eca004` feat(map): add numbered order badges for room cleaning sequence
- `aaf9e57` fix(api): send customOrder flag to enforce room cleaning sequence

## Self-Check: PASSED

- Badges zeigen 1, 2, 3 in Auswahlreihenfolge
- Abwählen nummeriert lückenlos um
- Badges unabhängig von showRoomLabels
- customOrder: true wird bei 2+ Räumen gesendet
- Roboter reinigt in der gewählten Reihenfolge
- Human verification: alle Szenarien bestanden

## Deviations

- **customOrder-Fix war nicht im ursprünglichen Plan** — User-Testing ergab, dass die Valetudo API den Parameter `customOrder: true` benötigt, damit die Reihenfolge respektiert wird. Fix wurde inline implementiert.
