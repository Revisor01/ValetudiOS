---
phase: 18-map-caching
plan: 01
subsystem: cache
tags: [swift, filemanager, json, codable, offline, ios]

requires:
  - phase: 17-background-monitoring
    provides: BackgroundMonitorService Singleton-Pattern als Referenz fuer MapCacheService

provides:
  - MapCacheService Singleton mit async save/load und sync deleteCache fuer RobotMap-Disk-Persistenz
  - MapViewModel.isOffline Bool-Flag fuer Offline-Indikator
  - Cache-Integration in loadMap() und startMapRefresh() Polling-Loop

affects:
  - 18-02-map-caching (Offline-Banner in MapView.swift benötigt isOffline-Flag aus diesem Plan)
  - RobotManager.removeRobot() (Cache-Cleanup noch nicht implementiert — folgt in Plan 18-02 oder als Deviation)

tech-stack:
  added: []
  patterns:
    - "MapCacheService Singleton: static let shared + private init(), async Disk-I/O via Foundation"
    - "Offline-State-Management: isOffline=true nur bei tatsaechlich geladenem Cache, false bei jedem Erfolg"
    - "Atomic FileManager Write: data.write(to:url, options:.atomic) fuer sichere Cache-Persistenz"

key-files:
  created:
    - ValetudoApp/ValetudoApp/Services/MapCacheService.swift
  modified:
    - ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift

key-decisions:
  - "MapCacheService ohne @MainActor — save/load sind async und blockieren den Main Thread nicht"
  - "isOffline=true im Polling-Loop bei self.map != nil (bereits angezeigte Karte wird offline) — kein Cache-Reload noetig"
  - "isOffline-Flag NUR bei tatsaechlich geladenem Cache gesetzt — ohne Cache bleibt ContentUnavailableView (per CONTEXT.md)"
  - "xcodegen generate nach MapCacheService.swift-Erstellung ausgefuehrt — automatisch ins Xcode-Target aufgenommen"

patterns-established:
  - "MapCacheService als Singleton-Service fuer Disk-I/O — konsistent mit NotificationService.shared und BackgroundMonitorService.shared"

requirements-completed: [CACHE-01, CACHE-02, CACHE-03]

duration: 5min
completed: 2026-04-01
---

# Phase 18 Plan 01: Map Caching — Service & ViewModel

**MapCacheService Singleton mit async JSON-Persistenz in Documents/MapCache/ und isOffline-Flag-Integration in MapViewModel fuer CACHE-01/02/03**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-04-01T00:00:00Z
- **Completed:** 2026-04-01T00:05:00Z
- **Tasks:** 2
- **Files modified:** 2 (+1 xcodeproj via xcodegen)

## Accomplishments

- MapCacheService.swift erstellt — Singleton mit save/load/deleteCache, atomic FileManager I/O, os.Logger
- MapViewModel erweitert — @Published var isOffline + Cache-Calls in loadMap() und startMapRefresh()
- Projekt kompiliert ohne Fehler (BUILD SUCCEEDED)

## Task Commits

1. **Task 1: MapCacheService erstellen** - `e3c2584` (feat)
2. **Task 2: MapViewModel Cache-Integration und isOffline** - `fcb9e0f` (feat)

## Files Created/Modified

- `ValetudoApp/ValetudoApp/Services/MapCacheService.swift` — Neuer Singleton-Service fuer Disk-basiertes Map-Caching mit async save/load und sync deleteCache
- `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift` — isOffline-Flag, Cache-Calls in loadMap() und startMapRefresh()

## Decisions Made

- `isOffline = true` im Polling-Loop auch wenn `self.map != nil` — Karte bereits sichtbar, Benutzer soll trotzdem sehen dass keine Live-Verbindung besteht
- Cache-Load im Polling-Loop nur wenn `self.map == nil` — bei bereits sichtbarer Karte kein erneuter Cache-Load, nur isOffline-Flag
- xcodegen nach Datei-Erstellung ausgefuehrt (etabliertes Pattern aus Phase 10)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- MapCacheService und isOffline-Flag sind bereit fuer Plan 18-02 (Offline-Banner in MapView.swift + Cache-Cleanup in RobotManager)
- Plan 18-02 kann direkt mit `viewModel.isOffline` das ZStack-Overlay implementieren

## Self-Check: PASSED

- MapCacheService.swift: FOUND
- MapViewModel.swift (modified): FOUND
- 18-01-SUMMARY.md: FOUND
- Commit e3c2584 (Task 1): FOUND
- Commit fcb9e0f (Task 2): FOUND
- BUILD SUCCEEDED: VERIFIED

---
*Phase: 18-map-caching*
*Completed: 2026-04-01*
