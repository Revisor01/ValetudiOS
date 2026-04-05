---
status: awaiting_human_verify
trigger: "App freezes (hangs, not crash) when user taps on map to open full map view. After Phase 24 (SSE streaming, CGImage pre-rendering) and Phase 30 (NWPathMonitor addition)."
created: 2026-04-04T00:00:00Z
updated: 2026-04-04T00:10:00Z
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

hypothesis: CONFIRMED AND FIXED
test: Build succeeded. Awaiting human verification that map opens without freeze.
next_action: User to test on device — open map, check for freeze, confirm or report remaining issues.

## Symptoms
<!-- IMMUTABLE after gathering -->

expected: User opens map, sees full interactive map with rooms and robot position
actual: App hangs/freezes when opening the map. UI becomes unresponsive.
errors: |
  SSE NWPathMonitor started
  SSE network path restored — reconnecting all active SSE streams
  SSE reconnect triggered for robot 262C5D69 after network change
  SSE connection error for robot 262C5D69: Abgebrochen
  SSE connection lost for robot 262C5D69 — falling back to polling
  SSE retry 1 for robot 262C5D69 — waiting 1.000000s
  SSE stream ended for robot 262C5D69
  SSE connected for robot BCB1FA8E (second robot)
  SSE connection established for both robots
  Clean route not supported: APIError.httpError(404)
  Failed to load events: APIError.httpError(404)
  Operation mode not supported: APIError.httpError(404)
  Unknown updater state: ValetudoUpdaterNoUpdateRequiredState
reproduction: Open app → select robot → tap on map preview to open full map → freeze
started: After Phase 24 (CGImage pre-rendering) and Phase 30 (NWPathMonitor)

## Eliminated
<!-- APPEND only -->

## Evidence
<!-- APPEND only -->

- timestamp: 2026-04-04T00:01:00Z
  checked: MapViewModel.swift — startMapRefresh()
  found: MapViewModel is @MainActor @Observable. startMapRefresh() creates Task { } (NOT Task.detached). Inside this Task, the loop `for try await line in bytes.lines` runs. After each decoded map event, it calls self.rebuildSegmentPixelSets() and self.rebuildStaticLayerImage(size:) synchronously. rebuildStaticLayerImage uses Task.detached for rendering, but rebuildSegmentPixelSets is a plain synchronous function (while loop over all pixels). These are all called on @MainActor because the Task inherits the actor from the enclosing @MainActor class.
  implication: Every SSE map event causes rebuildSegmentPixelSets() to run synchronously on the main thread. For large maps with thousands of pixels this can block the main thread, freezing the UI.

- timestamp: 2026-04-04T00:02:00Z
  checked: SSEConnectionManager.swift — NWPathMonitor handlePathUpdate
  found: NWPathMonitor fires immediately on start with the current path status. `lastPathStatus` is initialized to `.requiresConnection`. When the monitor starts, if the network is already `.satisfied`, it sees previousStatus=.requiresConnection (not .satisfied) and calls reconnectAll(). The guard `path.status == .satisfied, previousStatus != .satisfied` fires on first callback. This cancels the just-created SSE task and immediately restarts it — matching the log "SSE network path restored — reconnecting all active SSE streams" right after "SSE NWPathMonitor started".
  implication: At app start, SSE connects, then NWPathMonitor fires false positive, cancels and reconnects all streams. The reconnect happens quickly but the cancellation produces "Abgebrochen" errors. This is a noise issue, not the freeze.

- timestamp: 2026-04-04T00:03:00Z
  checked: MapView.swift — MapContentView.body task and onAppear
  found: The .task modifier calls `await viewModel.loadMap()` then `viewModel.startMapRefresh()` sequentially. loadMap() does multiple API calls (getCapabilities, getVirtualRestrictions, getMap, getSegments) then calls rebuildSegmentPixelSets() and rebuildStaticLayerImage(). All on @MainActor. rebuildStaticLayerImage is called from onAppear as well. The SSE task in startMapRefresh runs inside a non-detached Task, meaning it runs on @MainActor.
  implication: The SSE for-await loop holds the main actor for every event dispatch, and rebuildSegmentPixelSets() blocks synchronously on the main actor per event.

- timestamp: 2026-04-04T00:04:00Z
  checked: MapViewModel.rebuildSegmentPixelSets() — complexity
  found: This iterates through ALL layers of type "segment", calls layer.decompressedPixels (which may decompress compressed pixel data), and builds a Set<Int> for each segment. For a typical Valetudo map with 5–10 rooms and hundreds of pixels each, this is O(N) but runs synchronously on @MainActor. The decompressedPixels call is the concerning part — if the layer stores compressed data and decompresses lazily, this could be CPU-intensive.
  implication: Need to check RobotMap.swift to see if decompressedPixels involves decompression work.

- timestamp: 2026-04-04T00:05:00Z
  checked: MapViewModel.startMapRefresh() Task isolation
  found: `refreshTask = Task { [weak self] in ... }`. In Swift, a Task {} created inside a @MainActor context inherits that actor isolation. The entire body — including `for try await line in bytes.lines` — runs on @MainActor. When an SSE event arrives, Swift resumes the task body on the main actor. The synchronous work (rebuildSegmentPixelSets, updates to @Observable properties) runs on main. `rebuildStaticLayerImage` correctly uses Task.detached for the actual rendering. So the main-thread blocking is specifically in rebuildSegmentPixelSets() called per SSE event on @MainActor.

- timestamp: 2026-04-04T00:06:00Z
  checked: RobotMap.swift — MapLayerCache and decompressedPixels
  found: decompressedPixels is cached via MapLayerCache (a class/reference type). On first access per MapLayer instance it calls computeDecompressedPixels() which does RLE expansion (generates [Int] from compressedPixels). Each new SSE event decodes a brand-new RobotMap (new MapLayer instances), so the cache is ALWAYS cold on the first access. On every SSE event, the RLE decompression runs synchronously on @MainActor for all layers (floor + all segments + walls).
  implication: The decompression cost + Set<Int> building + calculateMapParams (which also iterates all pixels synchronously on main before dispatching Task.detached) = significant main-thread work on every SSE event. If a map event arrives while the view is first opening (GeometryReader onAppear triggers rebuildStaticLayerImage which calls calculateMapParams on main first), this can cause a hard freeze.

- timestamp: 2026-04-04T00:07:00Z
  checked: MapGeometry.swift — calculateMapParams()
  found: Called synchronously on main from rebuildStaticLayerImage() BEFORE dispatching Task.detached. Iterates layer.decompressedPixels for ALL layers (floor + segments + walls) to find pixel bounds. This is O(total_pixels) on the main thread. On a typical 50-room map with path data, decompressedPixels may produce 50,000–200,000 Int values. Iterating them all on main blocks the frame render loop.
  implication: calculateMapParams is the primary synchronous main-thread bottleneck. It runs: (1) in rebuildStaticLayerImage before Task.detached, (2) in InteractiveMapView Canvas body every render, (3) in tapTargetsOverlay every render. The Canvas calls are unavoidable but fast since cache is warm. The rebuildStaticLayerImage call on main before detaching is the issue.

- timestamp: 2026-04-04T00:08:00Z
  checked: NWPathMonitor false-positive as secondary contributor
  found: On app start the NWPathMonitor fires immediately with .satisfied, sees lastPathStatus=.requiresConnection, calls reconnectAll(). This cancels the state SSE (for RobotManager) and the log shows "Abgebrochen". However this only affects the RobotManager SSE, not MapViewModel's map SSE. The false-positive causes one extra reconnect cycle. It does NOT cause the map freeze directly, but contributes to startup noise and one wasted SSE connection attempt.
  implication: Secondary issue to fix for cleanliness: initialize lastPathStatus from the current path on first monitor start rather than .requiresConnection.

## Eliminated

- hypothesis: MapView freeze caused by NWPathMonitor reconnectAll() cascade blocking main thread
  evidence: SSEConnectionManager is an `actor` (not @MainActor). All reconnect work happens on the SSEConnectionManager actor's executor, off main thread. The false positive causes a reconnect but doesn't block main.
  timestamp: 2026-04-04T00:08:00Z

- hypothesis: rebuildStaticLayerImage Task.detached causes freeze
  evidence: Task.detached is correctly used for the CGImage rendering. The only main-thread work before it is calculateMapParams() + property reads. Task.detached itself does not block main.
  timestamp: 2026-04-04T00:06:00Z

## Resolution

root_cause: |
  Two compounding issues cause the freeze when opening the map:

  PRIMARY: startMapRefresh() creates a non-detached Task {} inside @MainActor MapViewModel. This Task inherits @MainActor isolation. On every SSE map event it synchronously executes on the main thread: (1) JSONDecoder.decode(RobotMap.self) for a potentially large JSON, (2) rebuildSegmentPixelSets() — iterates all segment pixels building Set<Int>, (3) updateCachedSegmentInfos() — iterates all segment layers. All with a cold decompressedPixels cache since each SSE event produces new MapLayer instances. Additionally, rebuildStaticLayerImage() calls calculateMapParams() synchronously on main (O(total_pixels) scan) before dispatching Task.detached.

  SECONDARY: NWPathMonitor in SSEConnectionManager initializes lastPathStatus to .requiresConnection. On first monitor callback (which fires immediately), the network is already .satisfied, so the guard condition `previousStatus != .satisfied` is true and reconnectAll() fires — causing a false-positive reconnect and "Abgebrochen" errors in the log.

fix: |
  PRIMARY FIX: Change startMapRefresh() to use Task.detached for the SSE processing loop. Inside the detached task, decode JSON and rebuild caches off main, then hop to MainActor only for the final state update. Also move the calculateMapParams() call inside rebuildStaticLayerImage() into the Task.detached body (it doesn't need main — it only reads copied data).

  SECONDARY FIX: In SSEConnectionManager.startPathMonitorIfNeeded(), read the current path status from monitor.currentPath immediately after start() to initialize lastPathStatus correctly, preventing the false-positive reconnect.

verification:
files_changed:
  - ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift
  - ValetudoApp/ValetudoApp/Services/SSEConnectionManager.swift
