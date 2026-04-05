---
phase: 24-map-performance
plan: 03
subsystem: ui
tags: [swift, swiftui, canvas, performance, cgimage, pre-rendering, uikit]

# Dependency graph
requires:
  - phase: 24-map-performance
    provides: "segmentPixelSets, cachedSegmentInfos, SSE-based map refresh (Plans 01-02)"
provides:
  - "staticLayerImage: CGImage? in MapViewModel — pre-rendered floor+segments+walls"
  - "rebuildStaticLayerImage(size:) — background-thread CGImage renderer"
  - "Canvas draws only dynamic elements (selection, entities, restrictions) per frame"
affects: [25-view-architecture, 28-tests]

# Tech tracking
tech-stack:
  added:
    - UIKit (UIGraphicsImageRenderer, UIColor, UIScreen) in MapViewModel and MapInteractiveView
  patterns:
    - "Static-layer pre-rendering: render immutable pixels to CGImage once on background thread, draw as single Image in Canvas"
    - "Task.detached + MainActor.run for off-main-thread rendering with safe main-thread assignment"
    - "Image(decorative:scale:in:) for retina-correct CGImage rendering in SwiftUI Canvas"
    - "Fallback path: pixel-by-pixel Canvas drawing while CGImage not yet ready"

key-files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift
    - ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift
    - ValetudoApp/ValetudoApp/Views/MapView.swift

key-decisions:
  - "staticLayerImage is fully @Observable so SwiftUI Canvas re-renders when pre-render completes asynchronously"
  - "lastRenderSize is @ObservationIgnored — used only for re-triggering rebuild on size changes, not observed by SwiftUI"
  - "Background rendering uses UIGraphicsImageRenderer (UIKit) for direct CGContext pixel fill — faster than SwiftUI Canvas for batch pixel ops"
  - "Fallback to pixel-by-pixel Canvas drawing ensures correct display before background thread completes on first render"
  - "Selected segments drawn dynamically (opacity 0.9 + border) over static image — not baked into pre-render to stay reactive to selection state changes"
  - "rebuildStaticLayerImage called at all map update sites only when lastRenderSize.width > 0 (view has appeared)"

requirements-completed: [PERF-04]

# Metrics
duration: 5min
completed: 2026-04-04
---

# Phase 24 Plan 03: Static Layer Pre-Rendering Summary

**Floor, walls, and segments pre-rendered as a single CGImage on a background thread — Canvas draws only dynamic elements (selection, entities, restrictions) per frame**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-04-04T23:36:09Z
- **Completed:** 2026-04-04T23:41:12Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added `staticLayerImage: CGImage?` observable property and `lastRenderSize: CGSize` @ObservationIgnored tracking to MapViewModel
- Added `segmentUIColors` static array (pixel-identical UIColor values to `segmentColors` in InteractiveMapView)
- Implemented `rebuildStaticLayerImage(size:)` using `UIGraphicsImageRenderer` on `Task.detached(priority: .userInitiated)` background thread:
  - Renders floor pixels (gray 0.92)
  - Renders segment pixels with full material texture logic (tile/wood/wood_horizontal/wood_vertical) at opacity 0.6
  - Renders wall pixels at 20% scale offset-centered (matching InteractiveMapView.drawWalls)
  - Assigns resulting `CGImage` back to `@MainActor` via `MainActor.run { [weak self] in self?.staticLayerImage = ... }`
- Wired `rebuildStaticLayerImage` after all 8 map/segments update call sites (loadMap, 3 SSE paths, renameRoom, 2x joinRooms, 2x splitRoom)
- Added `rebuildStaticLayerImage` calls in `MapContentView.onAppear` and `onChange(of: geometry.size)` to trigger rebuild on first render and rotation/fullscreen changes
- Updated Canvas in `InteractiveMapView` to draw `staticLayerImage` via `context.draw(Image(decorative:scale:in:))` as a single draw call
- Added pixel-by-pixel fallback rendering path for the brief window before the background thread completes
- Selected segments still drawn dynamically over the static image (opacity 0.9 solid fill + border stroke)
- All dynamic elements unchanged: path, charger, robot, restrictions, drawing preview

## Task Commits

Each task was committed atomically:

1. **Task 1: Static Layer Pre-Rendering in MapViewModel (PERF-04)** — `fd25f54` (feat)
2. **Task 2: Canvas auf staticLayerImage umstellen (PERF-04)** — `372a4d8` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift` — Added `import UIKit`; `staticLayerImage`, `lastRenderSize` properties; `segmentUIColors`, `segmentUIColor()`, `rebuildStaticLayerImage(size:)` methods; wired rebuild calls at all 8 map/segments update points
- `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift` — Added `import UIKit`; `staticLayerImage: CGImage?` property; replaced static Canvas drawing with `context.draw(Image(decorative:scale:in:))`; added pixel-by-pixel fallback; kept all helper drawing methods
- `ValetudoApp/ValetudoApp/Views/MapView.swift` — Added `viewModel.rebuildStaticLayerImage(size:)` in `onAppear` and `onChange(of: geometry.size)`; passes `staticLayerImage: viewModel.staticLayerImage` to InteractiveMapView

## Decisions Made

- `staticLayerImage` is fully observable so SwiftUI Canvas re-renders when the async CGImage assignment arrives from the background thread
- `lastRenderSize` is `@ObservationIgnored` because it is only an internal trigger for rebuild decisions, not a SwiftUI-reactive value
- `UIGraphicsImageRenderer` chosen over SwiftUI Canvas for the off-screen render — direct `CGContext.fill(rect)` is faster than SwiftUI `context.fill(Path(rect))` for thousands of pixels
- Material texture logic replicated exactly from `drawPixelsWithMaterial` to maintain visual parity
- Wall rendering matches `drawWalls` exactly: 20% wall scale, 40% offset centering

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - build succeeded on first attempt for both tasks.

## Known Stubs

None.

## Next Phase Readiness

- Phase 24 is now complete: SSE refresh (01), O(1) hit-testing (02), static pre-rendering (03)
- Phase 25 (View Architecture) can decompose MapContentView knowing the Canvas is already optimized
- Phase 28 (Tests) can unit-test `rebuildStaticLayerImage` in isolation (deterministic function of map data + size)

## Self-Check: PASSED
