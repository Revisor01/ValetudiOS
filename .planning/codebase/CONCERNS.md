# Codebase Concerns

**Analysis Date:** 2026-04-04

## Tech Debt

**Triplicated `calculateMapParams` function:**
- Issue: The map parameter calculation logic is copy-pasted identically in three separate files. All three iterate all layers, compute min/max pixel bounds, and derive scale/offset. Additionally, `MapViewModel.splitRoom()` contains a fourth inline copy of the same algorithm.
- Files: `ValetudoApp/ValetudoApp/Views/MapView.swift:792`, `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift:307`, `ValetudoApp/ValetudoApp/Views/MapMiniMapView.swift:169`, `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift:320-346`
- Impact: Bug fixes or performance improvements must be applied four times. Inconsistencies between copies could cause coordinate mismatches between interactive map and control overlays.
- Fix approach: Extract into a static method on `MapParams` or a free function in a shared file (e.g., `Utilities/MapGeometry.swift`). Accept `[MapLayer]`, `pixelSize: Int`, `size: CGSize` and return `MapParams?`.

**Dual room selection state (`selectedSegmentIds` vs `selectedSegments`):**
- Issue: `MapViewModel` uses `selectedSegmentIds: [String]` while `RobotDetailViewModel` independently maintains `selectedSegments: [String]`. Both are `[String]` arrays representing room IDs with cleaning order. These are not synchronized -- selecting rooms on the map does not update the detail view's list, and vice versa.
- Files: `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift:47`, `ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift:18`
- Impact: User selects rooms in map view, then navigates back to detail view -- selection lost. Cleaning order set in one view not reflected in the other. Confusing UX when both views show different selections.
- Fix approach: Lift selection state to `RobotManager` or a shared observable. Both ViewModels should read/write the same source. Consider a `RoomSelectionManager` per robot.

**Silent error suppression with `try?` pattern:**
- Issue: Over 30 instances of `try? await` that silently discard errors. Key examples: map refresh polling (line 164), segment/map reload after join/split operations (lines 295-298, 366-369), stats loading (lines 217-225), and locate command (line 334).
- Files: `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift:164,295,298,366,369`, `ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift:217-225,334`, `ValetudoApp/ValetudoApp/Services/UpdateService.swift:63,185,189,224,228`
- Impact: Failures in map refresh, room operations, and updates go completely undetected. User sees stale data with no indication something went wrong. Particularly dangerous for `splitRoom`/`joinRooms` where the operation succeeds but the reload silently fails.
- Fix approach: Replace `try?` with proper do/catch blocks that at minimum log warnings. For user-initiated actions (join, split, rename), surface errors via `errorMessage` state property and show alert.

**DebugConfig fallback masks real failures:**
- Issue: Capability flags initialized to `DebugConfig.showAllCapabilities` (e.g., `hasManualControl`, `hasAutoEmptyTrigger`). When debug mode is on, API failures are masked because the feature still appears enabled with mock data. Error handlers only disable features when NOT in debug mode.
- Files: `ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift:28-34`, `ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift:170-176`, `ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift:186-209`
- Impact: Developers testing on real devices with debug flag on will not notice API failures. Bugs may ship to production because the debug path suppresses them.
- Fix approach: Always log errors regardless of debug flag. Use DebugConfig only to inject mock UI data, never to bypass error handling logic.

**`isInitialLoad` flag pattern in RobotSettingsViewModel:**
- Issue: Uses a fragile boolean `isInitialLoad` flag to suppress `onChange`-triggered API calls during initial data load. Pattern repeated across 10+ settings properties. If a developer adds a new setting and forgets the guard, an unintended API call fires on app launch.
- Files: `ValetudoApp/ValetudoApp/ViewModels/RobotSettingsViewModel.swift` (throughout)
- Impact: Risk of accidental API writes during initialization. Manual flag management is error-prone.
- Fix approach: Use a two-phase pattern: load data into private backing storage, then copy to published properties. Or restructure to only bind onChange handlers after initial load completes.

**Capabilities never re-checked after firmware update:**
- Issue: Robot capabilities loaded once per view lifecycle. No cache invalidation mechanism if robot firmware updates and gains new capabilities (e.g., after OTA update within the app itself).
- Files: `ValetudoApp/ValetudoApp/ViewModels/RobotSettingsViewModel.swift`, `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift:107-112`, `ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift:166-179`
- Impact: After firmware update, user must kill and restart the app to see new capabilities.
- Fix approach: Cache capabilities in `RobotManager` with a TTL (e.g., 1 hour). Force-refresh after OTA update completes. Expose a manual refresh mechanism.

**Product ID hardcoding in SupportManager:**
- Issue: StoreKit product IDs are hardcoded string literals with no runtime validation that products exist.
- Files: `ValetudoApp/ValetudoApp/Services/SupportManager.swift`
- Impact: If product ID is mismatched in App Store Connect, purchase fails silently. No way to toggle support tiers without recompile.
- Fix approach: Move product IDs to a configuration file. Add product verification on app launch with explicit error logging.

## Performance Bottlenecks

**Map pixel-by-pixel hit-testing via linear scan:**
- Issue: `handleCanvasTap()` in `InteractiveMapView` performs a linear scan through ALL decompressed pixels of EVERY segment layer to find which room was tapped. For a typical map with 8 rooms and thousands of pixels per room, this is O(n) per tap where n = total pixel count across all segments.
- Files: `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift:228-254`
- Impact: Tap responsiveness degrades on maps with many rooms or large floor areas. On older devices (iPhone SE, iPad mini), perceptible delay possible.
- Fix approach: Build a spatial lookup structure (e.g., dictionary keyed by `(x,y)` -> segmentId) when map data arrives. Or use bounding box pre-filter per segment before pixel-level check.

**Map polling every 2-3 seconds with full JSON decode:**
- Issue: `MapViewModel.startMapRefresh()` polls `api.getMap()` every 2 seconds. `MapPreviewView.startLiveRefresh()` polls every 3 seconds. Each call returns the full map JSON (can be 100KB+), which is fully decoded into `RobotMap` + all `MapLayer` objects. No SSE-based map streaming is used (only state attributes use SSE).
- Files: `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift:154-181`, `ValetudoApp/ValetudoApp/Views/MapView.swift:164-176`
- Impact: Continuous network traffic and CPU usage for JSON parsing. On cellular connections, consumes significant bandwidth. Both the preview and full map poll independently -- if both are visible, double the traffic.
- Fix approach: Use the map SSE endpoint (`/api/v2/robot/state/map/sse`) already defined in `ValetudoAPI.streamMapLines()` but currently unused. Implement differential map updates. Share a single map data source between preview and full map views.

**`segmentInfos()` recomputed on every overlay render:**
- Issue: `segmentInfos(from:)` iterates all segment layers and computes midpoints every time the `tapTargetsOverlay` or `orderBadgesOverlay` is rendered. Both overlays call it independently, so it runs twice per frame.
- Files: `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift:264-304`, referenced at lines 151 and 199
- Impact: Redundant computation during map panning/zooming. Midpoint calculation involves iterating all decompressed pixels if `dimensions.mid` is nil.
- Fix approach: Cache segment info in a computed property that only recalculates when `map.layers` identity changes. Compute once and share between both overlays.

**Canvas redraws entire map every frame:**
- Issue: `InteractiveMapView` uses a SwiftUI `Canvas` that redraws ALL pixels (floor, segments, walls, entities, restrictions, zones) on every render pass. No partial redraw or layer caching.
- Files: `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift:34-121`
- Impact: During zoom/pan gestures, all drawing functions execute per frame. `drawPixelsWithMaterial()` has extra branching per pixel for material texture patterns.
- Fix approach: Pre-render the static map layers (floor, walls, segments) into a `CGImage` when map data changes. Use the image in Canvas for display. Only overlay dynamic elements (robot position, drawing preview, selection highlights) on each frame.

**MapCacheService writes to disk on every 2-second poll:**
- Issue: Every successful map poll triggers `MapCacheService.shared.save()`, which JSON-encodes the full map and writes atomically to disk.
- Files: `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift:140,167`, `ValetudoApp/ValetudoApp/Services/MapCacheService.swift:29-37`
- Impact: Continuous disk I/O every 2 seconds. On devices with flash wear concerns or during battery-sensitive scenarios, unnecessary writes.
- Fix approach: Only write cache when map data actually changes (compare hash/checksum). Or throttle writes to once per minute while actively polling.

## Fragile Areas

**RobotDetailView monolith (1208 lines):**
- Issue: Single file contains the entire robot detail screen: status header, map preview, controls, intensity settings, dock actions, consumables, statistics, events, obstacles, rooms, clean route, settings navigation, update flow, and all helper functions.
- Files: `ValetudoApp/ValetudoApp/Views/RobotDetailView.swift` (1208 lines)
- Impact: Any change to one section risks breaking another. Merge conflicts when multiple features developed in parallel. Difficult to find specific logic. SwiftUI body is deeply nested.
- Fix approach: Already partially decomposed with `RobotDetailSections.swift`. Continue extracting: move control section, consumables section, rooms section, statistics section, events section into separate files or extracted views. Each section should be a standalone `View` struct.

**MapContentView split across 3 files with shared mutable state:**
- Issue: `MapContentView` is defined in `MapView.swift` but extended in `MapControlBarsView.swift` (594 lines). The view's `@State` properties (`currentDrawStart`, `currentDrawEnd`, `currentViewSize`, `scale`, `offset`) are accessed from both files. Coordinate transformation functions (`screenToMapCoords`, `mapToScreenCoords`) live in `MapView.swift` but are called from control bar actions.
- Files: `ValetudoApp/ValetudoApp/Views/MapView.swift`, `ValetudoApp/ValetudoApp/Views/MapControlBarsView.swift`, `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift`
- Impact: Understanding the full map interaction requires reading 3 files simultaneously. State mutations from control bars affect rendering in MapView without clear data flow.
- Fix approach: Move all mutable state into `MapViewModel`. Control bars should call ViewModel methods, not mutate view state directly. Coordinate transforms should live in a pure utility.

**Coordinate transform correctness depends on render pipeline order:**
- Issue: `screenToMapCoords` / `mapToScreenCoords` in `MapContentView` account for `scale` and `offset` state. But `InteractiveMapView` has its own `calculateMapParams` that computes different scale/offset values. The GoTo marker and preset markers convert between these two coordinate systems with manual math that must stay in sync with the Canvas drawing code.
- Files: `ValetudoApp/ValetudoApp/Views/MapView.swift:459-480` (transforms), `ValetudoApp/ValetudoApp/Views/MapView.swift:260-297` (marker positioning), `ValetudoApp/ValetudoApp/Views/MapView.swift:300-328` (preset positioning)
- Impact: If drawing code changes pixel placement logic, markers and tap targets drift out of alignment. Bug would be subtle -- off by a few pixels, visible only on certain map sizes.
- Fix approach: Unify coordinate systems. Define canonical "map coordinate" and "screen coordinate" types. All conversions go through a single, tested utility.

**RobotSettingsSections.swift complexity (1078 lines):**
- Issue: Contains 15+ independent settings sub-views (AutoEmptyDock, Quirks, WiFi, NTP, MQTT, CarpetMode, VoicePack, MapSnapshots, etc.) all in one file. Each has its own state, loading logic, and API calls.
- Files: `ValetudoApp/ValetudoApp/Views/RobotSettingsSections.swift` (1078 lines)
- Impact: Long compile times for this file. Hard to navigate. Each sub-view is effectively independent but changes to shared patterns require scanning the entire file.
- Fix approach: Extract each settings sub-view into its own file under a `Views/Settings/` directory.

## Security Considerations

**Basic Auth credentials in every HTTP request:**
- Issue: `ValetudoAPI` constructs Basic Auth header on every request by reading password from Keychain. The base64-encoded credentials are sent in plain text over HTTP if `useSSL` is false (the default for local network robots).
- Files: `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift:90-95`, `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift:131-138`
- Current mitigation: Keychain storage with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. SSL option available.
- Recommendations: Warn users when connecting without SSL. Consider showing a security indicator in the robot detail view when HTTP (not HTTPS) is used.

**SSL certificate validation bypass:**
- Issue: `SSLSessionDelegate` accepts ALL server certificates when `ignoreCertificateErrors` is enabled. No certificate pinning, no fingerprint validation.
- Files: `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift:65-75`
- Current mitigation: User must explicitly enable `ignoreCertificateErrors` in robot config.
- Recommendations: Add certificate fingerprint pinning option. Show clear warning when certificate errors are ignored.

**Robot configuration stored in UserDefaults:**
- Issue: `RobotManager.saveRobots()` serializes robot configs (including hostnames, usernames, SSL settings) to `UserDefaults`. While passwords were migrated to Keychain, the rest of the config (host, port, username) remains in unencrypted UserDefaults.
- Files: `ValetudoApp/ValetudoApp/Services/RobotManager.swift:286-289`
- Impact: On jailbroken devices or via iTunes backup, robot network addresses and usernames are readable.
- Recommendations: Low risk for typical home use. Consider migrating to Keychain for sensitive fields if targeting enterprise users.

## Accessibility Gaps

**Zero accessibility labels/hints in entire codebase:**
- Issue: A search for `accessibilityLabel`, `accessibilityHint`, `accessibilityValue`, and `.accessibility` returns zero matches across all Swift files. No VoiceOver support whatsoever.
- Files: All view files in `ValetudoApp/ValetudoApp/Views/`
- Impact: App is completely unusable for visually impaired users. VoiceOver will read generic button labels or nothing for icon-only buttons. Map interaction is entirely inaccessible.
- Fix approach (high priority areas):
  1. Control buttons (`ControlButton`, `DockActionButton`): Add `.accessibilityLabel` with action description
  2. Status header battery/status indicators: Add `.accessibilityValue` for current state
  3. Map room labels and order badges: Add `.accessibilityLabel` with room name and order number
  4. Consumable progress bars: Add `.accessibilityValue` with percentage
  5. All icon-only buttons throughout the app: Add descriptive labels

**Map Canvas not accessible:**
- Issue: The `Canvas`-based map rendering produces a flat image with no accessibility tree. Room selection by tapping areas, drawing zones, and GoTo placement are all gesture-based with no accessible alternatives.
- Files: `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift` (entire file)
- Impact: Map functionality is completely inaccessible via VoiceOver or Switch Control.
- Fix approach: Provide alternative room selection via the list-based room picker (already exists in `RobotDetailView.roomsSection`). Mark the Canvas with `.accessibilityElement(children: .ignore)` and add a summary label. Consider adding an "Accessible mode" that uses only list-based interactions.

## Test Coverage Gaps

**No tests for map interaction logic:**
- What's not tested: Room tap hit-testing (`handleCanvasTap`), coordinate transformations (`screenToMapCoords`/`mapToScreenCoords`), zone drawing, GoTo coordinate calculations, split line positioning.
- Files: `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift`, `ValetudoApp/ValetudoApp/Views/MapView.swift:459-480,685-790`
- Risk: Coordinate math bugs could cause cleaning wrong rooms, going to wrong locations, or drawing restrictions in wrong positions. These are the highest-impact bugs possible.
- Priority: **High** -- Extract coordinate transform and hit-test logic into testable pure functions, then add unit tests.

**No tests for SSE connection management:**
- What's not tested: SSE reconnection logic, backoff timing, connection state tracking, attribute parsing from SSE stream.
- Files: `ValetudoApp/ValetudoApp/Services/SSEConnectionManager.swift`
- Risk: SSE bugs cause stale robot state, missed notifications, or infinite reconnection loops.
- Priority: **Medium** -- SSE reconnection has been stable, but edge cases (network transitions, background/foreground) untested.

**No tests for MapCacheService:**
- What's not tested: Cache save/load cycle, cache invalidation on robot removal, behavior with corrupted cache data.
- Files: `ValetudoApp/ValetudoApp/Services/MapCacheService.swift`
- Risk: Corrupted cache could crash the app on startup or show stale/wrong map data.
- Priority: **Medium**

**No tests for UpdateService state machine:**
- What's not tested: Update phase transitions (checking -> downloading -> readyToApply -> applying -> rebooting), error recovery, download progress tracking, reboot detection via polling.
- Files: `ValetudoApp/ValetudoApp/Services/UpdateService.swift`
- Risk: Firmware update is the most dangerous operation. A bug could leave the robot in an inconsistent state or the app stuck on the update overlay with no way to dismiss.
- Priority: **High**

**No UI/integration tests:**
- What's not tested: Full user flows (add robot, view detail, select rooms, start cleaning). Navigation between views. Sheet presentation/dismissal.
- Files: No UI test target exists.
- Risk: Regressions in navigation flow, sheet presentation, or view state management undetected.
- Priority: **Low** -- Unit tests for ViewModels cover most logic. UI tests would add significant maintenance burden for a small team.

**Existing test coverage (687 lines across 8 files):**
- `RobotDetailViewModelTests.swift` (153 lines): Tests basic actions, segment selection, consumable loading
- `MapViewModelTests.swift` (94 lines): Tests map loading, cleaning actions
- `ValetudoAPITests.swift` (88 lines): Tests URL construction, request building
- `ConsumableTests.swift` (80 lines): Tests consumable model parsing
- `KeychainStoreTests.swift` (75 lines): Tests save/load/delete cycle
- `TimerTests.swift` (74 lines): Tests timer model parsing
- `RobotSettingsViewModelTests.swift` (71 lines): Tests settings loading
- `MapLayerTests.swift` (52 lines): Tests pixel decompression

## Scaling Limits

**Single-robot map polling assumption:**
- Issue: Each robot gets its own independent map polling loop (2-second interval) plus an independent preview polling loop (3-second interval). With multiple robots, this multiplies network requests linearly.
- Current capacity: Works well for 1-3 robots.
- Limit: 5+ robots would generate 5+ map requests/second continuously, plus SSE connections.
- Scaling path: Use SSE for map updates (endpoint exists but unused). Share a single map data source between preview and full map. Only poll active/visible robot.

**MapLayerCache uses reference type without thread safety:**
- Issue: `MapLayerCache` is a `class` (reference type) used from SwiftUI `Canvas` closures. `cachedPixels` has no synchronization mechanism. If the map is accessed from multiple Canvas renders simultaneously (e.g., minimap and full map), a data race is theoretically possible.
- Files: `ValetudoApp/ValetudoApp/Models/RobotMap.swift:18-29`
- Current capacity: Works because SwiftUI typically renders on main thread.
- Limit: If rendering moves to background (e.g., Metal-based map renderer), data race would occur.
- Scaling path: Make `MapLayerCache` `@unchecked Sendable` with a lock, or move to a value-type caching approach.

## Known Limitations

**No map SSE streaming despite API support:**
- Issue: `ValetudoAPI` defines `streamMapLines()` (line 648) for SSE-based map updates, but this endpoint is never used. Map data relies entirely on HTTP polling.
- Files: `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift:648-676`
- Impact: Unnecessary network overhead. Map updates have 2-3 second latency instead of near-realtime.
- Fix: Implement map SSE consumer similar to `SSEConnectionManager.streamWithReconnect()` for attributes.

**ErrorRouter defined but minimally used:**
- Issue: `ErrorRouter` class exists with retry support, but most error handling throughout the app uses logger-only or silent `try?`. The router is not wired into any view's alert system in a systematic way.
- Files: `ValetudoApp/ValetudoApp/Helpers/ErrorRouter.swift`
- Impact: User-facing error reporting is inconsistent. Some errors show alerts, most are silently logged.
- Fix: Wire `ErrorRouter` into `RobotDetailView` and `MapContentView` for user-initiated action failures.

**No confirmation before destructive robot actions:**
- Issue: Stop, Home, auto-empty dock, mop dock clean/dry actions execute immediately on tap with no confirmation dialog. Only firmware update has a confirmation alert.
- Files: `ValetudoApp/ValetudoApp/Views/RobotDetailView.swift:518-527` (stop/home buttons)
- Impact: Accidental taps can interrupt cleaning in progress or trigger dock operations unnecessarily.
- Recommendations: Add confirmation for Stop during active cleaning. Other actions are low-risk.

**Consumable reset has no confirmation:**
- Issue: Tapping the reset arrow on a consumable immediately calls the API with no "Are you sure?" prompt.
- Files: `ValetudoApp/ValetudoApp/Views/RobotDetailView.swift:816-824`
- Impact: Accidental reset makes the app show 100% for a consumable that hasn't actually been replaced, misleading the user about replacement timing.
- Fix: Add `.confirmationDialog` before `viewModel.resetConsumable()`.

---

*Concerns audit: 2026-04-04*
