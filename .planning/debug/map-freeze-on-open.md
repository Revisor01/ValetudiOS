---
status: resolved
trigger: "App freezes (hangs, not crash) when user taps on map to open full map view. After Phase 24 (SSE streaming, CGImage pre-rendering) and Phase 30 (NWPathMonitor addition)."
created: 2026-04-04T00:00:00Z
updated: 2026-04-12T00:00:00Z
resolved: 2026-04-12
---

## Current Focus

hypothesis: RESOLVED
test: Fixed in commit 52f7057 — verified working by user.
next_action: None. Session closed.

## Symptoms

expected: User opens map, sees full interactive map with rooms and robot position
actual: App hangs/freezes when opening the map. UI becomes unresponsive.
errors: |
  Extensive SSE/NWPathMonitor log noise during debugging — but these turned out to be red herrings unrelated to the actual freeze.
reproduction: Open app → select robot → tap on map preview to open full map → freeze
started: After cleaning-order-persistence feature was added (roomSelections/iterationSelections in RobotManager)

## Resolution

root_cause: |
  The actual cause was NOT the SSE pipeline or HTTPS layer, despite lengthy investigation pointing that way. It was an infinite feedback loop introduced by the cleaning-order persistence feature:

  `RobotManager.roomSelections` and `RobotManager.iterationSelections` were plain `var` properties on an `@Observable` class. `MapViewModel.init` read these dictionaries during initialization, and `didSet` observers wrote back to them as selections changed. Under Swift's Observation framework, every read during init registered a dependency, and every write triggered a notification — causing SwiftUI to re-render the map sheet, re-run MapViewModel.init, read again, write again, forever.

  Result: the map sheet opened but never stabilized — the view tree rebuilt itself in an infinite loop, appearing to the user as a freeze.

  The long SSE/decompression/Task-isolation investigation documented in the Evidence section below was pursuing a real but secondary inefficiency, not the actual freeze. The freeze vanished the moment the Observable loop was broken — no SSE changes were needed.

fix: |
  Mark both properties with `@ObservationIgnored` in `RobotManager.swift`:

  ```swift
  @ObservationIgnored var roomSelections: [UUID: [String]] = [:]
  @ObservationIgnored var iterationSelections: [UUID: Int] = [:]
  ```

  Room/iteration selection state is per-sheet UI state that does not need to propagate Observable notifications from the RobotManager side. Breaking the notification loop breaks the infinite re-render cycle.

  Commit: 52f7057 "fix: mark roomSelections/iterationSelections as @ObservationIgnored"

verification: User confirmed fix working on 2026-04-12. Map sheet opens normally.

files_changed:
  - ValetudoApp/ValetudoApp/Services/RobotManager.swift

## Lessons

- Extensive log noise (SSE reconnects, NWPathMonitor churn, "Abgebrochen" errors) distracted investigation toward the wrong subsystem. Red-herring logs are worth flagging early, not chasing.
- Under `@Observable`, any state read during a view's `init` / `body` creates a dependency. If that state is also written in response to view-driven actions, the loop is silent and fast — presents as a "freeze" rather than a stack overflow or obvious error.
- Rule of thumb: cross-cutting state on `@Observable` singletons that does not need to drive view updates should default to `@ObservationIgnored`.

## Evidence (preserved from investigation — points to a secondary issue, NOT the root cause)

<!-- The evidence below was gathered while chasing the SSE/decompression hypothesis.
     It correctly identified inefficiencies in the map-rebuild pipeline, but those
     were not what caused the freeze. Kept for context; do not re-open this path. -->

- timestamp: 2026-04-04T00:01:00Z
  checked: MapViewModel.swift — startMapRefresh()
  found: MapViewModel is @MainActor @Observable. startMapRefresh() creates Task { } (NOT Task.detached). The for-await SSE loop runs on @MainActor. Per-event rebuildSegmentPixelSets() runs synchronously on main.
  implication: Secondary inefficiency, not the freeze cause.

- timestamp: 2026-04-04T00:06:00Z
  checked: RobotMap.swift — MapLayerCache and decompressedPixels
  found: decompressedPixels cache is cold on every SSE event because each event produces new MapLayer instances. RLE decompression + Set<Int> building runs on main.
  implication: Wasteful but not the freeze cause.

- timestamp: 2026-04-04T00:07:00Z
  checked: MapGeometry.swift — calculateMapParams()
  found: Runs synchronously on main in multiple call sites.
  implication: Wasteful but not the freeze cause.

## Eliminated (correctly — these were never the cause)

- hypothesis: MapView freeze caused by NWPathMonitor reconnectAll() cascade blocking main thread
  evidence: SSEConnectionManager is an actor, reconnect work is off-main.
  timestamp: 2026-04-04T00:08:00Z

- hypothesis: rebuildStaticLayerImage Task.detached causes freeze
  evidence: Task.detached is correctly dispatched.
  timestamp: 2026-04-04T00:06:00Z

- hypothesis: SSE/HTTPS transport layer freezes the main thread
  evidence: User-confirmed — swapping to Observable-ignored selection state fixed the freeze without any SSE change.
  timestamp: 2026-04-12T00:00:00Z
