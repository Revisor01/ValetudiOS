# Phase 22: Map Geometry Unification - Research

**Researched:** 2026-04-04
**Domain:** Swift/SwiftUI iOS — Map coordinate math, state centralization, refactoring
**Confidence:** HIGH

## Summary

Phase 22 eliminates two classes of duplication in the map subsystem. First, the `calculateMapParams` function is copied verbatim in three view files and reimplemented inline in one ViewModel — four total instances. Second, `selectedSegmentIds` in `MapViewModel` and `selectedSegments` in `RobotDetailViewModel` are independent `[String]` arrays with no synchronization, causing UX breakage when the user switches between the map view and the detail view.

The fix for DEBT-01 is purely mechanical: extract the function body into a `static func` in a new `Utilities/MapGeometry.swift` file, update all four call sites to delegate to it, and verify the `MapMiniMapView` copy uses a `padding` of 10 (not 20) — that difference is intentional and must be handled via a parameter, not by writing two versions.

The fix for DEBT-02 (and VIEW-04 by extension) requires a clear architectural decision on where the shared state lives. `RobotManager` is the natural candidate because it is already the single source of truth per robot and is injected everywhere. A `roomSelection: [UUID: [String]]` dictionary keyed by robot ID gives each robot its own independent selection without any new type. Both `MapViewModel` and `RobotDetailViewModel` delegate reads and writes to that dictionary. The coordinate transform functions (`screenToMapCoords`/`mapToScreenCoords`) in `MapContentView` are already pure enough to lift into `MapGeometry.swift` alongside `calculateMapParams`.

**Primary recommendation:** Create `Utilities/MapGeometry.swift` with three exported free functions (`calculateMapParams`, `screenToMapCoords`, `mapToScreenCoords`) and add `roomSelections: [UUID: [String]]` to `RobotManager`. No new manager type is needed.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEBT-01 | `calculateMapParams` existiert nur einmal — keine duplizierten Kopien | Four copies found and fully analyzed; unified signature determined |
| DEBT-02 | Room-Selection-State in einer einzigen Quelle | Both state properties found; RobotManager lift strategy documented |
| VIEW-04 | Koordinaten-Transforms in einer einzigen, testbaren Utility | `screenToMapCoords`/`mapToScreenCoords` analyzed; extraction path clear |
</phase_requirements>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Swift Observation (`@Observable`) | Swift 5.9+ | Observable ViewModels without `@Published` | Already used throughout — no change |
| SwiftUI `Canvas` | iOS 15+ | Map pixel rendering | Already in use |
| `@MainActor` | Swift concurrency | Thread safety for UI state | Project-wide pattern |

No new dependencies are needed for this phase. All changes are pure Swift refactoring.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `roomSelections` dict in `RobotManager` | New `RoomSelectionManager` per robot | New type adds complexity with no benefit; `RobotManager` already holds per-robot dictionaries (`robotStates`, `apis`) |
| Free functions in `MapGeometry.swift` | Static methods on `MapParams` struct | Either works; free functions are simpler and match Swift convention for pure transforms |
| `padding` parameter on `calculateMapParams` | Two functions | Single function with parameter is cleaner and explicit |

---

## Architecture Patterns

### Recommended Project Structure (additions only)
```
ValetudoApp/ValetudoApp/
├── Utilities/
│   ├── Constants.swift          # already exists
│   └── MapGeometry.swift        # NEW — all map math in one place
├── Services/
│   └── RobotManager.swift       # add roomSelections: [UUID: [String]]
└── ViewModels/
    ├── MapViewModel.swift        # delegate selectedSegmentIds to RobotManager
    └── RobotDetailViewModel.swift # delegate selectedSegments to RobotManager
```

### Pattern 1: Unified `calculateMapParams`

**What:** Single static free function in `MapGeometry.swift`. Accepts `padding` parameter so `MapMiniMapView` (uses 10) and all other callers (use 20) share one implementation.

**When to use:** Wherever map pixel bounds and scale/offset are needed.

**Exact current signature (all four copies):**
```swift
// MapView.swift:792 — `func calculateMapParams` (on MapContentView extension)
// MapInteractiveView.swift:307 — `private func calculateMapParams` (on InteractiveMapView)
// MapMiniMapView.swift:169 — `private func calculateMapParams` (on MapMiniMapView)
// MapViewModel.swift:320-346 — inline, no function, padding=20
```

**Key difference confirmed:** `MapMiniMapView` uses `padding: CGFloat = 10`. All others use `padding: CGFloat = 20`. This is intentional — mini map is compact.

**Unified free function:**
```swift
// Utilities/MapGeometry.swift
func calculateMapParams(
    layers: [MapLayer],
    pixelSize: Int,
    size: CGSize,
    padding: CGFloat = 20
) -> MapParams? {
    var minX = Int.max, maxX = Int.min
    var minY = Int.max, maxY = Int.min

    for layer in layers {
        let pixels = layer.decompressedPixels
        guard !pixels.isEmpty else { continue }
        var i = 0
        while i < pixels.count - 1 {
            minX = min(minX, pixels[i])
            maxX = max(maxX, pixels[i])
            minY = min(minY, pixels[i + 1])
            maxY = max(maxY, pixels[i + 1])
            i += 2
        }
    }

    guard minX < Int.max else { return nil }

    let contentWidth = CGFloat(maxX - minX + pixelSize)
    let contentHeight = CGFloat(maxY - minY + pixelSize)
    let availableWidth = size.width - padding * 2
    let availableHeight = size.height - padding * 2
    let scaleX = availableWidth / contentWidth
    let scaleY = availableHeight / contentHeight
    let scale = min(scaleX, scaleY)
    let offsetX = padding + (availableWidth - contentWidth * scale) / 2 - CGFloat(minX) * scale
    let offsetY = padding + (availableHeight - contentHeight * scale) / 2 - CGFloat(minY) * scale

    return MapParams(scale: scale, offsetX: offsetX, offsetY: offsetY, minX: minX, minY: minY)
}
```

**MapViewModel inline copy (lines 319-346):** Does not call a function — it computes inline. Missing the `guard !pixels.isEmpty` check present in the other copies. This is a latent bug: if a layer has no pixels, the while-loop reads `pixels[i]` on an empty array — safe in Swift (loop condition `i < 0 - 1` is false) but worth noting. The unified function must preserve the `guard !pixels.isEmpty` guard.

### Pattern 2: Coordinate Transform Extraction

**What:** `screenToMapCoords` and `mapToScreenCoords` currently live on `MapContentView` (in `MapView.swift:459-480`). They are pure functions of `scale`, `offset`, `point`, and `viewSize` — no `self` state other than those two properties.

**`InteractiveMapView`** does NOT have its own `screenToMapCoords`/`mapToScreenCoords`. The tap hit-test in `InteractiveMapView` uses `calculateMapParams` for a different coordinate system (canvas pixel coords, not gesture-layer screen coords). These are two distinct transform layers:
- **Layer A (gesture):** `MapContentView.screenToMapCoords/mapToScreenCoords` — accounts for pinch/pan `scale` and `offset` state
- **Layer B (canvas):** `InteractiveMapView.handleCanvasTap` — uses `calculateMapParams` offsets to go from Canvas point to pixel

Both need to move to `MapGeometry.swift`, but they serve different purposes and must stay distinct.

**Free functions:**
```swift
// Utilities/MapGeometry.swift

func screenToMapCoords(
    _ point: CGPoint,
    scale: CGFloat,
    offset: CGSize,
    viewSize: CGSize
) -> CGPoint {
    let centerX = viewSize.width / 2
    let centerY = viewSize.height / 2
    let mapX = (point.x - offset.width - centerX) / scale + centerX
    let mapY = (point.y - offset.height - centerY) / scale + centerY
    return CGPoint(x: mapX, y: mapY)
}

func mapToScreenCoords(
    _ point: CGPoint,
    scale: CGFloat,
    offset: CGSize,
    viewSize: CGSize
) -> CGPoint {
    let centerX = viewSize.width / 2
    let centerY = viewSize.height / 2
    let screenX = (point.x - centerX) * scale + centerX + offset.width
    let screenY = (point.y - centerY) * scale + centerY + offset.height
    return CGPoint(x: screenX, y: screenY)
}
```

**Call site update:** `MapContentView` methods become one-liner wrappers that pass their `scale`, `offset`, `viewSize` to the free functions. Or the methods are removed entirely and call sites call the free functions directly.

### Pattern 3: Centralized Room Selection in RobotManager

**What:** `RobotManager` gains a `@Published`-equivalent (it's `@Observable`, so just a stored property) `roomSelections: [UUID: [String]]`. Both ViewModels read/write this dict using their `robot.id` as key.

**Why RobotManager (not a new RoomSelectionManager):**
- Already `@MainActor @Observable` — correct threading model
- Already injected into every ViewModel via init parameter
- Already holds per-robot dictionaries (`robotStates`, `apis`, `robotUpdateAvailable`)
- Adding one more dict follows existing patterns exactly

**RobotManager addition:**
```swift
// RobotManager.swift
var roomSelections: [UUID: [String]] = [:]

func toggleRoom(_ id: String, for robotId: UUID) {
    var current = roomSelections[robotId] ?? []
    if current.contains(id) {
        current.removeAll { $0 == id }
    } else {
        current.append(id)
    }
    roomSelections[robotId] = current
}

func clearRoomSelection(for robotId: UUID) {
    roomSelections[robotId] = nil
}

func selectedRooms(for robotId: UUID) -> [String] {
    roomSelections[robotId] ?? []
}
```

**MapViewModel migration:**
```swift
// Before
var selectedSegmentIds: [String] = []

// After — computed proxy, no local state
var selectedSegmentIds: [String] {
    get { robotManager.selectedRooms(for: robot.id) }
    set { robotManager.roomSelections[robot.id] = newValue }
}
```

**RobotDetailViewModel migration:**
```swift
// Before
var selectedSegments: [String] = []

// After — same source via different property name (keep name for compatibility)
var selectedSegments: [String] {
    get { robotManager.selectedRooms(for: robot.id) }
    set { robotManager.roomSelections[robot.id] = newValue }
}
```

**Observation note:** With Swift Observation (`@Observable`), computed properties that read from another `@Observable` object (`robotManager`) DO trigger view updates automatically — the observation system tracks access through the chain. This is confirmed behavior in Swift 5.9+.

**Cleanup on clear:** Both ViewModels currently call `.removeAll()` on their local arrays. After migration this becomes `robotManager.clearRoomSelection(for: robot.id)`.

### Anti-Patterns to Avoid
- **Creating a `RoomSelectionManager` type:** No new type needed. Adding to `RobotManager` is the correct scope.
- **Making `selectedSegmentIds` a `@State` in views:** Room selection is domain state, not view state. It belongs in the ViewModel/Manager layer.
- **Extracting `handleCanvasTap` into `MapGeometry.swift`:** Hit-testing logic is view behavior (needs `editMode`, `map`, calls `toggleSegment`). Only the pure math helpers belong in Utilities.
- **Changing the `MapParams` struct:** It is defined in `MapView.swift:30-36` and used across all map files. Keep it there for now. Moving it would expand scope. The struct itself is fine.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Observable cross-ViewModel state | Custom publisher/notification | Computed property reading `@Observable` `RobotManager` | Swift Observation auto-tracks cross-object reads |
| Thread-safe room selection | Locks, actors | `@MainActor` on `RobotManager` | Already @MainActor; no additional synchronization needed |

---

## Common Pitfalls

### Pitfall 1: `MapMiniMapView` padding difference overlooked
**What goes wrong:** Unified function uses `padding: 20` (default), caller in `MapMiniMapView` forgets to pass `padding: 10` — mini map crops content.
**Why it happens:** Padding difference is subtle and not documented in code comments.
**How to avoid:** Add `padding: 10` explicitly to the `MapMiniMapView` call site. Add a comment explaining why.
**Warning signs:** Mini map shows map content cut off at edges after migration.

### Pitfall 2: `MapViewModel` inline copy missing `guard !pixels.isEmpty`
**What goes wrong:** The inline version in `MapViewModel.splitRoom()` (lines 323-333) does not have `guard !pixels.isEmpty` before the pixel loop. The unified function adds this guard. If behavior differs, split operations may silently skip empty layers differently.
**Why it happens:** The inline copy was written slightly differently.
**How to avoid:** The unified version should keep `guard !pixels.isEmpty` — this is a bug fix, not a behavioral change. An empty layer contributing nothing to bounds is correct.

### Pitfall 3: Computed property proxy breaks `@Binding` usage
**What goes wrong:** `InteractiveMapView` receives `selectedSegmentIds` as `@Binding var selectedSegmentIds: [String]` from `MapContentView`. If `MapViewModel.selectedSegmentIds` becomes a computed property, `$viewModel.selectedSegmentIds` must still work as a binding.
**Why it happens:** Swift `@Observable` computed properties support bindings via `Bindable(viewModel).selectedSegmentIds` — but the `$viewModel.selectedSegmentIds` syntax used in the current code requires `viewModel` to be a `@Bindable` or `@State`.
**How to avoid:** `MapContentView` uses `@State var viewModel: MapViewModel`. The `$viewModel.selectedSegmentIds` binding works on `@State` through `@Bindable` projection. Since `viewModel` is `@State`, `$viewModel` is `Binding<MapViewModel>`, and `$viewModel.selectedSegmentIds` works for stored properties. For computed properties on `@Observable` types accessed via `@State`, you need to verify this works or convert the `InteractiveMapView` binding to use a computed `Binding<[String]>` manually.

**Concrete risk:** `$viewModel.selectedSegmentIds` in `MapView.swift:231` passes a binding to `InteractiveMapView`. If `selectedSegmentIds` becomes a computed property on `MapViewModel`, this binding may not compile or may not propagate writes back correctly. The safe approach is to keep `selectedSegmentIds` as a stored property in `MapViewModel` and make it sync to/from `robotManager` explicitly (on set via a setter, on willClean clear the manager).

**Recommended solution:** Use explicit sync pattern instead of full computed proxy:
```swift
// MapViewModel — keep as stored property
var selectedSegmentIds: [String] = [] {
    didSet { robotManager.roomSelections[robot.id] = selectedSegmentIds }
}

// On init, load from robotManager
init(...) {
    ...
    self.selectedSegmentIds = robotManager.selectedRooms(for: robot.id)
}
```
And `RobotDetailViewModel` uses the same pattern with `selectedSegments`.
This avoids the computed-property-binding issue entirely.

### Pitfall 4: Clearing selection in one ViewModel doesn't reflect in the other
**What goes wrong:** `MapViewModel.cleanSegments()` clears `selectedSegmentIds.removeAll()` — if not synced to `RobotManager`, `RobotDetailViewModel.selectedSegments` remains stale.
**Why it happens:** The whole point of this phase is that they are currently independent.
**How to avoid:** After migration, any `.removeAll()` must go through `robotManager.clearRoomSelection(for:)`. Both ViewModels' clear operations must route through the shared store.

### Pitfall 5: `MapParams` struct is defined in `MapView.swift`, not `Utilities/`
**What goes wrong:** `MapGeometry.swift` free functions return `MapParams` — but `MapParams` is defined in `MapView.swift`. Swift compilation requires the struct to be visible when using it across files.
**Why it happens:** `MapParams` is currently co-located with its sole user (`MapContentView`).
**How to avoid:** Either move `MapParams` to `MapGeometry.swift` (clean) or leave it in `MapView.swift` and ensure `MapGeometry.swift` is in the same module (it is — same target). Since they share the same app target, no import is needed. Both options work; moving it to `MapGeometry.swift` is cleaner.

---

## Code Examples

### `MapGeometry.swift` file skeleton

```swift
// Utilities/MapGeometry.swift
import SwiftUI

// MARK: - Map Parameter Calculation

/// Calculates scale and offset needed to fit all map layers into the given view size.
/// - Parameters:
///   - layers: All map layers (floor, walls, segments)
///   - pixelSize: Map pixel size from RobotMap.pixelSize (typically 5)
///   - size: Available view size in points
///   - padding: Padding around the map content (default 20; use 10 for mini-map)
/// - Returns: MapParams with scale and offsets, or nil if no pixel data found
func calculateMapParams(
    layers: [MapLayer],
    pixelSize: Int,
    size: CGSize,
    padding: CGFloat = 20
) -> MapParams? { ... }

// MARK: - Coordinate Transforms

/// Converts a screen coordinate (accounting for pinch/pan gesture state) to map canvas coordinates.
func screenToMapCoords(
    _ point: CGPoint,
    scale: CGFloat,
    offset: CGSize,
    viewSize: CGSize
) -> CGPoint { ... }

/// Converts a map canvas coordinate to screen coordinates (accounting for pinch/pan gesture state).
func mapToScreenCoords(
    _ point: CGPoint,
    scale: CGFloat,
    offset: CGSize,
    viewSize: CGSize
) -> CGPoint { ... }
```

### `MapContentView` call site update

```swift
// Before (in MapContentView extension, MapView.swift)
func screenToMapCoords(_ point: CGPoint, viewSize: CGSize) -> CGPoint {
    // ... 5 lines of math
}

// After (thin wrapper — or remove wrapper, call free function directly at call sites)
func screenToMapCoords(_ point: CGPoint, viewSize: CGSize) -> CGPoint {
    ValetudoApp.screenToMapCoords(point, scale: scale, offset: offset, viewSize: viewSize)
}
```

### `MapMiniMapView` call site (critical — padding differs)

```swift
// MapMiniMapView.swift — must pass padding: 10
guard let p = calculateMapParams(layers: layers, pixelSize: pixelSize, size: size, padding: 10)
```

---

## Open Questions

1. **`$viewModel.selectedSegmentIds` binding compatibility with computed property**
   - What we know: `InteractiveMapView` receives this as `@Binding`. If the property becomes computed, binding behavior changes.
   - What's unclear: Whether Swift Observation's `Bindable` projection handles computed properties on `@Observable` correctly.
   - Recommendation: Use the `didSet` sync pattern (stored property + `didSet`) instead of pure computed proxy. This is the safe path.

2. **Should `MapParams` move to `MapGeometry.swift`?**
   - What we know: It's currently in `MapView.swift`. Moving it is clean but not required for correctness.
   - What's unclear: Whether other phases will touch `MapParams` (e.g., Phase 24 — CGImage caching may need it).
   - Recommendation: Move it to `MapGeometry.swift` now — it is a data type for the geometry utility, not a View concern.

3. **`selectedIterations` — should it also be centralized?**
   - What we know: Both `MapViewModel.selectedIterations` and `RobotDetailViewModel.selectedIterations` exist independently (same pattern as selection arrays).
   - What's unclear: Phase 22 requirements only mention `selectedSegmentIds`/`selectedSegments`. DEBT-02 is scoped to room selection state.
   - Recommendation: Include `selectedIterations` in the centralization — same pattern, same fix. Otherwise the problem re-emerges for iterations. Document as an extension of DEBT-02 in the plan.

---

## Environment Availability

Step 2.6: SKIPPED (pure Swift refactoring — no external tools, services, or CLI utilities required beyond Xcode).

---

## Sources

### Primary (HIGH confidence)
- Direct source code inspection of all four `calculateMapParams` copies — line numbers verified
- Direct source code inspection of `screenToMapCoords`/`mapToScreenCoords` — `MapView.swift:459-480`
- Direct source code inspection of `selectedSegmentIds` (`MapViewModel.swift:47`) and `selectedSegments` (`RobotDetailViewModel.swift:18`)
- `RobotManager.swift` structure and existing dictionary patterns — direct read
- `.planning/codebase/CONCERNS.md` — tech debt audit (2026-04-04)
- `.planning/codebase/ARCHITECTURE.md` — MVVM patterns and `@Observable` usage

### Secondary (MEDIUM confidence)
- Swift Observation `@Observable` computed property binding behavior — consistent with known Swift 5.9 behavior; verified against project's existing usage

---

## Metadata

**Confidence breakdown:**
- `calculateMapParams` analysis: HIGH — all four copies read and diff'd
- `screenToMapCoords`/`mapToScreenCoords` extraction: HIGH — pure functions, no hidden state
- Room selection centralization strategy: HIGH — clear pattern exists in `RobotManager`
- `@Binding` + computed property risk (Pitfall 3): MEDIUM — identified risk, safe workaround documented
- `selectedIterations` scope extension: MEDIUM — logical extension, but not explicitly in requirements

**Research date:** 2026-04-04
**Valid until:** Stable — no external dependencies, pure internal refactoring
