# Codebase Concerns

**Analysis Date:** 2026-03-28

## Tech Debt

**Logger usage inconsistency across Views:**
- Issue: Mix of structured Logger (os.Logger) in services and print() statements in views. DoNotDisturbView, StatisticsView, IntensityControlView, MapView, ManualControlView all use print() for error reporting instead of unified logger.
- Files: `ValetudoApp/ValetudoApp/Views/DoNotDisturbView.swift:124`, `ValetudoApp/ValetudoApp/Views/StatisticsView.swift:72,80`, `ValetudoApp/ValetudoApp/Views/IntensityControlView.swift:145,158,171,186,200,214`, `ValetudoApp/ValetudoApp/Views/MapView.swift:156`, `ValetudoApp/ValetudoApp/Views/ManualControlView.swift:152,164,176,200`
- Impact: Errors in views not captured in unified logging stream. Production debugging harder. Lost structured logging context (privacy levels, categories).
- Fix approach: Replace all print() in Views with Logger instance matching service pattern (example: RobotDetailViewModel line 11). Ensure all API errors logged with `privacy: .public` for safe console output. Create shared logger creation helper to avoid duplication.

**DispatchQueue.main.asyncAfter instead of Task-based concurrency:**
- Issue: SupportReminderOverlay uses `DispatchQueue.main.asyncAfter(deadline: .now() + 2)` instead of Task-based async/await pattern. Inconsistent with rest of codebase which uses async let and Task.sleep.
- Files: `ValetudoApp/ValetudoApp/Views/SupportReminderView.swift:93`
- Impact: Mixed concurrency models increase maintenance burden. DispatchQueue approach doesn't automatically cancel on view dealloc (unlike Task).
- Fix approach: Replace with `Task { try? await Task.sleep(for: .seconds(2)); /* animation */ }`. Ensure Task cancelled in onDisappear like MapViewModel line 139.

**Product ID hardcoding in SupportManager:**
- Issue: StoreKit product IDs hardcoded as string literals (SupportManager.swift lines 20-24). Changes require code modification + manual App Store Connect setup synchronization. No validation that products exist at runtime.
- Files: `ValetudoApp/ValetudoApp/Services/SupportManager.swift:20-24`
- Impact: If product ID mismatched in App Store Connect, purchase fails silently (line 54 shows unverified handler but no user alert). No way to toggle support feature without recompile.
- Fix approach: Move product IDs to Configuration.plist or environment variable. Add product verification on app launch with explicit error message if load fails (currently caught and hidden with DEBUG print at line 37).

**Manual isInitialLoad flag for onChange suppression:**
- Issue: RobotSettingsViewModel uses fragile `isInitialLoad` flag (line 72) to suppress onChange-triggered API calls during initial loadSettings(). Pattern duplicated across 10+ onChange handlers (lines 77, 91, 104, 118, 132, 150, 339, etc.). If developer adds new property and forgets isInitialLoad check, accidental API call triggered on app launch.
- Files: `ValetudoApp/ValetudoApp/ViewModels/RobotSettingsViewModel.swift:72, 87-300+`
- Impact: Risk of duplicate unwanted API calls during initialization. Manual flag management error-prone.
- Fix approach: Extract into generic initialization pattern using Swift Task cancellation. Use single @Published initializing state that gates all onChange handlers. Or refactor to separate view for loaded state (SkeletonView → RealSettingsView).

**Keychain error handling ignored:**
- Issue: KeychainStore operations ignore status codes. SecItemDelete (line 28) returns errSecItemNotFound for missing items, treated as success. SecItemAdd (line 37) failure silently continues.
- Files: `ValetudoApp/ValetudoApp/Services/KeychainStore.swift:28,37,46`
- Impact: Password persistence failure undetected. Robot credentials could be lost between sessions with no user feedback. User tries to connect → auth fails → confused.
- Fix approach: Return Result<Void, KeychainError> from save/delete methods. Log errors to unified logger. Notify user if password storage fails (show alert).

**Capabilities cache never invalidated:**
- Issue: RobotSettingsViewModel loads capabilities once in loadSettings() (line 115). No cache invalidation if robot updates firmware and gains new capabilities. Capability detection mixed: some from API (capabilities array), some from DEBUG flag (DebugConfig.showAllCapabilities).
- Files: `ValetudoApp/ValetudoApp/ViewModels/RobotSettingsViewModel.swift:115-137`
- Impact: User won't see new features after robot firmware update without force-quit and relaunch. Capability flags initialized to DebugConfig value (lines 25-47) so features hidden until explicit loadSettings() call.
- Fix approach: Store capability last-check timestamp. Invalidate if >1 week old or on explicit refresh. Implement capability cache in RobotManager as single source of truth.

**Silent error suppression with DebugConfig fallback:**
- Issue: Pattern throughout codebase: catch errors but only act if !DebugConfig.showAllCapabilities. Example: RobotSettingsViewModel line 96 — if volume load fails, hasCarpetMode disabled ONLY if not in debug mode. In debug mode, silently continues with mock data.
- Files: RobotSettingsViewModel (lines 96, 103, 110, 144, 154, 162, 175, 186, 195), RobotDetailViewModel (lines 159-165)
- Impact: Errors hidden in debug mode. Developer might not notice API failures. Debug path taken by development devices means bugs slip to production.
- Fix approach: Log all errors regardless of debug flag. Use DebugConfig only to SHOW mock UI in development, not to suppress error handling. Separate concerns: error handling vs. capability mocking.

## Fragile Areas

**MapView (2532 lines) — Massive monolithic canvas view:**
- Files: `ValetudoApp/ValetudoApp/Views/MapView.swift`
- Why fragile: Complex Canvas rendering with all logic spread across 2500+ lines. Drawing operations (floor, walls, segments, entities, restrictions) tightly coupled. Zone/wall coordinate transformations duplicated across drawVirtualWall(), drawRestrictedZone(), drawNoMopZone() (lines 242-300). Small changes to coordinate system affect many methods. Scale/offset calculations repeated (MapParams used inconsistently).
- Safe modification: Extract drawing helpers into separate structs (FloorDrawer, WallDrawer, ZoneDrawer, EntityDrawer). Use shared MapParams calculation to prevent coordinate drift. Add coordinate transformation unit tests. Implement incremental rendering (cache static layers as CGImage, only redraw dynamic entities).
- Test coverage: Minimal — no unit tests for coordinate transformations, pixel-to-screen calculations, or zoom behavior.

**RobotSettingsView (1801 lines) — UI mixing state, API, presentation:**
- Files: `ValetudoApp/ValetudoApp/Views/RobotSettingsView.swift`
- Why fragile: Settings controller mixing state management, API interactions, and presentation across 1800+ lines. Multiple nested conditional sections (VolumeControl, CleaningSettings, MapSettings, MapSnapshots, VoicePack, Quirks, System) making feature additions error-prone. Settings changes via onChange handlers (lines 36-152) trigger API calls without debouncing. Volume slider fires API request on every slider position change (10 requests if user drags from 0→100).
- Safe modification: Split into smaller focused views (VolumeSettingsView, CleaningSettingsView, MapSettingsView). Extract API mutation logic into dedicated viewmodel methods. Add debouncing to onChange handlers: `.debounce(for: .milliseconds(500))` before calling setVolume(), setCarpetMode(), etc. Implement request cancellation for rapid state changes.
- Test coverage: No unit tests for settings mutations, API error handling, or rapid state change sequences.

**RobotDetailView (1253 lines) — Large coordinator view:**
- Files: `ValetudoApp/ValetudoApp/Views/RobotDetailView.swift`
- Why fragile: Large view coordinating multiple features (segments, consumables, statistics, events, cleaning route, obstacles, update status). Conditional capability rendering based on ViewModel flags could hide missing error states. Live stats polling logic embedded in view instead of service (calls refreshData() on timer). Complex state transitions (idle → cleaning → paused → returning → docked) not formally modeled.
- Safe modification: Extract stats polling to RobotManager. Use separate ViewModels for distinct sections (StatisticsViewModel, ObstacleViewModel, EventsViewModel). Add explicit error states for missing data vs. loading vs. unsupported capability. Implement state machine for robot status transitions.
- Test coverage: None for capability-gated sections or error paths. No tests for status transitions.

**RobotManager SSE/Polling coordination (lines 79-120) — Complex state machine:**
- Files: `ValetudoApp/ValetudoApp/Services/RobotManager.swift`
- Why fragile: Complex logic mixing SSE connection attempts with 5s polling fallback. SSE manager maintains separate connection state; mismatch between SSE connection success and polling logic could cause duplicate updates or missed state changes. Attribute updates applied before previousState tracking (line 177) could lose connection-loss detection. No explicit state machine — SSE can drop but polling continues, creating uncertainty about which is active.
- Safe modification: Consolidate SSE/polling state machine into single coordinator. Make previousState update atomic with status update. Add invariant tests verifying SSE-active prevents polling (and vice versa). Implement retry backoff not just for SSE but also for polling fallback.
- Test coverage: No tests for SSE/polling race conditions, state consistency, or robot add/remove during streaming.

**RobotSettingsViewModel onChange handlers — No debouncing:**
- Files: `ValetudoApp/ValetudoApp/ViewModels/RobotSettingsViewModel.swift` (setVolume, setCarpetMode, setObstacleAvoidance, etc.)
- Why fragile: Each onChange handler directly calls API without debouncing or request coalescing. Volume slider (RobotSettingsView line 36) generates 10 sequential setVolume() requests if user drags slider from 0-100. No cancellation of in-flight requests if user changes mind.
- Safe modification: Add debouncing with task cancellation. Store previous request task and cancel before issuing new one. Use .debounce(for: .milliseconds(500)) on onChange handlers.
- Test coverage: No tests for rapid state changes or concurrent API requests.

## Performance Bottlenecks

**Map rendering on full view redraws entire canvas each update:**
- Problem: MapView Canvas redraws entire map (floor, walls, segments, restrictions, entities) on every @State update. No layer caching or incremental rendering. Coordinate calculations in multiple drawing functions (drawPixels, drawThinWalls, drawPath, drawRobot) repeated on each frame.
- Files: `ValetudoApp/ValetudoApp/Views/MapView.swift` (drawing methods starting line 183)
- Cause: Canvas renders from scratch on @State updates. RobotMap updates at 3s intervals (MapPreviewView line 165) trigger full recompute. MiniMapView redraws on every map poll.
- Improvement path: Cache static layers (floor, walls, segments) as CGImage. Only redraw dynamic entities (robot position, path). Implement layer reuse in Canvas context. Pre-calculate coordinate params. Target: 60fps on iPhone 14 (currently likely ~15fps on large maps).

**SSE-to-polling transition penalty — no fallback backoff:**
- Problem: When SSE drops, system falls back to 5s polling. For 2-3 robots without active SSE, RobotManager.startRefreshing() (line 79) invokes refreshRobot() in parallel taskgroup every 5s, generating 6 API calls/min/robot without SSE. Backoff only in SSE stream (exponential 1s → 5s → 30s), not in polling fallback.
- Files: `ValetudoApp/ValetudoApp/Services/RobotManager.swift:105-120`
- Cause: Polling interval fixed at 5s regardless of connection state. No adaptive backoff after failed refreshes. No network reachability check before polling.
- Improvement path: Implement polling backoff (5s → 15s → 60s) after failed refreshes. Check network reachability before polling. Reset backoff on successful refresh. Target: Reduce unnecessary API calls on poor network by 80%.

**Consumables check every refresh without rate limiting:**
- Problem: checkConsumables() (RobotManager.swift line 154) called every refresh cycle as background task. Compares consumable levels across all items, logs notifications. On 2-3 robots refreshing every 5s, generates O(N) comparisons per robot per 5s.
- Files: `ValetudoApp/ValetudoApp/Services/RobotManager.swift:154`
- Cause: No rate limiting; called on every refresh in background task. Notification triggered on every <20% check even if level unchanged.
- Improvement path: Implement debounce timer (check consumables max once per hour unless level changes >5%). Cache previous consumable state for delta detection. Suppress duplicate notifications.

**RobotMap JSON decoding on every preview refresh:**
- Problem: Full RobotMap (with layer pixel data, entities, restrictions) decoded from JSON on every 3s preview refresh (MapPreviewView line 167). Decompression of pixel arrays happens in RobotMap.decompressedPixels (computed property). No caching. Canvas redraws entire map on each update.
- Files: `ValetudoApp/ValetudoApp/Views/MapView.swift:150,167`, `ValetudoApp/ValetudoApp/Models/RobotState.swift`
- Cause: RobotMap fully decoded; decompression runs on every Canvas render. No state snapshot between requests.
- Improvement path: Cache decompressed pixels in RobotMap. Use @State snapshot for preview to avoid re-decoding. Implement lazy decompression only for visible layers. Batch map updates to max once per second.

## Security Considerations

**SSL certificate validation disabled for self-signed certs — Man-in-the-middle risk:**
- Risk: SSLSessionDelegate (ValetudoAPI.swift lines 65-75) bypasses certificate validation for *all* SSL connections if ignoreCertificateErrors flag set. Accepts any certificate presented. No hostname verification after trust accepted. Man-in-the-middle attack surface on local network.
- Files: `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift:52-54,65-75`
- Current mitigation: Only enabled if config.ignoreCertificateErrors explicitly set. Stored in RobotConfig (local only, not synced to iCloud).
- Recommendations: Add certificate pinning option for production robots. Implement hostname verification even if certificate self-signed. Warn user in UI when SSL validation disabled (show badge on robot). Consider AppKit Security Framework for better cert handling. Log certificate acceptance with details.

**Basic Auth credentials in memory — Plaintext on network:**
- Risk: Credentials decoded from Keychain on every API request (ValetudoAPI.swift lines 91, 137). Base64-encoded (not encrypted) and sent in Authorization header. Vulnerable to network sniffing if HTTPS bypass occurs. No request timeout for hanging connections (would block indefinitely).
- Files: `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift:80-157`
- Current mitigation: Credentials stored in Keychain (encrypted at rest). Used only for requests to configured robot host. URLSession uses default timeout (10s for requests, 30s for resource).
- Recommendations: Enforce HTTPS-only for remote connections. Consider OAuth2 if Valetudo supports it. Implement certificate-based auth (client certs). Log authentication failures to detect credential issues (currently silent). Add credential rotation mechanism.

**Unencrypted stored robot passwords in Keychain — Lock-dependent:**
- Risk: While Keychain encrypts data, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` means passwords become unavailable when device locked. If user needs to unlock robot while phone asleep, authentication fails. Trade-off between security and usability.
- Files: `ValetudoApp/ValetudoApp/Services/KeychainStore.swift:35`
- Current mitigation: Setting requires device unlock. Protects against physical device theft.
- Recommendations: Document the lock behavior in UI. Consider `kSecAttrAccessibleAfterFirstUnlock` if background connectivity needed (more security risk). Implement password complexity validation on save. Add warning if robot connectivity fails due to device lock state.

**No rate limiting on API requests — Spam/DoS risk:**
- Risk: If robot credentials leaked or endpoint exposed, attacker can spam API with requests. No circuit breaker or request throttling. SSEConnectionManager implements backoff (exponential 1s → 5s → 30s) but only for streaming reconnects. Polling has no backoff.
- Files: `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift` (request methods), `ValetudoApp/ValetudoApp/Services/RobotManager.swift` (polling)
- Current mitigation: URLSession timeout prevents infinite hangs. SSE connection has backoff.
- Recommendations: Implement per-robot request rate limiting (max N requests/min). Add circuit breaker (disable API calls after 10 consecutive failures). Log suspicious request patterns. Implement exponential backoff in polling like SSE does.

## Scaling Limits

**In-memory state for unlimited robots:**
- Current capacity: Tested with 3-4 robots. RobotManager stores all state in @Published dicts (`robotStates: [UUID: RobotStatus]`, `apis: [UUID: ValetudoAPI]`, `previousStates: [UUID: RobotStatus]`). Each robot maintains SSE stream + 5s polling task. No pagination or windowing for robot list.
- Limit: ~50+ robots would exceed iOS memory constraints (SSE streams not garbage collected, state accumulation, 50 * 10MB map buffers = 500MB).
- Scaling path: Implement lazy-loading for robot state (load active robot state, background-load others with lower priority). Add max concurrent SSE connections (e.g., 5, others use polling only). Implement robot list pagination in UI. Add memory warning handler to drop cached maps.

**Map pixel buffer scaling — Memory exhaustion on large maps:**
- Current capacity: Typical map 1000x1000 pixels (~10MB uncompressed). Works fine on iPhone 12+. Larger maps (2000x2000) risk memory pressure during Canvas rendering.
- Limit: >2000x2000 maps + 10 concurrent robots = potential memory exhaustion (500MB+ needed).
- Scaling path: Implement map tiling (render only visible regions). Lazy-decompress pixel layers only when needed. Add memory warning handler to drop cached maps. Implement mipmap downsampling for preview view.

**SSE connection limits — URLSession exhaustion:**
- Current capacity: System limits concurrent URLSession data tasks (~1000 across all domains typical). SSE connections are long-lived tasks taking 1 connection slot each.
- Limit: >50 robots with active SSE = potential connection exhaustion. Competing with other network traffic.
- Scaling path: Implement connection pooling. Switch to WebSocket if Valetudo supports it (WebSocket allows multiplexing). Implement fallback to polling-only for non-primary robots. Share URLSession across robots.

## Missing Critical Features

**No offline queue for critical actions:**
- Problem: User initiates cleaning/docking action but network drops. Action is lost (network error). No queue to retry when connectivity restored.
- Blocks: Reliable robot control on poor networks.
- Recommendation: Implement local action queue in RobotManager. Persist queued actions to disk. Retry on network restoration. Show user "X actions pending" badge.

**No user-facing error messages for API failures:**
- Problem: API calls fail silently (print() statements in console only). User sees no feedback when zone cleaning, consumable reset, or settings change fails.
- Blocks: Debugging user issues. User trust degradation (app feels broken).
- Recommendation: Add error alert coordinator. Display user-friendly error messages for each failure type. Provide retry option. Log details for debugging.

**No background sync for consumables/statistics:**
- Problem: Consumable levels only update when app in foreground. User won't know consumable is low until they open app.
- Blocks: Proactive consumable replacement workflow.
- Recommendation: Implement background task (BGProcessingTaskRequest) to sync consumable data every 6 hours. Show notification if low.

## Test Coverage Gaps

**MapView coordinate transformation:**
- What's not tested: Pixel-to-screen coordinate math, scale/offset calculations, zoom behavior, rotation handling
- Files: `ValetudoApp/ValetudoApp/Views/MapView.swift` (calculateMapParams, drawing methods)
- Risk: Coordinate bugs cause elements to render off-screen or misaligned. Hard to detect visually across devices.
- Priority: High

**RobotManager SSE/polling state machine:**
- What's not tested: SSE drops and reconnects without duplicate updates. Polling activates when SSE fails. State consistency across robot add/remove during streaming.
- Files: `ValetudoApp/ValetudoApp/Services/RobotManager.swift:79-120,166-179`
- Risk: Race conditions cause missed or duplicate status updates. Connection leaks.
- Priority: High

**API error handling in Views:**
- What's not tested: Views behavior when API calls fail (network error, 401, 500). Current print() statements don't provide user feedback. No error retry logic.
- Files: All view files with mutations (RobotSettingsView, ManualControlView, TimersView, etc.)
- Risk: User sees no feedback when action fails. Silent failures degrade trust.
- Priority: High

**Rapid onChange state mutations — Debouncing:**
- What's not tested: User drags volume slider quickly. Are in-flight requests cancelled? Do they coalesce?
- Files: `ValetudoApp/ValetudoApp/ViewModels/RobotSettingsViewModel.swift` (all setters)
- Risk: API call storms, inconsistent state.
- Priority: Medium

**Capability gating with DebugConfig interaction:**
- What's not tested: Interaction between API capability detection and DebugConfig.showAllCapabilities override. Real APIs still called?
- Files: ViewModels, RobotDetailView
- Risk: Debug mode hides real issues. Production build behaves differently.
- Priority: Medium

**Consumable warnings notification delivery:**
- What's not tested: Do notifications trigger when consumable <20%? Persisted correctly? User can dismiss and see again?
- Files: `ValetudoApp/ValetudoApp/Services/NotificationService.swift`, RobotManager line 154
- Risk: Critical alerts might not reach user.
- Priority: Medium

---

*Concerns audit: 2026-03-28*
