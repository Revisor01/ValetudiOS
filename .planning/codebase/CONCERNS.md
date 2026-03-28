# Codebase Concerns

**Analysis Date:** 2026-03-28

## Tech Debt

**Force-unwrap URLs in URLSession handling:**
- Issue: Hardcoded force-unwrap operators on URL strings without validation
- Files: `ValetudoApp/ValetudoApp/Services/NetworkScanner.swift:154`, `ValetudoApp/ValetudoApp/Views/RobotDetailView.swift:106`
- Impact: Runtime crash if URL construction fails (e.g., invalid host characters). Network scanner assumes all hosts form valid URLs.
- Fix approach: Use optional URL binding with error handling instead of `!`. Validate host strings before URL construction.

**Debug print statements in production code:**
- Issue: Extensive `print()` debugging statements left throughout codebase
- Files: `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift` (40+ print calls), `ValetudoApp/ValetudoApp/Views/RobotSettingsView.swift` (20+ print calls), `ValetudoApp/ValetudoApp/Views/ConsumablesView.swift`
- Impact: Noise in system logs, performance overhead (print is serialized), data exposure (coordinates logged), unprofessional in production
- Fix approach: Replace with `Logger` (already imported and used elsewhere). Create logging utility with debug-only envelope.

**Silently swallowed errors in critical paths:**
- Issue: Multiple error handlers that catch exceptions but don't log, retry, or notify user
- Files: `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift:170` (zone cleaning), `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift:104` (capability check), `ValetudoApp/ValetudoApp/Services/RobotManager.swift:197` (updater check)
- Impact: User has no visibility into why actions fail (e.g., zone cleaning silently fails). Makes debugging impossible. Operations fail without feedback.
- Fix approach: Log all errors with `Logger.warning()`. Provide user-facing error messages for recoverable errors (via state). Only suppress errors for truly optional capabilities.

**Mixed error handling patterns:**
- Issue: Inconsistent error handling across ViewModels and Services - some use Logger, some use print, some silently ignore
- Files: Most of `MapViewModel`, `RobotSettingsViewModel`, `RobotManager`
- Impact: Unpredictable behavior, difficult to trace issues across modules
- Fix approach: Establish error handling convention - all errors logged to Logger, critical errors propagated to UI

## Fragile Areas

**MapView complexity and coordinate transformation:**
- Files: `ValetudoApp/ValetudoApp/Views/MapView.swift` (2532 lines), `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift:276-353` (splitRoom function)
- Why fragile: Complex geometry calculations for map coordinate transformation (pixel ↔ API coords). Heavy use of CGFloat arithmetic with multiple conversion layers (gesture → adjusted → pixel → API). Coordinate system assumptions tied to hardcoded pixel sizes and scaling.
- Safe modification: Extract coordinate transformation into dedicated `MapCoordinateConverter` class with unit tests for edge cases (zero dimensions, extreme scales, portrait/landscape transitions). Add assertion guards for preconditions.
- Test coverage: No unit tests for coordinate transformation logic. Split operation has manual coordinate verification in print statements instead of assertions.

**MapViewModel state explosion:**
- Files: `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift:1-75` (45+ @Published properties)
- Why fragile: 45+ published properties managing zones, restrictions, edit modes, room selection, GoTo states, presets. State transitions not formally modeled (editMode enum helps but only partial). Easy to leave contradictory state (e.g., drawnZones non-empty with editMode=.none).
- Safe modification: Consider state machine pattern (using enum with associated values). Group related properties into sub-structs (ZoneEditingState, RestrictionEditingState, GoToState).
- Test coverage: No tests for state machine transitions or edge cases (cancel mid-operation, rapid mode changes).

**SSE connection management with actor + callbacks:**
- Files: `ValetudoApp/ValetudoApp/Services/SSEConnectionManager.swift`, `ValetudoApp/ValetudoApp/Services/RobotManager.swift:88-101`
- Why fragile: Actor-based SSE manager combined with closure callbacks crossing actor boundaries. Reconnection logic waits 30s before retry — user perceives 30s lag on disconnect. No exponential backoff or max retry logic.
- Safe modification: Add optional backoff strategy parameter. Track retry count and warn/fail after N attempts. Add cancellation token tracking to prevent double-connect.
- Test coverage: No tests for reconnection scenarios, timeout handling, or concurrent multi-robot SSE state.

**Robot network discovery race conditions:**
- Files: `ValetudoApp/ValetudoApp/Services/NetworkScanner.swift:77-93` (mergeMDNSResults)
- Why fragile: mDNS results merged while IP scan running — duplicate detection via host string comparison. If host resolution changes (IP vs hostname), duplicates slip through. Three hardcoded subnets (en0, en1) may miss VPN/mobile interfaces.
- Safe modification: Use UUID or stable robot identifier instead of host string for deduplication. Support dynamic interface detection. Validate host format before URL construction.
- Test coverage: No tests for network discovery. IP scan always runs (even in WiFi-only networks) creating unnecessary overhead.

**RobotSettingsView capability loading race:**
- Files: `ValetudoApp/ValetudoApp/Views/RobotSettingsView.swift:516`, `ValetudoApp/ValetudoApp/ViewModels/RobotSettingsViewModel.swift:63-100`
- Why fragile: Many async capability checks that may fail independently. `isInitialLoad` flag used to suppress updates during first load, but unclear when it resets. Multiple @Published properties toggled based on `DebugConfig.showAllCapabilities` at init time — debug flag doesn't update at runtime.
- Safe modification: Consolidate capability checks into single API call (if backend supports). Clear initialization sequence docs.
- Test coverage: No tests for capability loading sequences or timeout behavior.

## Test Coverage Gaps

**Network and API layers untested:**
- What's not tested: ValetudoAPI request/response handling, URLSession integration, SSL certificate bypass behavior, error codes and retry logic
- Files: `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift` (738 lines, all untested)
- Risk: Encoding/decoding bugs silently fail. HTTP error handling not validated. SSL handshake edge cases untested.
- Priority: High — API is critical path for all robot operations

**ViewModels untested:**
- What's not tested: MapViewModel state transitions, zone/restriction editing flows, room rename/join/split coordination with API
- Files: `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift`, `ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift`, `ValetudoApp/ValetudoApp/ViewModels/RobotSettingsViewModel.swift`
- Risk: Refactoring breaks silent failures; state machine bugs (leftover selections, duplicate operations)
- Priority: High — ViewModels are core business logic

**Persistence and migration untested:**
- What's not tested: Password migration from UserDefaults to Keychain, robot state saving/loading, edge cases (corrupted data, version mismatches)
- Files: `ValetudoApp/ValetudoApp/Services/RobotManager.swift:253-281` (migration logic)
- Risk: Data loss during migration or app updates. Keychain failures silently swallowed.
- Priority: High — handles sensitive data

**Multi-robot state management untested:**
- What's not tested: Concurrent refresh of multiple robots, SSE connection switching between robots, state isolation (one robot's error doesn't affect others)
- Files: `ValetudoApp/ValetudoApp/Services/RobotManager.swift:79-120` (refresh loop)
- Risk: State corruption under load, SSE connections leaking across robots
- Priority: Medium — affects multi-robot users

**View integration untested:**
- What's not tested: MapView rendering, map interaction (zone drawing, restriction deletion), UI state consistency
- Files: `ValetudoApp/ValetudoApp/Views/MapView.swift` (2532 lines, complex Canvas+gesture handling)
- Risk: Gestures mishandled, coordinate transforms fail on rotation, memory spikes from map rendering
- Priority: Medium — impacts user experience

## Scaling Limits

**Map rendering with large pixel arrays:**
- Current capacity: Tested with maps up to ~50K pixels (typical robot map). Canvas rendering blocks main thread during decompression.
- Limit: Maps beyond ~100K pixels will cause jank. Pixel decompression not cached optimally across rotations.
- Scaling path: Move pixel decompression to background thread. Cache compressed data between rotations. Consider canvas optimization (downsample for preview).

**SSE connection per robot:**
- Current capacity: 1 SSE stream per robot, 5-second polling fallback for all robots
- Limit: With 5+ robots, polling overhead becomes significant (5 API calls every 5 sec = 60+ req/min). SSE reconnect waits 30s before retry.
- Scaling path: Implement exponential backoff (1s → 5s → 30s). Add connection pooling if backend supports multiplexing.

**Memory footprint with map caching:**
- Current capacity: Full map cached in memory. Typical 256KB per map. 4 robots = ~1MB.
- Limit: Large-scale deployments (10+ robots) may hit memory pressure on older devices.
- Scaling path: Implement LRU cache with max memory budget. Store large maps to disk with lazy loading.

## Dependencies at Risk

**URLSession and custom SSL delegate:**
- Risk: SSLSessionDelegate bypasses certificate validation for all requests when `ignoreCertificateErrors=true`. No way to re-enable validation per-request. Future iOS versions may deprecate or restrict this pattern.
- Impact: Self-signed cert scenarios work but with security trade-off. No way to pin certificates or validate specific hosts.
- Migration plan: Implement certificate pinning instead. Add per-robot cert validation override (accept known bad cert, reject others).

**UserDefaults for sensitive data (migrating to Keychain):**
- Risk: Migration incomplete — robots array still stored in UserDefaults (without passwords, but metadata visible)
- Impact: Reversible data leak if device compromised (can see which robots are configured)
- Migration plan: Complete Keychain migration for all robot metadata. Use encrypted UserDefaults or omit non-essential data.

## Known Bugs

**Coordinate transformation loss of precision:**
- Symptoms: Zone cleaning or GoTo commands appear offset on robot map. Especially noticeable on maps with large pixel sizes (>10px).
- Files: `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift:276-353` (splitRoom), `ValetudoApp/ValetudoApp/Views/MapView.swift` (gesture coordinate handling)
- Trigger: Draw zone on top-left or bottom-right of map. Split large room. View rotation during GoTo mode.
- Workaround: Recalibrate map or reattempt operation. Avoid splitting rooms near edges.
- Root cause: Integer rounding in coordinate transformation + gesture offset calculations. Accumulating float→int conversions lose precision.

**SSE reconnection with concurrent robot refresh:**
- Symptoms: "SSE connection lost" log spam on poor networks. Robot state may not update for 30+ seconds.
- Files: `ValetudoApp/ValetudoApp/Services/RobotManager.swift:82-103` (SSE connect loop), `ValetudoApp/ValetudoApp/Services/SSEConnectionManager.swift:98-105` (reconnect delay)
- Trigger: Network glitch, robot reboots, WiFi roam
- Workaround: Manual refresh via UI (pull-to-refresh, switch tabs)
- Root cause: Hard 30-second retry delay + no exponential backoff. On poor networks, connection fails immediately and cycle repeats every 30s.

**Map preview may not load in detail view:**
- Symptoms: Map preview shows loading spinner indefinitely or doesn't render when switching robots quickly
- Files: `ValetudoApp/ValetudoApp/Views/MapView.swift:58-150` (MapPreviewView)
- Trigger: Switch between robots while map is still loading. Robot goes offline during preview load.
- Workaround: Navigate to full map view. Refresh manually.
- Root cause: Preview uses separate state from full map. No coordination on robot change — old request may still be in flight.

## Missing Critical Features

**No offline robot detection strategy:**
- Problem: App assumes robot availability. No UI indication of connection quality or retry strategy.
- Blocks: Batch operations (clean multiple robots at once), scheduled operations
- Recommendation: Add connection quality indicator. Implement operation queuing for offline robots (retry when back online).

**No error recovery or user feedback for failed operations:**
- Problem: Operations fail silently (clean zones, restrictions, renames). User has no way to retry.
- Blocks: Reliable automation, trust in app for critical operations
- Recommendation: Add error overlay with retry button. Queue failed operations for replay.

**No map caching between app launches:**
- Problem: Map reloads every time app opens, even if robot state hasn't changed
- Blocks: Quick access, offline mode
- Recommendation: Cache map + restrictions to disk. Validate freshness on app launch.

## Performance Bottlenecks

**Map rendering jank during zone drawing:**
- Problem: Canvas redraws entire map on every gesture update. No throttling or frame skipping.
- Files: `ValetudoApp/ValetudoApp/Views/MapView.swift` (Canvas with heavy drawing logic)
- Cause: Gesture handler directly updates @Published property → view redraws. Pixel decompression happens in main thread.
- Improvement path: Throttle gesture updates (debounce 50ms). Move decompression to background. Use Canvas optimizations (opacity layers).

**SSE polling fallback creates unnecessary network traffic:**
- Problem: All robots polled every 5 seconds (50+ requests for 10 robots), even with SSE active
- Files: `ValetudoApp/ValetudoApp/Services/RobotManager.swift:106-115`
- Cause: Polling loop runs unconditionally; only skips if SSE active. But SSE reconnects may lag.
- Improvement path: Skip polling when SSE active for 30+ seconds. Add exponential backoff to polling (start at 5s, extend to 30s).

**Network scanner blocks UI during IP scan:**
- Problem: Scanning all 254 hosts (even on slow networks) causes 3-30s wait time
- Files: `ValetudoApp/ValetudoApp/Services/NetworkScanner.swift:95-151`
- Cause: 254 concurrent tasks with 1.5s timeout each. Single WiFi adapter can't handle 254 connections simultaneously.
- Improvement path: Limit concurrent tasks to 10-20. Add subnet detection (skip obviously empty subnets). Prioritize mDNS, abort IP scan after timeout.

---

*Concerns audit: 2026-03-28*
