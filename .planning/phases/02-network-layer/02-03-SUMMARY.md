---
phase: 02-network-layer
plan: 03
subsystem: ui
tags: [swiftui, sse, map, caching, performance, swift]

# Dependency graph
requires:
  - phase: 02-network-layer plan 01
    provides: ValetudoAPI.streamMapLines(), SSEConnectionManager actor

provides:
  - MapLayerCache class-based pixel decompression cache in RobotMap.swift
  - MapContentView.startLiveRefresh() uses SSE with polling fallback

affects: [map-rendering, sse-lifecycle, phase-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - class-reference cache on Codable struct to work around SwiftUI let-binding
    - SSE stream with CancellationError clean-exit and polling fallback

key-files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/Models/RobotMap.swift
    - ValetudoApp/ValetudoApp/Views/MapView.swift

key-decisions:
  - "MapLayerCache uses final class (not lazy var) — MapLayer is a struct passed as let in SwiftUI Canvas, lazy var would require mutating"
  - "Cache invalidation is natural: new map data from SSE or polling creates new MapLayer instances with fresh MapLayerCache"
  - "Map-SSE lifecycle bounded to MapContentView open/close via refreshTask — SSEConnectionManager not used for map-SSE (attributes-SSE only)"
  - "CancellationError caught and returned cleanly — not swallowed — ensures Task exits on onDisappear cancel"

patterns-established:
  - "Cache-on-struct pattern: use a final class as stored property on Codable struct for memoization in SwiftUI immutable contexts"
  - "SSE-then-poll fallback: try SSE stream, catch non-cancellation errors, fall back to polling"

requirements-completed: [DEBT-03, NET-01]

# Metrics
duration: 10min
completed: 2026-03-27
---

# Phase 02 Plan 03: Map Pixel Cache + SSE Lifecycle Summary

**MapLayerCache final class caches RLE-decompressed pixels per MapLayer instance; MapContentView replaces 2s polling with SSE stream (auto-fallback to polling on failure)**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-03-27
- **Completed:** 2026-03-27
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- `MapLayerCache` class added to RobotMap.swift — pixel decompression runs once per MapLayer, cached on first access, naturally invalidated when new map data arrives
- `MapLayer.decompressedPixels` now delegates to cache instead of recomputing every frame
- `MapContentView.startLiveRefresh()` replaced with SSE-first implementation: connects to `api.streamMapLines()`, decodes `data:` lines as `RobotMap`, updates map on MainActor
- Clean fallback to 2s `pollMapFallback()` when SSE fails; `CancellationError` exits cleanly on `onDisappear`

## Task Commits

Each task was committed atomically:

1. **Task 1: MapLayerCache class-wrapper fuer Pixel-Dekompression** - `13412ae` (feat)
2. **Task 2: MapView Map-SSE-Lifecycle statt 2s-Polling** - `5bd3e62` (feat)

## Files Created/Modified

- `ValetudoApp/ValetudoApp/Models/RobotMap.swift` - Added MapLayerCache class, refactored decompressedPixels to use cache, extracted computeDecompressedPixels() as fileprivate
- `ValetudoApp/ValetudoApp/Views/MapView.swift` - Replaced startLiveRefresh() polling loop with SSE stream + pollMapFallback() fallback

## Decisions Made

- `MapLayerCache` as `final class` (not `lazy var`) because `MapLayer` is a struct — SwiftUI passes structs as `let` in Canvas closures, making `mutating lazy var` impossible to compile.
- Cache invalidation is architecture-natural: SSE/polling always creates new `RobotMap` with new `MapLayer` instances, each with a fresh `MapLayerCache` — no explicit `invalidate()` call needed.
- `pollMapFallback()` extracted as separate `async` func for clarity and testability.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Map rendering now efficient (single decompression per layer per map version)
- Map-SSE live updates active when MapView is open
- Phase 03 can build on SSE patterns established in Plans 01 and 03

---
*Phase: 02-network-layer*
*Completed: 2026-03-27*
