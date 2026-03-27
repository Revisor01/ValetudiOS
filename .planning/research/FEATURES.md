# Feature Research

**Domain:** iOS native app — Valetudo robot vacuum controller (v1.2.0 milestone)
**Researched:** 2026-03-27
**Confidence:** HIGH (API endpoints verified against Valetudo source at github.com/Hypfer/Valetudo)

---

## Context: What Already Exists

The app already implements the following API endpoints (not in scope for v1.2.0):
BasicControlCapability, GoToLocationCapability, ManualControlCapability, HighResolutionManualControlCapability, ZoneCleaningCapability, MapSegmentationCapability, CombinedVirtualRestrictionsCapability, MapSegmentEditCapability, MapSegmentRenameCapability, MapSegmentMaterialControlCapability, FloorMaterialDirectionAwareNavigationControlCapability, MappingPassCapability, MapResetCapability, FanSpeedControlCapability, WaterUsageControlCapability, OperationModeControlCapability, ConsumableMonitoringCapability, CurrentStatisticsCapability, TotalStatisticsCapability, DoNotDisturbCapability, SpeakerVolumeControlCapability, SpeakerTestCapability, CarpetModeControlCapability, PersistentMapControlCapability, LocateCapability, AutoEmptyDockAutoEmptyIntervalControlCapability, AutoEmptyDockManualTriggerCapability, MopDockCleanManualTriggerCapability, MopDockDryManualTriggerCapability, MopDockMopWashTemperatureControlCapability, MopDockMopAutoDryingControlCapability, KeyLockCapability, ObstacleAvoidanceControlCapability, PetObstacleAvoidanceControlCapability, CarpetSensorModeControlCapability, CollisionAvoidantNavigationControlCapability, QuirksCapability, WifiConfigurationCapability, WifiScanCapability, Timers (full CRUD).

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features whose absence makes the app feel broken or incomplete for v1.2.0 goals.

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

### Differentiators (Competitive Advantage)

Features that go beyond what the Valetudo web UI offers or that competing apps don't have.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| ObstacleImages browsing | Show photos of detected obstacles (pet waste, cables, shoes) from last cleaning run — unique to AI-equipped robots (Roborock S8 Pro Ultra etc.) | MEDIUM | `/robot/capabilities/ObstacleImagesCapability` — GET `/img/:id` returns JPEG/PNG stream. Rate-limited 3/sec on server side. |
| VoicePackManagement | Download custom voice packs by URL/language — useful for non-English users. Valetudo web UI has this but iOS native UX is better | MEDIUM | GET current language + operation status, PUT with download URL |
| AutoEmptyDock duration control | Fine-tune how long the auto-empty cycle runs — separate from interval | LOW | `AutoEmptyDockAutoEmptyDurationControlCapability` — GET/PUT duration |
| MopDock drying time control | Control how long the mop drying cycle runs | LOW | `MopDockMopDryingTimeControlCapabilityRouter` — GET/PUT duration |
| Robot properties endpoint | `/api/v2/robot/properties` returns static robot metadata not currently consumed — useful for displaying model details, quirk info | LOW | Already in RobotRouter, app uses `/robot` but not `/robot/properties` |
| Keychain credential storage | Storing credentials in Keychain rather than UserDefaults is a security differentiator vs competing apps | MEDIUM | Requires SecItem API — no external deps |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| MQTT in-app subscription | Users want push-style updates without polling | MQTT requires a broker, broker requires network config — not all users have one. Valetudo SSE achieves the same goal natively | Use SSE (`/state/attributes/sse`, `/state/map/sse`) — no broker needed |
| Multi-floor map management | Users want to store maps per floor | Valetudo itself does not support multiple maps — only workarounds via SSH. Implementing this in the app creates false expectations | Document as out-of-scope; mention manual MapSnapshot workflow as partial workaround |
| Background robot monitoring (BGAppRefreshTask) | Notifications when app is closed | BGAppRefreshTask is quota-limited by iOS (runs ~every 15 min, not guaranteed). Would require server-push infrastructure (APNS proxy) | Clear messaging in app that notifications require app to be in foreground/recent background |
| WiFi reconfiguration in-app | Users want to move robots between networks | Changing WiFi kicks the robot off the current network, breaking the connection mid-request. Requires careful UI flow to avoid brick | Defer to v2 with explicit warning flow; Valetudo web UI handles this |
| Valetudo updater in-app | Trigger firmware/Valetudo updates from iOS | Update process reboots the robot and WebServer — connection drops, hard to track completion state, risk of partial updates | Link to web UI (`http://<host>/`) for updates; display update availability status only (read-only) |

---

## Feature Dependencies

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

## MVP Definition for v1.2.0

### Must Ship (Core of this Milestone)

- [x] **Robot row fully tappable** — 1-line SwiftUI layout fix, high visibility bug
- [x] **Notification action handlers** — defined but broken; low effort, high trust impact
- [x] **Error feedback to users** — replaces 80+ silent `print()` calls; foundational for all other work
- [x] **mDNS/Bonjour discovery** — replaces brute-force scanner; correct use of platform APIs
- [x] **SSE real-time updates** — replaces polling; Valetudo provides 3 SSE streams natively
- [x] **MapSnapshot capability** — standard Valetudo feature, missing from app
- [x] **PendingMapChange handling** — robots can be stuck without this
- [x] **Valetudo Events display** — `/api/v2/events/` endpoint not consumed at all
- [x] **CleanRouteControl** — simple GET/PUT toggle, low effort

### Add After Validation (v1.2.x)

- [ ] **ObstacleImages browsing** — hardware-dependent (AI cameras), add once core is stable
- [ ] **VoicePackManagement** — niche use case, not blocking
- [ ] **AutoEmptyDock duration** — minor dock refinement
- [ ] **MopDock drying time** — minor dock refinement
- [ ] **Keychain credential storage** — important security fix, can ship as patch after core milestone

### Future Consideration (v2+)

- [ ] **Robot properties endpoint display** — informational only, low user value
- [ ] **Background monitoring via BGAppRefreshTask** — requires significant architecture change, limited iOS reliability
- [ ] **WiFi reconfiguration UI** — high risk, needs careful design

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Robot row tappable | HIGH | LOW | P1 |
| Notification action handlers | HIGH | LOW | P1 |
| Error feedback system | HIGH | MEDIUM | P1 |
| mDNS discovery | HIGH | MEDIUM | P1 |
| SSE real-time updates | HIGH | MEDIUM | P1 |
| Valetudo Events display | HIGH | MEDIUM | P1 |
| MapSnapshot capability | MEDIUM | MEDIUM | P1 |
| PendingMapChange handling | MEDIUM | LOW | P1 |
| CleanRouteControl | MEDIUM | LOW | P1 |
| ObstacleImages browsing | MEDIUM | MEDIUM | P2 |
| Keychain credentials | HIGH | MEDIUM | P2 |
| VoicePackManagement | LOW | MEDIUM | P2 |
| AutoEmptyDock duration | LOW | LOW | P2 |
| MopDock drying time | LOW | LOW | P2 |
| Robot properties display | LOW | LOW | P3 |
| Background monitoring | MEDIUM | HIGH | P3 |
| WiFi reconfiguration UI | LOW | HIGH | P3 |

---

## Verified API Endpoints (New for v1.2.0)

Verified against `github.com/Hypfer/Valetudo` master branch source (2026-03-27):

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

**Valetudo event types** (from `backend/lib/valetudo_events/events/`):
- `ConsumableDepletedValetudoEvent` — consumable at 0%
- `DustBinFullValetudoEvent` — auto-empty dock bin full
- `ErrorStateValetudoEvent` — robot error
- `MissingResourceValetudoEvent` — resource not found (water, mop attachment)
- `MopAttachmentReminderValetudoEvent` — reminder to attach/remove mop
- `PendingMapChangeValetudoEvent` — new map awaiting acceptance
- `DismissibleValetudoEvent` — base type for dismissible events

**mDNS service discovery:**
- Service type: `_valetudo._tcp` (Bonjour type `"valetudo"`)
- Also advertises `_http._tcp` as `"Valetudo [ID] Web"`
- TXT records contain: model, manufacturer, version, systemId, friendlyName
- iOS implementation: `NWBrowser` with `NWBrowser.Descriptor.bonjourWithTXTRecord(type: "_valetudo._tcp", domain: "local")`

---

## Competitor Feature Analysis

| Feature | Valetudo Web UI | ioBroker/HA Integration | ValetudiOS Approach |
|---------|-----------------|------------------------|---------------------|
| SSE updates | Yes (built-in) | Via MQTT | Replace polling with SSE |
| mDNS discovery | Not needed (browser) | Not applicable | NWBrowser — instant vs 254-IP scan |
| Obstacle images | Full gallery view | Not common | Inline in cleaning history |
| Events display | Persistent notification bar | Via MQTT topics | In-app event log with dismiss |
| Error feedback | Toast notifications | Via automations | SwiftUI `.alert` with retry |

---

## Sources

- Valetudo `RobotRouter.js` — SSE endpoints: https://github.com/Hypfer/Valetudo/blob/master/backend/lib/webserver/RobotRouter.js (verified via raw.githubusercontent.com, HIGH confidence)
- Valetudo `NetworkAdvertisementManager.js` — mDNS service type `"valetudo"`: https://github.com/Hypfer/Valetudo/blob/master/backend/lib/NetworkAdvertisementManager.js (HIGH confidence)
- Valetudo `capabilityRouters/index.js` — complete capability router list: https://github.com/Hypfer/Valetudo/blob/master/backend/lib/webserver/capabilityRouters/index.js (HIGH confidence)
- Valetudo `valetudo_events/events/` — event type files: https://github.com/Hypfer/Valetudo/tree/master/backend/lib/valetudo_events/events (HIGH confidence)
- Valetudo capabilities overview: https://valetudo.cloud/pages/usage/capabilities-overview.html (MEDIUM — rendered summary, not source)
- `ValetudoEventRouter.js` — events API structure: verified via raw GitHub source (HIGH confidence)

---

*Feature research for: ValetudiOS v1.2.0 — Valetudo API completeness + UX improvements*
*Researched: 2026-03-27*
