---
phase: 24-map-performance
plan: 01
subsystem: map
tags: [sse, streaming, caching, performance, swift, swiftui]

# Dependency graph
requires:
  - phase: 22-map-geometry-unification
    provides: MapViewModel structure with centralized state
  - phase: 23-error-handling-robustness-patterns
    provides: Explicit error handling patterns (no silent try?)
provides:
  - SSE-based map streaming in MapViewModel with HTTP-poll fallback
  - Hash-based write deduplication in MapCacheService (saveIfChanged)
affects: [25-view-architecture, 28-test-coverage-expansion]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - SSE stream loop with for-try-await and CancellationError handling
    - Exponential backoff retry pattern (2s/5s/30s) on SSE connection failure
    - Hash-based cache deduplication to avoid redundant disk I/O

key-files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/Services/MapCacheService.swift
    - ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift

key-decisions:
  - "data.hashValue used for cache dedup — acceptable collision risk (worst case: skipped write), avoids CryptoKit dependency"
  - "save() kept unchanged for initial load in loadMap() — dedup not needed there (called only once)"
  - "SSE decode failure triggers single HTTP-GET fallback, not connection retry — avoids unnecessary reconnect overhead"

patterns-established:
  - "SSE stream loop: for try await line in bytes.lines with data: prefix guard"
  - "Exponential backoff: retryCount 1->2s, 2->5s, 3+->30s"
  - "saveIfChanged: encode -> hash -> compare -> write only if changed"

requirements-completed: [PERF-02, PERF-05]

# Metrics
duration: 15min
completed: 2026-04-04
---

# Phase 24 Plan 01: SSE Map-Streaming Summary

**MapViewModel ersetzt 2-Sekunden HTTP-Poll durch SSE-Stream mit exponentieller Reconnect-Strategie; MapCacheService schreibt nur noch bei tatsaechlicher Datenaenderung auf Disk**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-04T23:30:00Z
- **Completed:** 2026-04-04T23:45:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- MapCacheService: `saveIfChanged()` mit `lastDataHash` Dictionary — ueberspringt Disk-Write bei identischem Hash
- MapViewModel: `startMapRefresh()` nutzt jetzt `api.streamMapLines()` statt 2s-Polling-Schleife
- SSE-Decode-Fehler: explizites Logging + einzelner HTTP-GET als Fallback (kein stilles try?)
- SSE-Connection-Fehler: HTTP-Poll-Fallback + Exponential Backoff 2s/5s/30s

## Task Commits

Jeder Task wurde atomar committed:

1. **Task 1: MapCacheService hash-basierte Deduplication** - `b8a50c4` (feat)
2. **Task 2: MapViewModel SSE-Streaming mit Poll-Fallback** - `e2aaf9e` (feat)

**Plan metadata:** (folgt in finalem Commit)

## Files Created/Modified
- `ValetudoApp/ValetudoApp/Services/MapCacheService.swift` - `saveIfChanged()` + `lastDataHash` hinzugefuegt
- `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift` - `startMapRefresh()` komplett durch SSE-Loop ersetzt

## Decisions Made
- `data.hashValue` statt CryptoKit SHA — ausreichend fuer Cache-Dedup, keine externe Abhaengigkeit
- `save()` in `loadMap()` unveraendert — dort kein Dedup noetig (nur einmaliger initialer Load)
- SSE-Decode-Fehler loest einzelnen HTTP-GET aus, kein Verbindungsabbruch — vermeidet unnoetige Reconnects

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- SSE Map-Streaming und Cache-Deduplication komplett implementiert
- Plan 24-02 (Spatial Hit-Testing) kann jetzt aufsetzen auf aktuellem MapViewModel-Stand
- Plan 24-03 (segmentInfos-Cache + CGImage Pre-Rendering) ebenfalls bereit

---
*Phase: 24-map-performance*
*Completed: 2026-04-04*
