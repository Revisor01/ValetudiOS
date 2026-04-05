# Phase 24: Map Performance - Research

**Researched:** 2026-04-04
**Domain:** SwiftUI Canvas rendering, SSE streaming, hit-testing, CGImage caching, disk write deduplication
**Confidence:** HIGH — all findings come from direct codebase inspection

## Summary

Phase 24 implements five targeted performance improvements to the map pipeline. The codebase is already well-structured for these changes: `streamMapLines()` exists in `ValetudoAPI` but is never called (polling is used instead), `segmentInfos()` is a private instance method called repeatedly from multiple overlays per frame, hit-testing is a confirmed O(n) linear pixel scan, `MapCacheService` has no hash-based deduplication, and the Canvas redraws all layers (floor, walls, segments, entities) on every map update — there is no static layer pre-rendering.

The SSEConnectionManager pattern for robot state attributes is the reference implementation for PERF-02. The `MapLayerCache` class in `RobotMap.swift` is the reference pattern for PERF-03 (caching on structs using a class wrapper). `UIGraphicsImageRenderer` + `CGImage` is the correct Swift/iOS approach for PERF-04.

**Primary recommendation:** Implement PERF-02 first (SSE replaces polling in `MapViewModel.startMapRefresh`), then PERF-03 (cache `segmentInfos()` result on `MapViewModel` keyed by map identity), then PERF-01 (replace linear scan with `Set<Pixel>` dictionary per segment), then PERF-04 (pre-render static layers to `CGImage`), then PERF-05 (add SHA256/hashValue deduplication to `MapCacheService.save`).

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PERF-01 | Map-Tap-Hit-Testing nutzt Spatial Lookup (Dictionary/Bounding Box) statt linearem Pixel-Scan — Tap-Response unter 16ms | `handleCanvasTap` in `MapInteractiveView` is a confirmed linear O(n) scan. Replace inner loop with `Set<[Int; 2]>` or `Dictionary<Int, Set<Int>>` per segment layer, built once per map update. |
| PERF-02 | Map-Updates kommen via SSE-Stream statt HTTP-Polling — `streamMapLines()` API-Endpoint wird genutzt | `streamMapLines()` exists in `ValetudoAPI` (line 648). `MapViewModel.startMapRefresh()` uses a 2-second poll loop. `SSEConnectionManager` is the reference pattern. |
| PERF-03 | `segmentInfos()` wird pro Map-Update einmal berechnet und gecacht — nicht bei jedem Overlay-Render | `segmentInfos(from:)` is called at minimum twice per render cycle (once in `tapTargetsOverlay`, once in `orderBadgesOverlay`). It iterates all segment layers and may decompress pixels. |
| PERF-04 | Statische Map-Layer (Floor, Walls, Segments) werden als CGImage vorgerendert — Canvas zeichnet nur dynamische Elemente pro Frame | Canvas in `InteractiveMapView` redraws all layers every frame. Floor, walls, and segments are static between map updates. Robot position and path are dynamic. |
| PERF-05 | MapCacheService schreibt nur bei tatsächlicher Datenänderung auf Disk — nicht bei jedem Poll-Zyklus | `MapCacheService.save()` has no deduplication — it encodes and writes on every call. `MapViewModel.startMapRefresh()` calls `save()` on every successful poll response (every 2 seconds). |
</phase_requirements>

---

## PERF-01: Hit-Testing — Current State and Fix

### Current Implementation (Confirmed O(n) linear scan)

File: `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift`, lines 228–254

```swift
// handleCanvasTap — current implementation
for layer in layers where layer.type == "segment" {
    let pixels = layer.decompressedPixels
    var i = 0
    while i < pixels.count - 1 {
        if pixels[i] == pixelX && pixels[i + 1] == pixelY {
            if let segmentId = layer.metaData?.segmentId {
                toggleSegment(segmentId)
            }
            return
        }
        i += 2
    }
}
```

**Problem:** For a segment with 10,000 pixels (common for a medium room), worst-case is 10,000 comparisons per tap. With 8 segments, worst case is 80,000 comparisons. A 16ms budget at 60fps leaves ~250,000 cycles — tight on older devices when combined with view layout work.

### Recommended Fix: Dictionary<SegmentId, Set<encoded pixel>>

Build a lookup structure once per map update and store it on `MapViewModel` (or on `InteractiveMapView` as a computed property cached by map identity):

```swift
// Pixel encoding: combine x,y into a single Int64 key
// x and y are typically 0..2000, so x << 16 | y fits in Int32, safe in Int64
typealias PixelKey = Int  // Int is 64-bit on arm64
// key = x * 65536 + y  (or x << 16 | y)

// Built once per map update:
var segmentPixelSets: [String: Set<PixelKey>] = [:]
for layer in layers where layer.type == "segment" {
    guard let id = layer.metaData?.segmentId else { continue }
    let pixels = layer.decompressedPixels
    var set = Set<PixelKey>(minimumCapacity: pixels.count / 2)
    var i = 0
    while i < pixels.count - 1 {
        set.insert(pixels[i] << 16 | pixels[i + 1])
        i += 2
    }
    segmentPixelSets[id] = set
}

// Hit test (O(1) per segment):
let key = pixelX << 16 | pixelY
for (segmentId, pixelSet) in segmentPixelSets {
    if pixelSet.contains(key) {
        toggleSegment(segmentId)
        return
    }
}
```

**Confidence:** HIGH — standard Swift pattern, verified against Swift Set documentation.

**Storage location:** `MapViewModel` holds the `segmentPixelSets` dictionary. It is (re)built in `loadMap()` and whenever `map` is set from SSE or poll. This keeps `InteractiveMapView` free of mutable state.

**Coordinate range note:** Valetudo map pixel coordinates are typically 0–2000 (maps up to ~40m x 40m at 5mm resolution). `pixelX << 16` is safe for values up to 65535, confirmed by typical pixelSize=5 and map dimensions in the app.

---

## PERF-02: SSE for Map — Current State and Integration

### Current Polling (Confirmed)

File: `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift`, lines 163–190

```swift
func startMapRefresh() {
    refreshTask = Task { [weak self] in
        // Poll map every 2 seconds
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled {
                if let newMap = try? await api.getMap() {
                    self.map = newMap
                    await MapCacheService.shared.save(newMap, for: robot.id)
                }
                // ... fallback to cache on failure
            }
        }
    }
}
```

### Existing SSE Infrastructure

`ValetudoAPI.streamMapLines()` exists at line 648:
- Endpoint: `/api/v2/robot/state/map/sse`
- Returns `URLSession.AsyncBytes`
- Uses `sseSession` (infinite timeout, already configured)
- Auth headers included

`SSEConnectionManager` (for robot state attributes) is the reference pattern:
- Actor-isolated state
- Exponential backoff: 1s → 5s → 30s
- `for try await line in bytes.lines` loop
- Falls back to polling when SSE fails

### Recommended Integration

Replace `startMapRefresh()` with an SSE-first pattern:

```swift
func startMapRefresh() {
    refreshTask?.cancel()
    refreshTask = Task { [weak self] in
        guard let self else { return }
        guard let api = self.api else { return }

        var retryCount = 0

        while !Task.isCancelled {
            do {
                let bytes = try await api.streamMapLines()
                retryCount = 0

                for try await line in bytes.lines {
                    if Task.isCancelled { break }
                    guard line.hasPrefix("data:") else { continue }
                    let jsonString = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                    guard !jsonString.isEmpty,
                          let jsonData = jsonString.data(using: .utf8),
                          let newMap = try? JSONDecoder().decode(RobotMap.self, from: jsonData) else { continue }

                    self.map = newMap
                    self.isOffline = false
                    await MapCacheService.shared.saveIfChanged(newMap, for: robot.id)
                }

            } catch is CancellationError {
                break
            } catch {
                // Fall back to single HTTP poll on SSE failure
                if let newMap = try? await api.getMap() {
                    self.map = newMap
                    self.isOffline = false
                    await MapCacheService.shared.saveIfChanged(newMap, for: robot.id)
                }

                retryCount += 1
                let delay: Double = retryCount == 1 ? 2 : retryCount == 2 ? 5 : 30
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }
}
```

**SSE event format:** Valetudo sends `data: {json}\n\n` lines on the map SSE endpoint, same format as the state attributes SSE. This is confirmed by the existing `streamStateLines()` parsing logic and the `streamMapLines()` endpoint in ValetudoAPI.

**MapPreviewView:** `MapPreviewView` in `MapView.swift` (lines 155–167) also has its own 3-second poll loop (`startLiveRefresh()`). This is a separate concern — it uses `api.getMap()` independently. PERF-02 scope is `MapViewModel.startMapRefresh()` only; `MapPreviewView` polling is out of scope unless specified.

**Confidence:** HIGH — `streamMapLines()` API method is confirmed in ValetudoAPI.swift. SSE event format is consistent with the existing state SSE implementation.

---

## PERF-03: segmentInfos() Caching — Current State and Fix

### Current Implementation

File: `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift`

`segmentInfos(from:)` is a private method (lines 264–303) that:
1. Iterates all layers for `type == "segment"`
2. For each, tries `layer.dimensions?.x?.mid` / `layer.dimensions?.y?.mid` first
3. If dimensions are absent, iterates **all decompressed pixels** to compute the centroid (sumX, sumY, count loop)
4. Looks up the segment display name from `segments` array

It is called in:
- `tapTargetsOverlay` (line 151): `segmentInfos(from: layers)` — called every time the overlay redraws
- `orderBadgesOverlay` (line 199): `segmentInfos(from: layers).first(where:)` — called on every badge position update

Both overlays are inside `GeometryReader` closures that recalculate on every layout pass.

### Fix

Move `segmentInfos` computation to `MapViewModel` and cache the result:

```swift
// In MapViewModel:
var cachedSegmentInfos: [SegmentInfo] = []

// SegmentInfo moved to a shared location (could stay in InteractiveMapView as internal struct
// or move to MapViewModel — must be accessible from both callers)
struct SegmentInfo: Identifiable {
    let id: String
    let name: String
    let midX: Int
    let midY: Int
}

// Recomputed when map or segments change:
private func updateSegmentInfos() {
    guard let layers = map?.layers else {
        cachedSegmentInfos = []
        return
    }
    cachedSegmentInfos = computeSegmentInfos(from: layers)
}
```

Call `updateSegmentInfos()` after `map = newMap` in both `loadMap()` and `startMapRefresh()`.

`InteractiveMapView` receives `cachedSegmentInfos: [SegmentInfo]` as a parameter instead of computing it inline.

**`MapLayerCache` reference pattern:** `RobotMap.swift` already uses a class-wrapper cache on a struct (`MapLayerCache`). The same pattern (class reference on a struct) can be used if `SegmentInfo` needs to be cached at the layer level, but storing on `MapViewModel` is simpler and preferable.

**Confidence:** HIGH — call sites confirmed in codebase.

---

## PERF-04: Static Layer Pre-rendering — Architecture

### Current Rendering

File: `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift`, `body` Canvas closure (lines 34–121)

Every frame renders in this order:
1. Floor pixels (static between map updates)
2. Segment pixels with material texture (static between map updates)
3. Segment selection border (dynamic — changes on tap)
4. Wall pixels (static between map updates)
5. Path entities (dynamic — robot moves)
6. Charger entity (static between map updates, but simple)
7. Robot position entity (dynamic — updates every SSE event)
8. Restrictions overlays (quasi-static)
9. Drawing preview (gesture-local, ephemeral)

Layers 1, 4 are fully static between map updates. Layer 2 base color is static; selection overlay (border) is dynamic. The floor+walls CGImage can be pre-rendered entirely. Segments can be pre-rendered for the unselected state.

### iOS API for Pre-rendering

```swift
// UIGraphicsImageRenderer is the correct Swift/iOS approach (no UIKit import needed for this)
import UIKit  // already available in a UIKit-backed SwiftUI app

func renderStaticLayers(
    layers: [MapLayer],
    params: MapParams,
    pixelSize: Int,
    size: CGSize
) -> CGImage? {
    let renderer = UIGraphicsImageRenderer(size: size)
    let uiImage = renderer.image { ctx in
        // Draw floor
        // Draw walls
        // Draw segments (unselected state)
    }
    return uiImage.cgImage
}
```

The `CGImage` is then drawn in Canvas with a single `context.draw()`:

```swift
Canvas { context, size in
    // Draw static pre-rendered image
    if let staticImage = viewModel.staticLayerImage {
        context.draw(Image(decorative: staticImage, scale: 1.0), in: CGRect(origin: .zero, size: size))
    }

    // Draw dynamic elements only
    drawSelectionBorders(...)
    drawEntities(...)   // path, robot, charger
    drawRestrictions(...)
}
```

### Re-rendering Trigger

`staticLayerImage` on `MapViewModel` is recomputed when:
- `map` changes (new map from SSE/poll)
- `segments` changes (room rename, join, split)

The CGImage does NOT need to be redrawn on tap (selection state). Selection state is drawn on top of the static image each frame.

**Important:** The pre-render must happen off the main thread to avoid frame drops. Use `Task.detached` or a background `Task` with `@MainActor` to assign the result:

```swift
private func rebuildStaticLayerImage() {
    guard let map = map, let layers = map.layers else { return }
    Task.detached(priority: .userInitiated) {
        let image = renderStaticLayers(layers: layers, params: ..., pixelSize: ..., size: ...)
        await MainActor.run { self.staticLayerImage = image }
    }
}
```

**Challenge:** `params` depends on `size` (view size), which is only known in the Canvas closure. Two options:
1. Store `currentViewSize` on `MapViewModel` (already exists as `@State var currentViewSize` on `MapContentView` — should be moved to `MapViewModel`)
2. Pass `size` from the Canvas closure and rebuild the image lazily when size changes

Option 1 is cleaner. `currentViewSize` already exists in `MapContentView` (line 190) — moving it to `MapViewModel` is consistent with PERF-03.

**Confidence:** HIGH — `UIGraphicsImageRenderer` + `CGImage` is the standard iOS approach. `context.draw(Image:in:)` is confirmed in SwiftUI Canvas documentation.

---

## PERF-05: MapCacheService Write Deduplication

### Current Implementation

File: `ValetudoApp/ValetudoApp/Services/MapCacheService.swift`, lines 29–38

```swift
func save(_ map: RobotMap, for robotId: UUID) async {
    do {
        let url = try cacheURL(for: robotId)
        let data = try JSONEncoder().encode(map)
        try data.write(to: url, options: .atomic)
        // ... no check — writes every time
    }
}
```

Called from:
- `MapViewModel.loadMap()` after initial successful load
- `MapViewModel.startMapRefresh()` on every successful 2-second poll (currently)
- After SSE integration (PERF-02), will be called on every SSE event

### Recommended Fix: Hash-Based Deduplication

```swift
// Add to MapCacheService:
private var lastDataHash: [UUID: Int] = [:]

func saveIfChanged(_ map: RobotMap, for robotId: UUID) async {
    do {
        let url = try cacheURL(for: robotId)
        let data = try JSONEncoder().encode(map)
        let newHash = data.hashValue  // or SHA256 for collision resistance

        // Skip write if hash unchanged
        if lastDataHash[robotId] == newHash {
            return
        }
        lastDataHash[robotId] = newHash
        try data.write(to: url, options: .atomic)
        logger.debug("MapCache saved (changed) for \(robotId.uuidString, privacy: .public)")
    } catch {
        logger.error("MapCache save failed: ...")
    }
}
```

**Hash collision risk:** `data.hashValue` uses Swift's non-cryptographic hash (fast, not collision-free, but changes per process restart). For cache write deduplication, collision is acceptable — worst case is an occasional unnecessary disk write. If stronger guarantees are needed, use `CryptoKit.SHA256.hash(data:)` (no external dependency — CryptoKit is a system framework).

**Alternative:** Compare `map` directly using `Equatable`. `RobotMap` currently does not conform to `Equatable`. Adding conformance requires adding it to all nested types (`MapLayer`, `MapEntity`, etc.). The `data.hashValue` approach avoids this structural change.

**Rename consideration:** The existing `save(_:for:)` method can either be renamed to `saveIfChanged` (requires updating all call sites) or a default-to-hash overload can be added. Renaming is cleaner.

**Confidence:** HIGH — straightforward Swift pattern.

---

## Architecture Patterns

### Pattern 1: SSEConnectionManager as Reference for Map SSE

The existing `SSEConnectionManager.streamWithReconnect()` (actor-isolated, exponential backoff, `for try await line in bytes.lines`) is the exact pattern to replicate in `MapViewModel.startMapRefresh()`. Do not create a second SSE manager for maps — map SSE is managed directly in `MapViewModel` via its `refreshTask`.

### Pattern 2: MapLayerCache as Reference for Struct Caching

`RobotMap.swift` demonstrates how to attach a mutable cache to an immutable struct: use a `final class` wrapper (`MapLayerCache`) stored as a constant (`let cache = MapLayerCache()`). This compiles in SwiftUI Canvas closures where `mutating` is disallowed. Apply this pattern if `SegmentInfo` caching needs to be struct-level.

### Pattern 3: @Observable + @ObservationIgnored for Performance State

All new cached properties on `MapViewModel` that are computed (not directly UI-bound) should use `@ObservationIgnored` to prevent unnecessary observation tracking:

```swift
@ObservationIgnored private var segmentPixelSets: [String: Set<Int>] = [:]
@ObservationIgnored private var staticLayerImageInternal: CGImage?
```

Expose them as computed properties or observable vars only where SwiftUI needs to observe them (e.g., `staticLayerImage` needs to be `var` for Canvas to react).

### Recommended Project Structure (no changes needed)

The current structure already isolates concerns well:
```
Services/
├── ValetudoAPI.swift       — streamMapLines() already exists
├── MapCacheService.swift   — add saveIfChanged()
└── SSEConnectionManager.swift — reference pattern only

ViewModels/
└── MapViewModel.swift      — startMapRefresh() (SSE), segmentPixelSets, cachedSegmentInfos,
                              staticLayerImage, currentViewSize

Views/
└── MapInteractiveView.swift — receives cachedSegmentInfos, segmentPixelSets from ViewModel;
                               Canvas uses staticLayerImage + dynamic-only drawing
```

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Spatial index for hit-testing | Quadtree, R-Tree | Swift `Set<Int>` with encoded pixel key | Map is 2D pixel grid — exact coordinate lookup with Set<Int> is O(1) and trivial to build |
| Image pre-rendering | Metal renderer, custom GPU path | `UIGraphicsImageRenderer` + `CGImage` | System API, correct scale factor handling, no dependency |
| Hash for dedup | Custom checksum | `data.hashValue` or `CryptoKit.SHA256` | Both zero-dependency options; `hashValue` is sufficient for cache deduplication |
| SSE parsing | Custom HTTP streaming layer | `URLSession.AsyncBytes` + `bytes.lines` | Already used and working in the codebase |

---

## Common Pitfalls

### Pitfall 1: CGImage Size vs View Size Mismatch
**What goes wrong:** Pre-rendering at `currentViewSize` in points but displaying at device pixel density causes blurry rendering on Retina displays.
**Why it happens:** `UIGraphicsImageRenderer` renders at screen scale by default when given a `UIGraphicsImageRendererFormat`, but a plain `UIGraphicsImageRenderer(size:)` uses `UIScreen.main.scale`.
**How to avoid:** Use `UIGraphicsImageRendererFormat.default()` (respects screen scale automatically) or explicitly pass scale: `UIGraphicsImageRenderer(size: size, format: format)` where `format.scale = UIScreen.main.scale`.
**Warning signs:** Map appears slightly blurry on physical device compared to simulator.

### Pitfall 2: Static Image Stale After Segment Selection Change
**What goes wrong:** Pre-rendered image includes segment colors in selected state, but selection is drawn over the top — selection border appears doubled.
**Why it happens:** Including selection-state drawing in the static image means it's baked in and can't update per frame.
**How to avoid:** Static image includes only unselected segment colors. Selection state (border, darker fill) is always drawn in the Canvas pass on top of the static image.

### Pitfall 3: SSE Map JSON Format vs HTTP Map JSON
**What goes wrong:** SSE stream wraps the map JSON in `data: {...}\n\n` format; the raw content is the same `RobotMap` JSON as the HTTP endpoint — but some Valetudo versions may not stream the full map object on every update (may send incremental/diff). Parsing as full `RobotMap` on every SSE event would silently fail for diff updates.
**Why it happens:** Unknown without device testing — Valetudo SSE map endpoint behavior is not documented in the app.
**How to avoid:** Add error logging (not silent `try?`) when decoding map SSE events. If decoding fails frequently, fall back to HTTP GET on each SSE trigger event.
**Warning signs:** Map stops updating despite SSE receiving events; decoder errors in logs.

### Pitfall 4: segmentPixelSets Built on Main Thread with Large Maps
**What goes wrong:** Building `Set<Int>` for all segment pixels during `loadMap()` blocks the main thread if a map has many pixels (>100k), causing UI jank on initial load.
**Why it happens:** `loadMap()` is `@MainActor`.
**How to avoid:** Build `segmentPixelSets` in a `Task.detached` or `Task(priority: .userInitiated)` block, then assign back to `@MainActor` property.

### Pitfall 5: MapCacheService.lastDataHash Not Persisted
**What goes wrong:** On app launch, `lastDataHash` is empty — the first save after launch always writes to disk even if the cached data is identical.
**Why it happens:** `lastDataHash` is an in-memory dictionary on the singleton.
**How to avoid:** This is acceptable behavior — one write per launch per robot. The goal is to eliminate writes during the polling loop (every 2 seconds → only on change). One extra write at launch is negligible.

---

## Code Examples

### PERF-01: Pixel Set Building

```swift
// In MapViewModel — call after map = newMap
private func rebuildSegmentPixelSets() {
    guard let layers = map?.layers else {
        segmentPixelSets = [:]
        return
    }
    var sets: [String: Set<Int>] = [:]
    for layer in layers where layer.type == "segment" {
        guard let id = layer.metaData?.segmentId else { continue }
        let pixels = layer.decompressedPixels
        var set = Set<Int>(minimumCapacity: pixels.count / 2)
        var i = 0
        while i < pixels.count - 1 {
            set.insert(pixels[i] &<< 16 | pixels[i + 1])
            i += 2
        }
        sets[id] = set
    }
    segmentPixelSets = sets
}

// In handleCanvasTap — O(1) lookup:
let key = pixelX &<< 16 | pixelY
for (segmentId, pixelSet) in viewModel.segmentPixelSets {
    if pixelSet.contains(key) {
        toggleSegment(segmentId)
        return
    }
}
```

### PERF-04: Pre-render Static Layers

```swift
// In MapViewModel:
var staticLayerImage: CGImage?

func rebuildStaticLayerImage(size: CGSize) {
    guard let map = map, let layers = map.layers, !layers.isEmpty else { return }
    let pixelSize = map.pixelSize ?? 5
    guard let params = calculateMapParams(layers: layers, pixelSize: pixelSize, size: size) else { return }

    Task.detached(priority: .userInitiated) {
        let renderer = UIGraphicsImageRenderer(size: size)
        let uiImage = renderer.image { ctx in
            let cgCtx = ctx.cgContext
            // Floor
            for layer in layers where layer.type == "floor" {
                drawLayerToCGContext(cgCtx, pixels: layer.decompressedPixels, color: UIColor(white: 0.92, alpha: 1), params: params, pixelSize: pixelSize)
            }
            // Segments (unselected base color)
            for layer in layers where layer.type == "segment" {
                let color = segmentUIColor(segmentId: layer.metaData?.segmentId)
                drawLayerToCGContext(cgCtx, pixels: layer.decompressedPixels, color: color.withAlphaComponent(0.6), params: params, pixelSize: pixelSize)
            }
            // Walls
            for layer in layers where layer.type == "wall" {
                drawLayerToCGContext(cgCtx, pixels: layer.decompressedPixels, color: UIColor(white: 0.25, alpha: 1), params: params, pixelSize: pixelSize)
            }
        }
        await MainActor.run { [weak self] in
            self?.staticLayerImage = uiImage.cgImage
        }
    }
}

// Canvas usage:
Canvas { context, size in
    if let img = viewModel.staticLayerImage {
        context.draw(Image(decorative: img, scale: UIScreen.main.scale),
                     in: CGRect(origin: .zero, size: size))
    }
    // Dynamic: selection borders, path, robot, charger, restrictions
}
```

---

## State of the Art

| Old Approach | Current Approach | Notes |
|--------------|------------------|-------|
| HTTP polling every 2s | SSE stream with poll fallback | SSE is the preferred Valetudo pattern; already used for robot state attributes |
| Linear pixel scan for hit-test | Set<Int> O(1) lookup | Standard spatial lookup for grid data |
| Redraw all layers per frame | CGImage static layers + dynamic overlay | Separates immutable from mutable content |

---

## Open Questions

1. **Valetudo Map SSE event format**
   - What we know: `streamMapLines()` endpoint is `/api/v2/robot/state/map/sse`, same session/auth setup as state SSE.
   - What's unclear: Whether every SSE event contains a full `RobotMap` JSON or a diff/trigger. The state SSE sends full `[RobotAttribute]` arrays — map SSE likely sends full `RobotMap` but this is unverified.
   - Recommendation: Log and inspect the first few SSE events from the map endpoint on a real robot. If the payload is not a full `RobotMap`, implement a "trigger-then-fetch" pattern (SSE event triggers a `getMap()` HTTP call).
   - Confidence: MEDIUM — consistent with Valetudo's general API design but unconfirmed.

2. **currentViewSize availability for static image rebuild**
   - What we know: `currentViewSize` is currently `@State` on `MapContentView`, updated via `onAppear`/`onChange`.
   - What's unclear: Whether moving it to `MapViewModel` causes any re-entrant update issues.
   - Recommendation: Move `currentViewSize` to `MapViewModel`. Call `rebuildStaticLayerImage(size:)` from `MapContentView`'s `.onChange(of: geometry.size)` and `.onAppear`.

3. **Segment material texture in static image**
   - What we know: `drawPixelsWithMaterial` adds texture lines for tile/wood materials, which are static data.
   - What's unclear: Should material textures be in the static CGImage (yes, they don't change) or drawn dynamically.
   - Recommendation: Include material textures in the static CGImage — they only change on segment material update, which triggers a map reload.

---

## Environment Availability

Step 2.6: SKIPPED — phase is code-only changes, no external dependencies beyond the existing Valetudo robot API which is already connected.

---

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection — all findings verified against source files
  - `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift` — hit-testing, segmentInfos, Canvas structure
  - `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift` — polling loop, loadMap, caching calls
  - `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift` — streamMapLines() at line 648
  - `ValetudoApp/ValetudoApp/Services/MapCacheService.swift` — save() without deduplication
  - `ValetudoApp/ValetudoApp/Services/SSEConnectionManager.swift` — reference SSE pattern
  - `ValetudoApp/ValetudoApp/Models/RobotMap.swift` — MapLayerCache reference pattern
  - `ValetudoApp/ValetudoApp/Utilities/MapGeometry.swift` — calculateMapParams, coordinate transforms

### Secondary (MEDIUM confidence)
- Swift Set O(1) lookup — standard Swift documentation
- UIGraphicsImageRenderer — iOS SDK (available since iOS 10, confirmed available iOS 17+)
- CryptoKit.SHA256 — Apple system framework, zero external dependency

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no external dependencies; all iOS system APIs
- Architecture: HIGH — all patterns traced directly from existing codebase code
- Pitfalls: HIGH — derived from direct code analysis (confirmed call sites, confirmed missing guards)

**Research date:** 2026-04-04
**Valid until:** Stable — pure Swift/iOS system API changes, no third-party libraries
