# Codebase Concerns

**Analysis Date:** 2026-04-04

## Tech Debt

**State Management Fragmentation (DEBT-02):**
- Issue: Room selection and iteration counts were previously scattered across MapViewModel and Views before centralization in RobotManager (Phase 22)
- Files: `ValetudoApp/Services/RobotManager.swift` (lines 22-47), `ValetudoApp/ViewModels/MapViewModel.swift` (lines 65-88)
- Impact: Risk of state desync if Views modify state directly instead of using RobotManager; update logic must route through `roomSelections` and `iterationSelections` dictionaries
- Fix approach: All room selection writes must use `robotManager.roomSelections[robot.id] = ...` via didSet observers; audit all View code to verify this pattern

**Capabilities Caching Pattern (DEBT-06):**
- Issue: Capabilities fetched from Valetudo API are cached with 24-hour TTL in RobotManager but no cache invalidation trigger on robot reconnection or config change
- Files: `ValetudoApp/Services/RobotManager.swift` (lines 59-62, 125-139)
- Impact: If robot firmware updates mid-session, capability list becomes stale; UI shows outdated buttons for disabled features
- Fix approach: Call `invalidateCapabilities(for: robotId)` in `addRobot()`, `updateRobot()`, and on SSE reconnection events; implement capability refresh on first view appearance per robot session

**Error Handling Suppressions (DEBT-08):**
- Issue: Multiple `try?` and silent `catch` blocks suppress network and decoding errors that should be logged or surfaced
- Files: `ValetudoApp/Services/RobotManager.swift` (lines 332, 343, 359, 381), `ValetudoApp/Services/NetworkScanner.swift` (line 172), `ValetudoApp/ViewModels/MapViewModel.swift` (lines 220, 238)
- Impact: Silent failures make debugging difficult; users see stale data without understanding why; offline scenarios not explicitly handled
- Fix approach: Replace `try?` with explicit error logging and state updates; use specific error types instead of silencing; update Views to display "failed to load" state

---

## Known Bugs

**SSE Reconnection Loop Edge Case:**
- Symptoms: SSE connection shows as `isConnected = true` but no data flows; UI appears frozen
- Files: `ValetudoApp/Services/SSEConnectionManager.swift` (lines 65-124)
- Trigger: Network connection drops but socket remains open (e.g., WiFi → LTE handoff); exponential backoff reaches 30-second max wait
- Workaround: Force-quit app and reopen to reset connection state; manual robot refresh will eventually trigger reconnection
- Root cause: Backoff timer reset only on successful data reception; zombie socket keeps isConnected = true during read failures

**Map Rendering Fallback Not Reached:**
- Symptoms: Map displays without segment layers despite successful API response
- Files: `ValetudoApp/Views/MapInteractiveView.swift` (lines 54-72)
- Trigger: `staticLayerImage` computation fails (rare CGImage conversion error); fallback pixel-by-pixel rendering triggered but performs poorly
- Workaround: Pan/zoom map to force re-render; restart app
- Root cause: CGImage pre-render happens in background; race condition if staticLayerImage assignment delayed

**Update Polling Race on App Foreground:**
- Symptoms: Update shown as "in progress" but progress bar stuck; download actually completed
- Files: `ValetudoApp/Services/UpdateService.swift` (lines 113-128)
- Trigger: App backgrounded during download, brought to foreground after robot completed; polling loop doesn't re-sync on scene phase change
- Workaround: Manual refresh of robot status via pull-to-refresh gesture
- Root cause: `pollUntilReadyToApply()` depends on linear loop execution; app suspension breaks loop invariants

---

## Security Considerations

**HTTP Connection Warning Not Enforced (SEC-01):**
- Risk: User can connect to robot via unencrypted HTTP; credentials sent in Base64-encoded Basic Auth header visible in packet capture
- Files: `ValetudoApp/Services/ValetudoAPI.swift` (lines 52-58), robot connection setup in `ValetudoApp/Views/AddRobotView.swift`
- Current mitigation: Config flag `useSSL` exists; HTTP connections show warning banner in RobotDetailView
- Recommendations: Block HTTP connections entirely in production; if HTTP must be allowed, enforce HTTPS Upgrade or refuse connection; add HSTS preload directive guidance for users

**Self-Signed Certificate Bypass (SEC-02):**
- Risk: `SSLSessionDelegate` (lines 65-75 in ValetudoAPI.swift) accepts any self-signed cert without validation; enables MITM attacks on local network
- Files: `ValetudoApp/Services/ValetudoAPI.swift` (lines 65-75), enabled via `config.ignoreCertificateErrors`
- Current mitigation: Bypass only enabled when user explicitly checks "Ignore certificate errors"; limited to local network use
- Recommendations: Add certificate pinning for known Valetudo root CA; require explicit user confirmation with warning per connection, not per config; audit logs for SEC-02 usage

**Password Storage in Keychain Without Encryption (SEC-03):**
- Risk: Robot config including credentials stored in iOS Keychain; if device is jailbroken, Keychain can be accessed
- Files: `ValetudoApp/Services/KeychainStore.swift` (lines 30-120), `ValetudoApp/Services/RobotManager.swift` (lines 82-84, 93-95)
- Current mitigation: Credentials use Keychain's default protection class (completeWhenUserIsPresent)
- Recommendations: Use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` to bind to device; add optional Face ID/Touch ID re-authentication on access; document that jailbroken devices void security

**Credentials Exposed in Logs (SEC-04):**
- Risk: Basic Auth header logged during debug (though marked `privacy: .private`)
- Files: `ValetudoApp/Services/ValetudoAPI.swift` (line 132)
- Current mitigation: Logging framework marks auth header as `.private` (redacted in production)
- Recommendations: Remove auth logging entirely; log only "Authorization header present: yes/no"

---

## Performance Bottlenecks

**Map Pixel Decompression on Every Frame:**
- Problem: `layer.decompressedPixels` property is computed on each Canvas render call; for large maps (4000+ pixels) this runs multiple times per screen refresh
- Files: `ValetudoApp/Views/MapInteractiveView.swift` (lines 62-72), property defined in `RobotMap.swift`
- Cause: Canvas body executes on every state change; decompression runs in draw context (synchronous)
- Improvement path: Cache decompressed pixel sets per layer; invalidate only on new map data; move decompression to background Task before rendering; use `@ObservationIgnored` cache in MapViewModel

**Segment Color Lookup in Drawing Loop:**
- Problem: `segmentColor(segmentId:)` function called O(n_segments * n_pixels_per_frame) times; performs string comparison on each call
- Files: `ValetudoApp/Views/MapInteractiveView.swift` (lines 66-67, 82-83)
- Cause: No caching of segment→color mapping during frame render
- Improvement path: Pre-compute color map as `[String: Color]` at start of Canvas body; reuse across all draw calls in same frame

**RobotDetailViewModel Data Loading Waterfall:**
- Problem: 11 async tasks spawned concurrently (line 149: segmentsTask, consumablesTask, etc.) but each has independent error handling; one slow endpoint blocks UI perception
- Files: `ValetudoApp/ViewModels/RobotDetailViewModel.swift` (lines 138-149)
- Cause: `async let` pattern fires all tasks in parallel, but ViewModel doesn't track which loads succeeded/failed individually
- Improvement path: Use `TaskGroup` with fallback values; show partial UI as data arrives; timeout slow endpoints after 5s and show stale cache instead of spinner

**SSE Reconnection Exponential Backoff CPU Wakes:**
- Problem: Every 1s, 5s, then 30s, the system wakes to retry connection; on poor network this causes battery drain
- Files: `ValetudoApp/Services/SSEConnectionManager.swift` (lines 102-112)
- Cause: Retry loop doesn't check network reachability before attempting; iOS still schedules timer even if connectivity is known-offline
- Improvement path: Use Network framework to monitor connectivity; only attempt reconnect when connectivity returns; exponential backoff resets on connectivity change

---

## Fragile Areas

**MapViewModel State Coordination (FRAGILE-01):**
- Files: `ValetudoApp/ViewModels/MapViewModel.swift` (lines 1-220)
- Why fragile: 40+ @State properties managing map render state, edit mode, selection state, and drawing overlays; changes to room selection flow through `didSet` observers that depend on RobotManager order-of-operations
- Safe modification: Any new feature that touches `selectedSegmentIds` or `selectedIterations` must verify the `didSet` observer chain is preserved; test room selection after every UI refactor; use Xcode Preview with mock data to validate state changes
- Test coverage: Gaps in MapViewModel state transitions (selection → cleaning → reset cycle); SSE update → map refresh → selection preservation

**RobotManager Multi-Robot Polling (FRAGILE-02):**
- Files: `ValetudoApp/Services/RobotManager.swift` (lines 148-200)
- Why fragile: Polling loop respects `activeRobotId` and calls `restartRefreshing()` on change, but if `activeRobotId` is set to `nil`, all polling stops; concurrent modification of `robotStates` dictionary during updates can race if SSE updates arrive mid-poll
- Safe modification: Never directly assign `robotStates[id] = status`; only write through polling loop; activeRobotId changes must happen on @MainActor; test robot switching under heavy SSE load
- Test coverage: Missing test for activeRobotId = nil → restore → state recovery

**UpdateService State Machine Assumptions (FRAGILE-03):**
- Files: `ValetudoApp/Services/UpdateService.swift` (lines 92-150)
- Why fragile: Phase transitions assume sequential execution; `checkForUpdates()` → `startDownload()` → `startApply()` must happen in order, but Views can call any phase's public function; no validation that phase change is legal
- Safe modification: Add phase guard at start of every public function; implement state diagram validation; document which phases are terminal (no forward progress possible)
- Test coverage: Missing tests for out-of-order calls (startApply without startDownload, or startDownload twice)

**SSE JSON Parsing with Silent Fallthrough (FRAGILE-04):**
- Files: `ValetudoApp/Services/SSEConnectionManager.swift` (lines 76-91)
- Why fragile: If `JSONDecoder` fails to parse a line, error is logged but loop continues silently; if 100 consecutive lines fail to decode, connection appears "working" because loop still iterates
- Safe modification: Track decode failure count; disconnect and reconnect if failure rate exceeds threshold; add metrics logging for decode success/failure ratio
- Test coverage: No tests for malformed JSON in SSE stream

---

## Scaling Limits

**Single RobotManager Instance Holds All Robot State:**
- Current capacity: 5-10 robots before UI responsiveness degradation observed in production
- Limit: `robotStates` dictionary with one entry per robot; polling loop iterates all robots sequentially; adding 50+ robots causes 500ms+ refresh latency
- Scaling path: Partition polling into per-robot tasks with independent schedules; use background URLSession for inactive robots (less frequent polls); implement robot groups/favorites to reduce active set

**MapViewModel Segment Pixel Cache Memory:**
- Current capacity: Maps up to 1GB pixel data; caching all decompressed pixels for 3+ robots consumes >2GB RAM
- Limit: `segmentPixelSets: [String: Set<Int>]` holds full pixel indices per segment; Set<Int> for large rooms is 100KB+
- Scaling path: Implement LRU eviction for oldest maps; store only pixel boundary metadata instead of full sets; compress cached pixels; limit to active robot only

**SSE Connection Per Robot:**
- Current capacity: 1 SSE stream per robot; 5 robots = 5 open TCP connections
- Limit: iOS allows ~200 concurrent connections per app, but network bandwidth/CPU is bottleneck around 10 simultaneous SSE streams
- Scaling path: Multiplex SSE over single proxy connection if supporting >10 robots on one network

---

## Dependencies at Risk

**iOS 18+ / Swift 6.0 Requirement:**
- Risk: Codebase uses latest Swift concurrency (actors, @Observable); deployment target iOS 18 means no iOS 17 support
- Impact: App unavailable to ~30% of iOS install base; if issue discovered post-launch, requires maintenance fork for iOS 17
- Migration plan: Add iOS 17 support by replacing @Observable with @StateObject where needed; test with iOS 17 SDK; document OS minimum clearly in App Store

**No Dependency on Stale Frameworks:**
- Risk: Valetudo API v2 is the only external API contract; if Valetudo breaks backward compatibility, app fails
- Impact: Robot owners on older Valetudo versions get incompatible app
- Migration plan: Version Valetudo API responses; implement adapter layer for v1/v2 API differences; document minimum Valetudo version required (current: v0.7.0+)

---

## Missing Critical Features

**No Offline Mode Cache for Robot List:**
- Problem: RobotManager reloads robots from UserDefaults on every app launch, but if app crashed during update, persisted robot list may be corrupted JSON
- Blocks: Users cannot recover after app crash; must re-add robots manually
- Recommended solution: Implement persistent store backup (keep 2 versions of RobotConfig JSON); validate stored JSON on load; show "Corrupted robot config, would you like to restore from backup?" on error

**No Update Check Throttle per Robot:**
- Problem: If user opens app while on metered connection, update check fires immediately; with 5+ robots, 5 concurrent API calls to Valetudo
- Blocks: Cannot optimize for bandwidth-constrained environments
- Recommended solution: Implement per-robot update-check throttle (max 1/hour); batch checks when network type changes (WiFi→LTE)

**No Capability Refresh on Robot Config Change:**
- Problem: If user changes hostname, SSL setting, or credentials, cached capabilities are stale and don't refresh
- Blocks: Edited robot may not show correct features (e.g., still shows zone cleaning button even though endpoint is now unavailable)
- Recommended solution: Invalidate capability cache in `updateRobot()` method; trigger refresh on first RobotDetailView appearance

---

## Test Coverage Gaps

**MapViewModel State Transitions (TEST-GAP-01):**
- What's not tested: Full lifecycle of room selection (empty → multi-select → clean → reset); SSE map update while rooms selected
- Files: `ValetudoApp/ViewModels/MapViewModel.swift`
- Risk: Room selection behavior breaks silently; regression testing relies on manual QA
- Priority: HIGH — affects core feature used by 100% of users

**UpdateService Out-of-Order Phase Calls (TEST-GAP-02):**
- What's not tested: Calling `startDownload()` twice, or `startApply()` without prior `startDownload()`, or `startDownload()` in non-updateAvailable phase
- Files: `ValetudoApp/Services/UpdateService.swift`
- Risk: Phase machine crashes or exhibits undefined behavior if called from buggy UI code
- Priority: HIGH — affects update feature, critical path

**RobotManager Robot Switching Under Load (TEST-GAP-03):**
- What's not tested: Switching activeRobotId while SSE updates are flowing; clearing activeRobotId and restoring state
- Files: `ValetudoApp/Services/RobotManager.swift`
- Risk: Polling state lost or mixed between robots on rapid switching; reports show occasional "wrong robot status displayed"
- Priority: MEDIUM — affects multi-robot users; single-robot users unaffected

**SSE Line Parsing Malformed JSON (TEST-GAP-04):**
- What's not tested: Feed SSE stream with 100 consecutive invalid JSON lines; verify connection doesn't appear "healthy"
- Files: `ValetudoApp/Services/SSEConnectionManager.swift`
- Risk: Robot appears online but data silently stops flowing; users don't notice stale status
- Priority: MEDIUM — edge case, but affects reliability perception

**Error Handling Integration (TEST-GAP-05):**
- What's not tested: ErrorRouter displayed when APIError thrown from every user action (20+ actions); error message clarity and actionability
- Files: `ValetudoApp/Helpers/ErrorRouter.swift` and all Views that use it
- Risk: Users see technical error messages ("Decoding error: ...") instead of friendly explanations; no recovery guidance
- Priority: MEDIUM — UX quality issue; no data loss risk

**Keychain Storage Corruption (TEST-GAP-06):**
- What's not tested: Simulate Keychain returning corrupted data or OSStatus errors; verify app doesn't crash and offers recovery
- Files: `ValetudoApp/Services/KeychainStore.swift`
- Risk: If Keychain becomes corrupted (rare but possible on jailbroken devices), app crashes on credential read
- Priority: LOW — rare occurrence, but safety-critical when it happens

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | Status |
|----------|-------------------|----------------|--------|
| `try?` suppression for JSON decode in RobotManager | Simpler code, fewer error branches | Silent failures; stale robot list; hard to debug | OPEN — affects reliability |
| Capabilities cached without refresh trigger | Avoid repeated API calls | Stale capabilities after config change or FW update | OPEN — affects correctness |
| `staticLayerImage` fallback to pixel-by-pixel | Works for rare CGImage failures | Slow rendering on large maps; bad UX during race | OPEN — performance impact |
| `didSet` observers for room selection state sync | Prevents passing selectionState down 10 levels | Fragile; easy to add new property without observer | OPEN — maintainability risk |
| SSE reconnection exponential backoff no network check | Simple retry logic | Battery drain on metered networks; thrashing on poor WiFi | OPEN — affects power usage |
| UpdateService phase guards in public functions | Guard prevents bad state transitions | Phase machine permissive; needs state diagram doc | MITIGATED — guards present but undocumented |

---

*Concerns audit: 2026-04-04*
