# Feature Research

**Domain:** iOS native app — Valetudo robot vacuum controller
**Researched:** 2026-03-29 (v2.0.0 update process hardening addendum)
**Confidence:** HIGH (code read directly, UX patterns from real apps + OTA design literature)

---

## v2.0.0 Addendum: Firmware Update Process Hardening

This section focuses exclusively on firmware update UX patterns for v2.0.0. It supplements the v1.2.0 feature research below.

### What Already Exists (Do Not Re-Implement)

| Component | Location | Notes |
|-----------|----------|-------|
| Update available banner in detail view | `RobotDetailView.swift` | Shows version, install + changelog buttons |
| Update badge on robot list | `RobotListView.swift` | Badge when update available |
| Alert confirmation before starting | `RobotDetailView.swift` | `.alert` with cancel/confirm |
| Download polling loop (5s, 60 iterations = 5min) | `RobotDetailViewModel.startUpdate()` | For-loop, no timeout feedback to user |
| `applyUpdate()` call | `RobotDetailViewModel.startUpdate()` | Called after download completes |
| Basic spinner during update | `RobotDetailView.swift` | `updateInProgress` flag, simple banner |
| `UpdaterState` model with 4 states | `RobotState.swift` | Idle / ApprovalPending / Downloading / ApplyPending |
| `metaData.progress.current/total` in `UpdaterState` | `RobotState.swift` | Progress data exists but is NOT used in UI |
| GitHub-based fallback update check | `RobotDetailViewModel.checkForUpdate()` | Duplicate logic alongside Valetudo updater |

### Known Issues in Existing Implementation

1. `startUpdate()` has no guard against double-invocation — two concurrent calls will send two `downloadUpdate` requests
2. `updateInProgress = true` is set but no `updateInProgress = false` on the success path after `applyUpdate()` (robot goes offline, so this is semi-intentional, but the state never resolves cleanly on error recovery)
3. The download polling loop silently exits on timeout with `updateInProgress = false` and no user-visible error message
4. `apply` errors are logged but no error is surfaced to the user
5. The spinner banner during `updateInProgress` can be swiped/navigated away from — nothing blocks the user from doing other things during the Apply phase
6. `checkForUpdate()` is called on every `onAppear` of the detail view — triggers unnecessary state changes on return from sub-screens
7. Two parallel update-availability checks exist: Valetudo updater API path and GitHub API path — they can produce conflicting state
8. `progress.current/total` from the API is decoded but never rendered — user sees no download percentage

---

## Feature Landscape — v2.0.0 Hardening

### Table Stakes (Users Expect These)

These are the minimum required for the update flow to feel trustworthy. Missing any of these makes the feature feel broken or dangerous.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| State machine with explicit states | Every download/apply flow in any mature app (Apple, Tesla, Sonos, Roborock) has discrete named states. A boolean `updateInProgress` is not enough — users need to know *which* phase they're in | MEDIUM | Idle → Checking → ApprovalPending → Downloading → ApplyPending → Applying → Done / Error. Maps 1:1 to Valetudo's `UpdaterState.__class` values plus app-managed states for Applying and Done |
| Download progress indicator | Valetudo already returns `metaData.progress.current/total` during `ValetudoUpdaterDownloadingState`. Not showing it is a missed opportunity and leaves users uncertain if anything is happening | LOW | `current/total` already decoded in `UpdaterState.metaData.progress` — just needs UI wiring. Show as percentage or progress bar in existing banner |
| Error state with user-visible message | Download timeout, network error, apply error — currently all silently set `updateInProgress = false`. Users are left with no feedback about what failed | LOW | Requires an `UpdateError` enum. Show inline in the update banner — no new UI surface needed |
| Double-invocation guard | "Tapping twice" or "re-entering view" while update is in progress must not send a second download/apply request to the robot | LOW | `guard !updateInProgress else { return }` at entry to `startUpdate()`. Already partially present via `updateInProgress` flag but not enforced consistently |
| Single source of truth for update state | Two parallel checks (Valetudo updater API + GitHub releases API) can show contradictory states. This is confusing and creates edge cases | MEDIUM | Prefer Valetudo updater API as primary. GitHub API as fallback only when Valetudo updater capability is absent. Merge into one `@Published var updateState: UpdateLifecycleState` |

### Differentiators (Competitive Advantage)

These go beyond what the Valetudo web UI does and make the native app experience clearly superior for dangerous operations.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Apply-phase fullscreen lock | During `Applying`, the robot is rebooting and must not be interrupted. Apple Home, Sonos, and eufy all block UI during this phase. Navigating away or backgrounding could confuse the user about whether the update succeeded | MEDIUM | `.fullScreenCover` with `interactiveDismissDisabled(true)`. Cannot be swiped down. Shows "Robot is updating — do not close the app" with animated indicator. Dismisses automatically on reconnect or timeout |
| Reconnect detection after apply | After `applyUpdate()`, the robot reboots and comes back online. Detecting this (polling `/updater/state` until `isIdle`, max 3min) and showing a success confirmation closes the update loop cleanly | MEDIUM | Poll `/updater/state` on 10s interval post-apply. On `isIdle` response: dismiss fullscreen lock, show success toast. On 3min timeout: show "Update may have completed — robot may need a manual check" |
| Intelligent update check throttling | Checking on every `onAppear` wastes a network round-trip and can show a stale state on re-entry to the detail view. Real apps (Apple Home, Roborock) check once per session or on explicit pull-to-refresh | LOW | Store `lastUpdateCheckDate`. Only re-check if `lastUpdateCheckDate` is nil or >1hr old. Expose "Check now" button in Settings for manual refresh |
| Retry from Error state | After a download or apply error, show a "Retry" button inline in the update banner rather than requiring the user to restart the whole flow | LOW | In `UpdateLifecycleState.error(UpdateError)`, show error message + Retry button in existing banner. Retry resets state machine to `Idle` and re-triggers `checkForUpdate()` |

### Anti-Features

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Background update installation | "Update while I sleep" | iOS does not allow maintaining a network connection for arbitrary durations in background. `BGAppRefreshTask` runs at most 30s, not enough for a multi-MB firmware download and robot reboot cycle | Make the foreground experience so smooth that users willingly stay in the app for the 2-3 minutes required |
| Cancel mid-download | "Let me abort if it takes too long" | Valetudo has no `/updater` cancel action. Sending `download` again while already downloading is undefined behavior. Cancelling from the app side would leave the robot's updater in `Downloading` state with no way to recover from iOS | Do not expose a cancel button. Show a clear time estimate ("typically 1-2 minutes") and progress percentage so users are not anxious |
| Auto-apply without confirmation | "Just install it" | Firmware updates reboot the robot. If the robot is mid-clean, this destroys the cleaning session. Auto-applying without user awareness violates the principle of least surprise | Always require explicit user confirmation before applying. Warn if robot is currently cleaning |
| Show full release notes inline | "What changed?" | GitHub release bodies are Markdown with HTML, can be multi-KB, and are formatted for desktop browsers. Rendering arbitrary Markdown in SwiftUI requires external dependencies (against project constraints) | Show the GitHub release URL as a tappable link that opens Safari. Already implemented in current code |
| Persistent "update done" screen | "Show success for 10 seconds" | After apply, the robot reboots and SSE disconnects. The app cannot reliably determine when the robot is back online without polling. A permanent success screen could be wrong if the update failed silently on the robot side | Show a dismissible success message ("Update complete — reconnecting...") and surface the new firmware version from `/updater/state` once the robot responds |

---

## Feature Dependencies (v2.0.0)

```
UpdateLifecycleState (enum)
    └──replaces──> Bool updateInProgress + UpdaterState.stateType string comparison
    └──drives──> All UI branches in update banner
    └──drives──> fullScreenCover presentation for Applying phase

Download progress display
    └──requires──> UpdaterState.metaData.progress.current/total (already decoded)
    └──requires──> UpdateLifecycleState.downloading(progress: Double)

Apply-phase fullscreen lock
    └──requires──> UpdateLifecycleState.applying
    └──requires──> .fullScreenCover with interactiveDismissDisabled(true)
    └──depends──> Post-apply reconnect detection (to dismiss the lock)

Post-apply reconnect detection
    └──requires──> Polling task after applyUpdate() succeeds
    └──drives──> Transition to UpdateLifecycleState.done or .error(.applyTimeout)

Error state with Retry
    └──requires──> UpdateLifecycleState.error(UpdateError)
    └──requires──> UpdateError enum (downloadFailed, applyFailed, downloadTimeout, applyTimeout)

Single source of truth
    └──replaces──> checkForUpdate() dual-path (Valetudo API + GitHub API)
    └──simplifies──> UpdateLifecycleState transitions

Intelligent throttling
    └──requires──> lastUpdateCheckDate: Date? stored in ViewModel
    └──prevents──> Re-checking on every onAppear
```

### Dependency Notes

- **State machine requires resolving dual-path update check first:** The current dual-path (Valetudo updater API + GitHub release API) produces two independent `@Published` vars. A clean state machine needs a single driver. Consolidate this before building the state machine.
- **fullScreenCover for Apply requires post-apply polling:** The cover has no natural dismiss trigger (the robot goes offline). Without the reconnect detection loop, the fullscreen cover would be permanently stuck. These two features must ship together.
- **Progress display is zero-dependency:** `metaData.progress` is already decoded. This is a UI-only change that can ship independently and early.

---

## MVP Definition for v2.0.0

### Must Ship (Core Hardening)

- [ ] **UpdateLifecycleState state machine** — consolidates `updateInProgress` bool + stateType string; single source of truth
- [ ] **Double-invocation guard** — `guard` at `startUpdate()` entry
- [ ] **Error state with user-visible message** — replaces silent `updateInProgress = false`
- [ ] **Download progress percentage** — wire existing `current/total` to ProgressView
- [ ] **Apply-phase fullscreen lock** — `.fullScreenCover` with `interactiveDismissDisabled(true)`

### Add After Core is Stable

- [ ] **Post-apply reconnect detection** — polling loop after `applyUpdate()`; auto-dismiss fullscreen cover on success
- [ ] **Retry from Error state** — Retry button in error banner
- [ ] **Intelligent update check throttling** — `lastUpdateCheckDate` check in `checkForUpdate()`

### Defer (v2.x or Later)

- [ ] **Dual-source consolidation (Valetudo API + GitHub API)** — refactor to prefer Valetudo updater; GitHub as fallback — architectural cleanup, not user-facing, defer if time-constrained

---

## Feature Prioritization Matrix (v2.0.0)

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| State machine (UpdateLifecycleState) | HIGH | MEDIUM | P1 — all other features build on this |
| Double-invocation guard | HIGH | LOW | P1 — safety critical |
| Error state + user message | HIGH | LOW | P1 — currently silent failures |
| Download progress display | MEDIUM | LOW | P1 — data already available |
| Apply-phase fullscreen lock | HIGH | MEDIUM | P1 — prevents interference in most critical phase |
| Post-apply reconnect detection | MEDIUM | MEDIUM | P2 — polish, not safety |
| Retry from Error | MEDIUM | LOW | P2 — convenience |
| Update check throttling | LOW | LOW | P2 — optimization |
| Dual-source consolidation | MEDIUM | MEDIUM | P3 — architectural, no user-facing change |

---

## Real-World Pattern Analysis

### Apple Home App (HomeKit)
- Update available: Banner at top of Home overview with accessory count badge
- Update flow: "Update All" button → progress per-accessory, percentage shown
- During update: Accessory shows "Updating..." status, controls disabled (greyed out)
- Post-update: Banner disappears, version shown in accessory settings
- **Key pattern:** Individual accessory controls are disabled during update (scoped lock, not app-wide)
- **Relevance:** Disable robot control buttons during `Applying` phase

### Tesla App
- Update available: Notification + banner on vehicle card
- Scheduling: User picks a time window, or taps "Update Now"
- During apply: Vehicle card shows animated progress ring; vehicle unavailable indicator
- Post-update: Push notification "Your Tesla has been updated to X.X.X"
- **Key pattern:** Explicit scheduling + non-intrusive background awareness. For Valetudo (local-only LAN), scheduling is not applicable — but the "vehicle unavailable" indicator pattern is directly applicable.
- **Relevance:** Show "Robot updating — unavailable" on robot list row during Apply phase

### Sonos App
- Update available: Banner blocks app use ("Update required before continuing") — historically notorious for this
- During update: Progress bar per speaker, percentage shown, speaker name listed
- Known failure: Infinite update loop bug (2024) where app showed update screen even after update was complete — caused by stale state not being cleared
- **Key pattern (negative):** Sonos's "block the entire app" approach caused massive user backlash. For ValetudiOS with multiple robots, blocking the whole app because one robot is updating would be wrong.
- **Relevance:** Scope the UI lock to the specific robot's detail view / fullscreen cover, not the whole app

### eufy Security App
- Update available: Badge in device list
- During update: Modal with progress percentage, "Do not close the app" warning
- Post-update: Automatic dismissal + version confirmation message
- **Key pattern:** The "Do not close the app" modal is the standard for IoT firmware that requires device reboot. Maps directly to the Apply-phase fullscreen lock requirement.
- **Relevance:** This is the pattern to implement for the Apply phase

### Roborock App
- Update available: Notification in robot detail
- During update: Full-page blocking screen with percentage and "Do not turn off robot or close the app" instruction
- Post-update: Returns to main screen, shows new firmware version
- **Key pattern:** Full-page blocking during update is standard for robot vacuums — users accept this because it's short
- **Relevance:** Confirms `.fullScreenCover` approach is correct for Apply phase

---

## Sources

- Valetudo `UpdaterState` class hierarchy (Idle / ApprovalPending / Downloading / ApplyPending): read from `/Users/simonluthe/Documents/valetudo-app/ValetudoApp/ValetudoApp/Models/RobotState.swift` lines 709-748 (HIGH confidence)
- Existing `startUpdate()` implementation: read from `/Users/simonluthe/Documents/valetudo-app/ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift` lines 450-490 (HIGH confidence)
- `UpdaterState.metaData.progress.current/total` already decoded: confirmed in `RobotState.swift` lines 720-727 (HIGH confidence)
- Sonos "update screen blocks app" behavior and infinite loop bug: [Sonos Community — app stops working when update detected](https://en.community.sonos.com/controllers-and-music-services-229131/sonos-app-stops-working-when-it-detected-an-update-6928341) (MEDIUM confidence — community report)
- Apple Home firmware update banner + "Update All" pattern: [MakeUseOf — How to Update Apple HomeKit Accessories](https://www.makeuseof.com/how-to-update-apple-homekit-accessories-home-app/) (MEDIUM confidence — editorial description)
- SwiftUI `fullScreenCover` + `interactiveDismissDisabled`: [Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/view/fullscreencover(ispresented:ondismiss:content:)) (HIGH confidence)
- eufy Security / IoT "do not close the app" modal pattern: [eufy Update Firmware via App](https://service.eufy.com/article-description/Update-Firmware-for-eufySecurity-Devices-via-App) (MEDIUM confidence)
- OTA idempotency and post-update verification patterns: [Robots Ops — OTA Updates in RobotOps](https://www.robotsops.com/comprehensive-tutorial-on-ota-updates-in-robotops/) (MEDIUM confidence)

---

---

## v1.2.0 Original Research (retained for reference)

**Domain:** iOS native app — Valetudo robot vacuum controller (v1.2.0 milestone)
**Researched:** 2026-03-27
**Confidence:** HIGH (API endpoints verified against Valetudo source at github.com/Hypfer/Valetudo)

---

### Context: What Already Exists

The app already implements the following API endpoints (not in scope for v1.2.0):
BasicControlCapability, GoToLocationCapability, ManualControlCapability, HighResolutionManualControlCapability, ZoneCleaningCapability, MapSegmentationCapability, CombinedVirtualRestrictionsCapability, MapSegmentEditCapability, MapSegmentRenameCapability, MapSegmentMaterialControlCapability, FloorMaterialDirectionAwareNavigationControlCapability, MappingPassCapability, MapResetCapability, FanSpeedControlCapability, WaterUsageControlCapability, OperationModeControlCapability, ConsumableMonitoringCapability, CurrentStatisticsCapability, TotalStatisticsCapability, DoNotDisturbCapability, SpeakerVolumeControlCapability, SpeakerTestCapability, CarpetModeControlCapability, PersistentMapControlCapability, LocateCapability, AutoEmptyDockAutoEmptyIntervalControlCapability, AutoEmptyDockManualTriggerCapability, MopDockCleanManualTriggerCapability, MopDockDryManualTriggerCapability, MopDockMopWashTemperatureControlCapability, MopDockMopAutoDryingControlCapability, KeyLockCapability, ObstacleAvoidanceControlCapability, PetObstacleAvoidanceControlCapability, CarpetSensorModeControlCapability, CollisionAvoidantNavigationControlCapability, QuirksCapability, WifiConfigurationCapability, WifiScanCapability, Timers (full CRUD).

---

### Feature Landscape (v1.2.0)

#### Table Stakes

| Feature | Why Expected | Complexity | Dependency |
|---------|--------------|------------|------------|
| Robot row fully tappable | Every iOS list row is tappable as a unit — tapping only text feels broken | LOW | None — pure SwiftUI layout fix |
| Notification action handlers (GO_HOME, LOCATE) | Defined actions that do nothing destroy trust. Users tap them expecting a result | LOW | Requires RobotManager reference in notification delegate |
| User-visible error feedback | Silent failures are a usability failure — user has no idea if an action succeeded | MEDIUM | Requires shared error state mechanism across views |
| mDNS/Bonjour robot discovery | IP brute-force scanning is slow (254 IPs × 1.5s timeout batched). Valetudo advertises `_valetudo._tcp` via Bonjour by default — apps are expected to use it | MEDIUM | NWBrowser (Network.framework), no external deps needed |
| SSE real-time state updates | 5-second polling creates noticeable UI lag during cleaning. Valetudo exposes `/api/v2/robot/state/attributes/sse` and `/api/v2/robot/state/map/sse` natively | MEDIUM | Replace polling loop in RobotManager |
| MapSnapshot support | Map backup/restore is a standard Valetudo feature many users rely on before map edits | MEDIUM | New capability — GET/PUT `/robot/capabilities/MapSnapshotCapability` |
| PendingMapChange handling | After a mapping run, some robots require accept/reject of the new map — ignoring this leaves robots in limbo | MEDIUM | New capability — GET/PUT `/robot/capabilities/PendingMapChangeHandlingCapability` |
| Valetudo Events display | `/api/v2/events/` stores consumable depletion, dust bin full, mop reminders, errors. Not polling these means the app misses robot-side event tracking | MEDIUM | New endpoint — GET `/api/v2/events/`, PUT `/:id/interact` |
| CleanRouteControl | Many robots offer route selection (standard vs bow-tie vs spiral etc.) — this setting appears in Valetudo web UI and users expect it in native app | LOW | New capability — GET/PUT `/robot/capabilities/CleanRouteControlCapability` |

#### Differentiators (v1.2.0)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| ObstacleImages browsing | Show photos of detected obstacles (pet waste, cables, shoes) from last cleaning run — unique to AI-equipped robots (Roborock S8 Pro Ultra etc.) | MEDIUM | `/robot/capabilities/ObstacleImagesCapability` — GET `/img/:id` returns JPEG/PNG stream. Rate-limited 3/sec on server side. |
| VoicePackManagement | Download custom voice packs by URL/language — useful for non-English users. Valetudo web UI has this but iOS native UX is better | MEDIUM | GET current language + operation status, PUT with download URL |
| AutoEmptyDock duration control | Fine-tune how long the auto-empty cycle runs — separate from interval | LOW | `AutoEmptyDockAutoEmptyDurationControlCapability` — GET/PUT duration |
| MopDock drying time control | Control how long the mop drying cycle runs | LOW | `MopDockMopDryingTimeControlCapabilityRouter` — GET/PUT duration |
| Robot properties endpoint | `/api/v2/robot/properties` returns static robot metadata not currently consumed — useful for displaying model details, quirk info | LOW | Already in RobotRouter, app uses `/robot` but not `/robot/properties` |
| Keychain credential storage | Storing credentials in Keychain rather than UserDefaults is a security differentiator vs competing apps | MEDIUM | Requires SecItem API — no external deps |

#### Anti-Features (v1.2.0)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| MQTT in-app subscription | Users want push-style updates without polling | MQTT requires a broker, broker requires network config — not all users have one. Valetudo SSE achieves the same goal natively | Use SSE (`/state/attributes/sse`, `/state/map/sse`) — no broker needed |
| Multi-floor map management | Users want to store maps per floor | Valetudo itself does not support multiple maps — only workarounds via SSH. Implementing this in the app creates false expectations | Document as out-of-scope; mention manual MapSnapshot workflow as partial workaround |
| Background robot monitoring (BGAppRefreshTask) | Notifications when app is closed | BGAppRefreshTask is quota-limited by iOS (runs ~every 15 min, not guaranteed). Would require server-push infrastructure (APNS proxy) | Clear messaging in app that notifications require app to be in foreground/recent background |
| WiFi reconfiguration in-app | Users want to move robots between networks | Changing WiFi kicks the robot off the current network, breaking the connection mid-request. Requires careful UI flow to avoid brick | Defer to v2 with explicit warning flow; Valetudo web UI handles this |
| Valetudo updater in-app | Trigger firmware/Valetudo updates from iOS | Update process reboots the robot and WebServer — connection drops, hard to track completion state, risk of partial updates | Link to web UI (`http://<host>/`) for updates; display update availability status only (read-only) |

---

### Feature Dependencies (v1.2.0)

```
SSE real-time updates
    └──replaces──> 5-second polling timer (RobotManager)
    └──requires──> URLSession dataTask with .infinity timeout + EventSource parsing

mDNS discovery
    └──replaces──> NetworkScanner IP brute-force
    └──requires──> NWBrowser (Network.framework) — already available iOS 13+
    └──fallback──> Existing IP scanner (keep for manual entry + networks where mDNS fails)

Notification action handlers
    └──requires──> UNUserNotificationCenterDelegate implementation
    └──requires──> RobotManager accessible from AppDelegate/Scene lifecycle
    └──uses──> Existing LocateCapability + BasicControlCapability (home action)

Valetudo Events display
    └──depends──> GET /api/v2/events/ (new endpoint)
    └──enhances──> Notification system (can cross-reference robot events)
    └──enables──> PUT /api/v2/events/:id/interact (dismiss/acknowledge events)

MapSnapshot capability
    └──requires──> New UI section in RobotSettingsView or MapView toolbar
    └──blocks──> PendingMapChange (accept/reject prompt appears after mapping pass)

PendingMapChange handling
    └──requires──> MapSnapshotCapability awareness (user should snapshot before accepting)
    └──triggered──> After MappingPassCapability run

Error feedback system
    └──required──> All new capability additions (consistent error presentation)
    └──unblocks──> All existing silent-failure paths in RobotDetailView, MapView
```

---

### MVP Definition (v1.2.0)

- [x] Robot row fully tappable
- [x] Notification action handlers
- [x] Error feedback to users
- [x] mDNS/Bonjour discovery
- [x] SSE real-time updates
- [x] MapSnapshot capability
- [x] PendingMapChange handling
- [x] Valetudo Events display
- [x] CleanRouteControl

---

### Verified API Endpoints (v1.2.0)

| Endpoint | Method | Purpose | Status |
|----------|--------|---------|--------|
| `/api/v2/robot/state/attributes/sse` | GET (SSE stream) | Real-time attribute updates | NOT IN APP |
| `/api/v2/robot/state/map/sse` | GET (SSE stream) | Real-time map updates | NOT IN APP |
| `/api/v2/robot/state/sse` | GET (SSE stream) | Full state stream | NOT IN APP |
| `/api/v2/robot/properties` | GET | Static robot metadata | NOT IN APP |
| `/api/v2/robot/capabilities/MapSnapshotCapability` | GET, PUT | Map backup/restore | NOT IN APP |
| `/api/v2/robot/capabilities/PendingMapChangeHandlingCapability` | GET, PUT | Accept/reject new maps | NOT IN APP |
| `/api/v2/robot/capabilities/CleanRouteControlCapability` | GET, PUT | Cleaning route pattern | NOT IN APP |
| `/api/v2/robot/capabilities/ObstacleImagesCapability` | GET, PUT | Enable/disable obstacle photos | NOT IN APP |
| `/api/v2/robot/capabilities/ObstacleImagesCapability/img/:id` | GET | Fetch obstacle photo | NOT IN APP |
| `/api/v2/robot/capabilities/VoicePackManagementCapability` | GET, PUT | Language/voice pack | NOT IN APP |
| `/api/v2/robot/capabilities/AutoEmptyDockAutoEmptyDurationControlCapability` | GET, PUT | Auto-empty cycle duration | NOT IN APP |
| `/api/v2/robot/capabilities/MopDockMopDryingTimeControlCapability` | GET, PUT | Mop drying duration | NOT IN APP |
| `/api/v2/events/` | GET | Robot event log | NOT IN APP |
| `/api/v2/events/:id` | GET | Single event detail | NOT IN APP |
| `/api/v2/events/:id/interact` | PUT | Dismiss/acknowledge event | NOT IN APP |

---

### Sources (v1.2.0)

- Valetudo `RobotRouter.js` — SSE endpoints: https://github.com/Hypfer/Valetudo/blob/master/backend/lib/webserver/RobotRouter.js (HIGH confidence)
- Valetudo `NetworkAdvertisementManager.js` — mDNS service type `"valetudo"`: https://github.com/Hypfer/Valetudo/blob/master/backend/lib/NetworkAdvertisementManager.js (HIGH confidence)
- Valetudo `capabilityRouters/index.js` — complete capability router list: https://github.com/Hypfer/Valetudo/blob/master/backend/lib/webserver/capabilityRouters/index.js (HIGH confidence)
- Valetudo `valetudo_events/events/` — event type files: https://github.com/Hypfer/Valetudo/tree/master/backend/lib/valetudo_events/events (HIGH confidence)
- Valetudo capabilities overview: https://valetudo.cloud/pages/usage/capabilities-overview.html (MEDIUM confidence)
- `ValetudoEventRouter.js` — events API structure: verified via raw GitHub source (HIGH confidence)

---

*Feature research for: ValetudiOS — v2.0.0 update process hardening + v1.2.0 API completeness*
*Last updated: 2026-03-29*
