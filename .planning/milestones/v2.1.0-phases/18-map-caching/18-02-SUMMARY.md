---
phase: 18-map-caching
plan: 02
subsystem: ui
tags: [swift, swiftui, offline, localization, mapcaching, ios]

requires:
  - phase: 18-01-map-caching
    provides: MapCacheService.shared, MapViewModel.isOffline

provides:
  - Offline-Banner-Overlay in MapView als dezente Capsule mit wifi.slash Icon
  - Cache-Cleanup in RobotManager.removeRobot() via MapCacheService.shared.deleteCache()
  - Lokalisierungskey map.offline in en/de/fr

affects:
  - MapView.swift: ZStack-Overlay fuer Offline-Zustand
  - RobotManager.swift: removeRobot() loescht jetzt auch MapCache
  - Localizable.xcstrings: neuer map.offline Key

tech-stack:
  added: []
  patterns:
    - "Offline-Banner: VStack+HStack mit ultraThinMaterial Capsule oben in MapContentView ZStack"
    - "Cache-Cleanup: synchrones deleteCache() direkt nach saveRobots() in removeRobot()"
    - "Lokalisierung: xcstrings JSON mit fr-Uebersetzung ergaenzt (Hors ligne — Carte en cache)"

key-files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/Views/MapView.swift
    - ValetudoApp/ValetudoApp/Services/RobotManager.swift
    - ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings

decisions:
  - "Checkpoint:human-verify auto-approved per autonomous-mode-instruction fuer Plan 18-02"
  - "Franzoesische Uebersetzung hinzugefuegt (Hors ligne — Carte en cache) — Datei enthaelt fr als dritte Sprache"

metrics:
  duration: ~8min
  completed: 2026-04-02T09:09:54Z
  tasks_completed: 3
  files_modified: 3
---

# Phase 18 Plan 02: Map Caching UI — Summary

**One-liner:** Offline-Banner als Capsule-Overlay mit wifi.slash Icon in MapView, Cache-Cleanup in removeRobot(), map.offline-Lokalisierung in en/de/fr.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Offline-Banner in MapView + Cache-Cleanup in RobotManager | 53d2e28 | MapView.swift, RobotManager.swift |
| 2 | Lokalisierungskey map.offline in String Catalog | 24d3143 | Localizable.xcstrings |
| 3 | Visueller Check (auto-approved) | — | — |

## What Was Built

**Offline-Banner (MapView.swift):**

Im inneren ZStack von `MapContentView` wird nach allen bestehenden Overlays (GoTo-Marker, Preset-Marker, Restriction-Targets) ein dezenter Banner eingeblendet, wenn `viewModel.isOffline == true`. Der Banner ist eine Capsule mit `ultraThinMaterial`-Hintergrund, einem `wifi.slash`-Icon und dem lokalisierten Text `map.offline`. Er erscheint oben auf der Karte und verschwindet automatisch beim naechsten erfolgreichen `getMap()`-Call (da `isOffline` dann auf `false` gesetzt wird — implementiert in Plan 18-01).

**Cache-Cleanup (RobotManager.swift):**

In `removeRobot(_ id: UUID)` wird nach `saveRobots()` synchron `MapCacheService.shared.deleteCache(for: id)` aufgerufen. `deleteCache` ist synchron — kein async/await noetig.

**Lokalisierung (Localizable.xcstrings):**

Neuer Key `map.offline` mit drei Sprachen: en ("Offline — Cached Map"), de ("Offline — Gespeicherte Karte"), fr ("Hors ligne — Carte en cache"). Alphabetisch korrekt zwischen `map.nogo_hint` und `map.nomop_hint` eingefuegt.

## Deviations from Plan

### Auto-added

**1. [Rule 2 - Missing Critical Functionality] Franzoesische Uebersetzung hinzugefuegt**
- **Found during:** Task 2
- **Issue:** Plan spezifiziert nur en/de. Die xcstrings-Datei enthaelt jedoch fr als dritte Sprache. Ein fehlender fr-Key wuerden in Xcode als fehlende Uebersetzung gemeldet.
- **Fix:** fr-Uebersetzung "Hors ligne — Carte en cache" ergaenzt.
- **Files modified:** Localizable.xcstrings
- **Commit:** 24d3143

## Checkpoint

Task 3 war `checkpoint:human-verify`. Da der Executor im autonomen Modus laeuft, wurde der Checkpoint automatisch mit "approved" beantwortet.

## Known Stubs

None — alle Werte werden aus dem echten `viewModel.isOffline`-State gelesen, der von `MapCacheService` gesteuert wird.

## Self-Check: PASSED

- [x] MapView.swift enthaelt `viewModel.isOffline` (grep: 1 Treffer)
- [x] MapView.swift enthaelt `wifi.slash` (grep: 1 Treffer)
- [x] MapView.swift enthaelt `map.offline` (grep: 1 Treffer)
- [x] MapView.swift enthaelt `ultraThinMaterial` (grep: 2 Treffer, davon 1 im neuen Banner)
- [x] RobotManager.swift enthaelt `MapCacheService.shared.deleteCache` (grep: 1 Treffer)
- [x] Localizable.xcstrings enthaelt `map.offline` (grep: 1 Treffer)
- [x] Commit 53d2e28 existiert (Task 1)
- [x] Commit 24d3143 existiert (Task 2)
- [x] BUILD SUCCEEDED
