---
phase: 24-map-performance
plan: 02
subsystem: ui
tags: [swift, swiftui, canvas, hit-testing, performance, caching]

# Dependency graph
requires:
  - phase: 24-map-performance
    provides: "MapViewModel with SSE-based map refresh (Plan 01)"
provides:
  - "SegmentInfo struct (public, in MapViewModel)"
  - "segmentPixelSets: [String: Set<Int>] cached pixel lookup per segment"
  - "cachedSegmentInfos: [SegmentInfo] cached centroids per segment"
  - "O(1) room tap hit-testing via packed Int key (x << 16 | y)"
affects: [25-view-architecture, 27-accessibility, 28-tests]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Packed Int key encoding: pixelX &<< 16 | pixelY for O(1) Set<Int> lookup"
    - "Cache-on-write: rebuild computed data whenever underlying map/segments change"
    - "@ObservationIgnored for performance-only state not observed by SwiftUI"

key-files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift
    - ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift
    - ValetudoApp/ValetudoApp/Views/MapView.swift

key-decisions:
  - "SegmentInfo struct placed in MapViewModel (not InteractiveMapView) so both ViewModel and View share the same type"
  - "segmentPixelSets is @ObservationIgnored — SwiftUI does not need to react to it, only hit-testing uses it"
  - "cachedSegmentInfos is observable — overlay Views need to re-render when it changes"
  - "Packed key x &<< 16 | y chosen for compact Set<Int> representation (avoids tuple/struct hashability)"

patterns-established:
  - "Cache-on-write: call rebuildSegmentPixelSets() + updateCachedSegmentInfos() at every map-assignment site"
  - "O(1) Hit-Test: encode 2D pixel coords as single Int, use Set.contains for lookup"

requirements-completed: [PERF-01, PERF-03]

# Metrics
duration: 8min
completed: 2026-04-04
---

# Phase 24 Plan 02: Spatial Hit-Testing and segmentInfos Caching Summary

**O(1) room tap hit-testing via packed Set<Int> pixel lookup and per-map segmentInfos caching, eliminating O(n) linear pixel scans on every tap and every overlay render**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-04T23:25:00Z
- **Completed:** 2026-04-04T23:33:05Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Added public `SegmentInfo` struct to MapViewModel (moved from private in InteractiveMapView)
- Built `rebuildSegmentPixelSets()` that pre-computes `Set<Int>` per segment using packed key `x &<< 16 | y` — from O(n) scan at tap time to O(1) lookup
- Built `updateCachedSegmentInfos()` that computes centroids once per map update instead of on every SwiftUI overlay render pass
- Wired both rebuild methods into all map/segments assignment sites: `loadMap()`, `startMapRefresh()` (SSE + fallback paths), `renameRoom()`, `joinRooms()`, `splitRoom()`
- Removed `private SegmentInfo` struct and `segmentInfos(from:)` method from `InteractiveMapView`
- Updated `tapTargetsOverlay` and `orderBadgesOverlay` to read `cachedSegmentInfos` directly
- Replaced O(n) while-loop in `handleCanvasTap` with O(1) `pixelSet.contains(key)` lookup
- Passed `segmentPixelSets` and `cachedSegmentInfos` from `viewModel` at the call site in `MapView.swift`

## Task Commits

Each task was committed atomically:

1. **Task 1: SegmentInfo und segmentPixelSets in MapViewModel** - `080f71d` (feat)
2. **Task 2: InteractiveMapView auf gecachte Daten umstellen** - `27661ca` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift` - Added SegmentInfo struct, segmentPixelSets, cachedSegmentInfos, rebuildSegmentPixelSets(), updateCachedSegmentInfos(); wired calls at all map/segments update points
- `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift` - Removed private SegmentInfo struct and segmentInfos(from:) method; added segmentPixelSets/cachedSegmentInfos properties; replaced O(n) hit-test with O(1) Set lookup; overlays now read cachedSegmentInfos
- `ValetudoApp/ValetudoApp/Views/MapView.swift` - Passes viewModel.segmentPixelSets and viewModel.cachedSegmentInfos to InteractiveMapView

## Decisions Made
- `SegmentInfo` is a top-level struct in MapViewModel.swift (not nested inside MapViewModel class) to keep it accessible as a plain public type
- `segmentPixelSets` is `@ObservationIgnored` because SwiftUI Views never directly observe it — it's only read during gesture handling
- `cachedSegmentInfos` is fully observable so SwiftUI can re-render overlays when rooms change names or map reloads

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None - build succeeded on first attempt.

## Known Stubs
None.

## Next Phase Readiness
- MapViewModel now exposes `segmentPixelSets` and `cachedSegmentInfos` — future phases can read these directly
- Phase 25 (View Architecture) can decompose MapContentView without worrying about hit-testing logic being in the view
- Phase 28 (Tests) can unit-test `rebuildSegmentPixelSets()` and `updateCachedSegmentInfos()` in isolation since they are deterministic functions of `map` and `segments`

## Self-Check: PASSED

---
*Phase: 24-map-performance*
*Completed: 2026-04-04*
