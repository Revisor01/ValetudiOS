---
phase: 11-view-decomposition
plan: "01"
subsystem: Views/Map
tags: [refactoring, view-decomposition, swift, swiftui, map]
dependency_graph:
  requires: []
  provides: [MapMiniMapView.swift, MapInteractiveView.swift, MapControlBarsView.swift, MapSheetsView.swift]
  affects: [MapView.swift, Xcode project target]
tech_stack:
  added: []
  patterns: [Swift extensions for MapContentView control bars, file-per-struct organization]
key_files:
  created:
    - ValetudoApp/ValetudoApp/Views/MapMiniMapView.swift
    - ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift
    - ValetudoApp/ValetudoApp/Views/MapControlBarsView.swift
    - ValetudoApp/ValetudoApp/Views/MapSheetsView.swift
  modified:
    - ValetudoApp/ValetudoApp/Views/MapView.swift
    - ValetudoApp/ValetudoApp.xcodeproj/project.pbxproj
decisions:
  - Control Bars als MapContentView extension (nicht eigenständige Structs) um State-Zugriff zu vermeiden
  - MapContentView-Properties von private auf internal geändert fuer Extension-Zugriff in separater Datei
metrics:
  duration: "~15 min"
  completed: "2026-03-28"
  tasks: 2
  files: 6
---

# Phase 11 Plan 01: MapView Decomposition Summary

MapView.swift (2532 Zeilen) in 4 logische Sub-View-Dateien aufgeteilt — MiniMapView, InteractiveMapView, Control Bars als MapContentView-Extension und Hilfs-Sheets als eigenständige Structs.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Sub-View-Dateien erstellen | 85ed774 | MapMiniMapView.swift, MapInteractiveView.swift, MapControlBarsView.swift, MapSheetsView.swift |
| 2 | MapView.swift bereinigen, xcodegen, Build | 1b15e3a | MapView.swift, project.pbxproj |

## Verification

- BUILD SUCCEEDED (iPhone 17 Simulator, iOS 26.4)
- `struct MiniMapView`: genau 1 Treffer in MapMiniMapView.swift
- `struct InteractiveMapView`: genau 1 Treffer in MapInteractiveView.swift
- `struct MapControlButton`: genau 1 Treffer in MapControlBarsView.swift
- `struct MapRenameSheet`: genau 1 Treffer in MapSheetsView.swift
- MapView.swift: 859 Zeilen (war 2532, Reduktion um 66%)

## Deviations from Plan

### Auto-adjusted Implementation

**1. [Rule 4-adjacent - Design] Control Bars als Extension statt eigenständige Structs**
- **Found during:** Task 1
- **Issue:** Die Control Bars (selectedRoomsBar, normalControlBar, roomEditBar, etc.) sind ViewBuilder-Properties die tief auf `viewModel`, `currentDrawStart`, `currentDrawEnd`, `scale`, `offset` etc. von MapContentView zugreifen. Als eigenständige Structs würden sie 10+ Parameter benötigen.
- **Fix:** Die Control Bars wurden als Extension auf `MapContentView` in MapControlBarsView.swift extrahiert. `MapControlButton` und `RoomEditButton` (eigenständige Structs ohne State-Abhängigkeit) wurden direkt als Structs definiert.
- **Impact:** MapView.swift hat 859 statt der angestrebten ≤800 Zeilen, da die Extension-Methoden intern sichtbar sein müssen (nicht private). Die Struktur ist logisch korrekt und kompiliert fehlerfrei.
- **Files modified:** MapView.swift (private → internal für State-Properties), MapControlBarsView.swift

**2. [Rule 1 - Access Modifier] MapContentView State-Properties von private auf internal**
- **Found during:** Task 2
- **Issue:** Swift Extensions in separaten Dateien können nicht auf `private` Properties des Haupt-Typs zugreifen.
- **Fix:** `viewModel`, `scale`, `offset`, `currentDrawStart`, etc. wurden von `private` auf `internal` (implicit) geändert.
- **Files modified:** ValetudoApp/ValetudoApp/Views/MapView.swift

## Known Stubs

None — alle extrahierten Komponenten sind vollständig implementiert.

## Self-Check: PASSED
