# External Integrations

**Analysis Date:** 2026-04-04

## APIs & External Services

### Valetudo REST API (Primary Integration)

**Client:** `ValetudoAPI` actor in `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift`

**Base URL:** `{scheme}://{host}/api/v2` where scheme is `http` or `https` based on `RobotConfig.useSSL`

**Authentication:**
- Optional HTTP Basic Auth
- Header: `Authorization: Basic <base64(username:password)>`
- Credentials: username from `RobotConfig`, password from `KeychainStore.password(for: robotId)`
- Applied per-request in both `request<T>()` and `requestVoid()` base methods

**Session Configuration:**
- Standard requests: 10s request timeout, 30s resource timeout
- SSE streams: infinite timeouts on dedicated `URLSession`
- Self-signed cert support: Custom `SSLSessionDelegate` when `config.useSSL && config.ignoreCertificateErrors`

**Endpoints Used (complete list):**

| Method | Endpoint | Swift Method | Purpose |
|--------|----------|-------------|---------|
| GET | `/robot` | `getRobotInfo()` | Robot manufacturer, model, implementation |
| GET | `/robot/capabilities` | `getCapabilities()` | List of supported capabilities (returns `[String]`) |
| GET | `/robot/properties` | `getRobotProperties()` | Firmware version, model, serial number |
| GET | `/robot/state/attributes` | `getAttributes()` | Battery, status, attachments |
| GET | `/robot/state/map` | `getMap()` | Full map with layers and entities |
| GET | `/robot/state/attributes/sse` | `streamStateLines()` | SSE stream for real-time attribute updates |
| GET | `/robot/state/map/sse` | `streamMapLines()` | SSE stream for real-time map updates |
| GET | `/robot/capabilities/MapSegmentationCapability` | `getSegments()` | List rooms/segments |
| PUT | `/robot/capabilities/MapSegmentationCapability` | `cleanSegments(ids:iterations:customOrder:)` | Start segment cleaning with order support |
| PUT | `/robot/capabilities/BasicControlCapability` | `basicControl(action:)` | Start, stop, pause, home |
| PUT | `/robot/capabilities/GoToLocationCapability` | `goTo(x:y:)` | Go to specific coordinates |
| PUT | `/robot/capabilities/LocateCapability` | `locate()` | Play locate sound |
| GET | `/robot/capabilities/ConsumableMonitoringCapability` | `getConsumables()` | Consumable status |
| PUT | `/robot/capabilities/ConsumableMonitoringCapability/{type}[/{subType}]` | `resetConsumable(type:subType:)` | Reset consumable counter |
| GET | `/robot/capabilities/FanSpeedControlCapability/presets` | `getFanSpeedPresets()` | Available fan speed levels |
| PUT | `/robot/capabilities/FanSpeedControlCapability/preset` | `setFanSpeed(preset:)` | Set fan speed |
| GET | `/robot/capabilities/WaterUsageControlCapability/presets` | `getWaterUsagePresets()` | Available water usage levels |
| PUT | `/robot/capabilities/WaterUsageControlCapability/preset` | `setWaterUsage(preset:)` | Set water usage |
| GET | `/robot/capabilities/TotalStatisticsCapability` | `getTotalStatistics()` | Lifetime stats (time, area, count) |
| GET | `/robot/capabilities/CurrentStatisticsCapability` | `getCurrentStatistics()` | Current session stats |
| GET | `/robot/capabilities/DoNotDisturbCapability` | `getDoNotDisturb()` | DND schedule |
| PUT | `/robot/capabilities/DoNotDisturbCapability` | `setDoNotDisturb(config:)` | Set DND schedule |
| GET | `/robot/capabilities/SpeakerVolumeControlCapability` | `getSpeakerVolume()` | Speaker volume |
| PUT | `/robot/capabilities/SpeakerVolumeControlCapability` | `setSpeakerVolume(_:)` | Set speaker volume |
| PUT | `/robot/capabilities/SpeakerTestCapability` | `testSpeaker()` | Play test sound |
| GET | `/robot/capabilities/CarpetModeControlCapability` | `getCarpetMode()` | Carpet mode enabled |
| PUT | `/robot/capabilities/CarpetModeControlCapability` | `setCarpetMode(enabled:)` | Toggle carpet mode |
| GET | `/robot/capabilities/PersistentMapControlCapability` | `getPersistentMap()` | Persistent map enabled |
| PUT | `/robot/capabilities/PersistentMapControlCapability` | `setPersistentMap(enabled:)` | Toggle persistent map |
| PUT | `/robot/capabilities/MappingPassCapability` | `startMappingPass()` | Start mapping run |
| PUT | `/robot/capabilities/MapResetCapability` | `resetMap()` | Reset stored map |
| PUT | `/robot/capabilities/ZoneCleaningCapability` | `cleanZones(_:)` | Clean specific zones |
| GET | `/robot/capabilities/CombinedVirtualRestrictionsCapability` | `getVirtualRestrictions()` | Virtual walls, no-go/no-mop zones |
| PUT | `/robot/capabilities/CombinedVirtualRestrictionsCapability` | `setVirtualRestrictions(_:)` | Set virtual restrictions |
| PUT | `/robot/capabilities/MapSegmentEditCapability` | `joinSegments(...)` / `splitSegment(...)` | Edit map segments |
| PUT | `/robot/capabilities/MapSegmentRenameCapability` | `renameSegment(id:name:)` | Rename a room |
| GET | `/robot/capabilities/OperationModeControlCapability/presets` | `getOperationModePresets()` | Operation modes |
| PUT | `/robot/capabilities/OperationModeControlCapability/preset` | `setOperationMode(preset:)` | Set operation mode |
| GET | `/robot/capabilities/AutoEmptyDockAutoEmptyIntervalControlCapability/presets` | `getAutoEmptyDockIntervalPresets()` | Auto-empty intervals |
| PUT | `/robot/capabilities/AutoEmptyDockAutoEmptyIntervalControlCapability/preset` | `setAutoEmptyDockInterval(preset:)` | Set auto-empty interval |
| GET | `/robot/capabilities/AutoEmptyDockAutoEmptyDurationControlCapability/presets` | `getAutoEmptyDockDurationPresets()` | Auto-empty durations |
| PUT | `/robot/capabilities/AutoEmptyDockAutoEmptyDurationControlCapability/preset` | `setAutoEmptyDockDuration(preset:)` | Set auto-empty duration |
| PUT | `/robot/capabilities/AutoEmptyDockManualTriggerCapability` | `triggerAutoEmptyDock()` | Trigger auto-empty |
| PUT | `/robot/capabilities/MopDockCleanManualTriggerCapability` | `triggerMopDockClean()` | Trigger mop dock clean |
| PUT | `/robot/capabilities/MopDockDryManualTriggerCapability` | `triggerMopDockDry()` | Trigger mop dock dry |
| PUT | `/robot/capabilities/ManualControlCapability` | `manualControl(action:...)` | Remote control movement |
| PUT | `/robot/capabilities/HighResolutionManualControlCapability` | `enableHighResManualControl()`, `disableHighResManualControl()`, `highResManualControl(velocity:angle:)` | High-res RC (S5 Max etc.) |
| GET | `/robot/capabilities/QuirksCapability` | `getQuirks()` | Device-specific quirks |
| PUT | `/robot/capabilities/QuirksCapability` | `setQuirk(id:value:)` | Set quirk value |
| GET | `/robot/capabilities/WifiConfigurationCapability` | `getWifiStatus()` | WiFi connection info |
| GET | `/robot/capabilities/WifiScanCapability` | `scanWifi()` | Scan available networks |
| PUT | `/robot/capabilities/WifiConfigurationCapability` | `setWifiConfig(ssid:password:)` | Configure WiFi |
| GET | `/robot/capabilities/KeyLockCapability` | `getKeyLock()` | Physical button lock state |
| PUT | `/robot/capabilities/KeyLockCapability` | `setKeyLock(enabled:)` | Toggle button lock |
| GET | `/robot/capabilities/ObstacleAvoidanceControlCapability` | `getObstacleAvoidance()` | Obstacle avoidance state |
| PUT | `/robot/capabilities/ObstacleAvoidanceControlCapability` | `setObstacleAvoidance(enabled:)` | Toggle obstacle avoidance |
| GET | `/robot/capabilities/PetObstacleAvoidanceControlCapability` | `getPetObstacleAvoidance()` | Pet avoidance state |
| PUT | `/robot/capabilities/PetObstacleAvoidanceControlCapability` | `setPetObstacleAvoidance(enabled:)` | Toggle pet avoidance |
| GET | `/robot/capabilities/CarpetSensorModeControlCapability` | `getCarpetSensorMode()` | Carpet sensor mode |
| GET | `/robot/capabilities/CarpetSensorModeControlCapability/presets` | `getCarpetSensorModePresets()` | Available carpet sensor modes |
| PUT | `/robot/capabilities/CarpetSensorModeControlCapability` | `setCarpetSensorMode(mode:)` | Set carpet sensor mode |
| GET | `/robot/capabilities/CollisionAvoidantNavigationControlCapability` | `getCollisionAvoidantNavigation()` | Collision avoidance state |
| PUT | `/robot/capabilities/CollisionAvoidantNavigationControlCapability` | `setCollisionAvoidantNavigation(enabled:)` | Toggle collision avoidance |
| GET | `/robot/capabilities/MopDockMopAutoDryingControlCapability` | `getMopDockAutoDrying()` | Auto-drying state |
| PUT | `/robot/capabilities/MopDockMopAutoDryingControlCapability` | `setMopDockAutoDrying(enabled:)` | Toggle auto-drying |
| GET | `/robot/capabilities/MopDockMopWashTemperatureControlCapability/presets` | `getMopDockWashTemperaturePresets()` | Wash temperature options |
| PUT | `/robot/capabilities/MopDockMopWashTemperatureControlCapability/preset` | `setMopDockWashTemperature(preset:)` | Set wash temperature |
| GET | `/robot/capabilities/MopDockMopDryingTimeControlCapability/presets` | `getMopDockDryingTimePresets()` | Drying time options |
| PUT | `/robot/capabilities/MopDockMopDryingTimeControlCapability/preset` | `setMopDockDryingTime(preset:)` | Set drying time |
| GET | `/robot/capabilities/MapSegmentMaterialControlCapability/properties` | `getSegmentMaterialProperties()` | Supported floor materials |
| PUT | `/robot/capabilities/MapSegmentMaterialControlCapability` | `setSegmentMaterial(segmentId:material:)` | Set room floor material |
| GET | `/robot/capabilities/FloorMaterialDirectionAwareNavigationControlCapability` | `getFloorMaterialNavigation()` | Floor-aware navigation state |
| PUT | `/robot/capabilities/FloorMaterialDirectionAwareNavigationControlCapability` | `setFloorMaterialNavigation(enabled:)` | Toggle floor-aware navigation |
| GET | `/robot/capabilities/MapSnapshotCapability` | `getMapSnapshots()` | Saved map snapshots |
| PUT | `/robot/capabilities/MapSnapshotCapability` | `restoreMapSnapshot(id:)` | Restore map snapshot |
| GET | `/robot/capabilities/PendingMapChangeHandlingCapability` | `getPendingMapChange()` | Pending map change state |
| PUT | `/robot/capabilities/PendingMapChangeHandlingCapability` | `handlePendingMapChange(action:)` | Accept/reject map change |
| GET | `/robot/capabilities/CleanRouteControlCapability` | `getCleanRoute()` | Clean route state |
| PUT | `/robot/capabilities/CleanRouteControlCapability` | `setCleanRoute(route:)` | Set clean route |
| GET | `/robot/capabilities/CleanRouteControlCapability/presets` | `getCleanRoutePresets()` | Available routes |
| GET | `/robot/capabilities/ObstacleImagesCapability/img/{id}` | `getObstacleImage(id:)` | Download obstacle photo (raw bytes) |
| GET | `/robot/capabilities/VoicePackManagementCapability` | `getVoicePackState()` | Voice pack info |
| PUT | `/robot/capabilities/VoicePackManagementCapability` | `setVoicePack(id:)` | Download voice pack |
| GET | `/valetudo/config/interfaces/mqtt` | `getMQTTConfig()` | MQTT configuration |
| PUT | `/valetudo/config/interfaces/mqtt` | `setMQTTConfig(_:)` | Update MQTT config |
| GET | `/valetudo/version` | `getValetudoVersion()` | Valetudo release and commit |
| GET | `/valetudo/events` | `getEvents()` | Event log (dict or array) |
| PUT | `/valetudo/events/{id}` | `dismissEvent(id:)` | Dismiss event |
| GET | `/ntpclient/config` | `getNTPConfig()` | NTP configuration |
| PUT | `/ntpclient/config` | `setNTPConfig(_:)` | Update NTP config |
| GET | `/ntpclient/status` | `getNTPStatus()` | NTP sync status |
| GET | `/system/host/info` | `getSystemHostInfo()` | Hostname, arch, memory, uptime, load |
| GET | `/updater/state` | `getUpdaterState()` | OTA update state |
| PUT | `/updater` | `checkForUpdates()`, `downloadUpdate()`, `applyUpdate()` | OTA update actions |
| GET | `/timers` | `getTimers()` | Scheduled timers (returns dict `{id: timer}`) |
| POST | `/timers` | `createTimer(_:)` | Create timer |
| PUT | `/timers/{id}` | `updateTimer(_:)` | Update timer |
| DELETE | `/timers/{id}` | `deleteTimer(id:)` | Delete timer |

### Valetudo SSE Streaming

**Manager:** `SSEConnectionManager` actor in `ValetudoApp/ValetudoApp/Services/SSEConnectionManager.swift`

**Endpoints:**
- `/api/v2/robot/state/attributes/sse` - Real-time attribute updates (battery, status, attachments)
- `/api/v2/robot/state/map/sse` - Real-time map updates

**Protocol:**
- Standard Server-Sent Events (SSE) over HTTP/HTTPS
- Data format: `data:` prefix followed by JSON array of `RobotAttribute` objects
- Uses `URLSession.AsyncBytes.lines` for streaming

**Connection Management:**
- Per-robot `Task` tracking via `tasks: [UUID: Task]`
- Connection state: `isConnected: [UUID: Bool]`
- Exponential backoff on failure: 1s -> 5s -> 30s (capped)
- Automatic reconnection on connection loss
- Cancellation-safe with proper cleanup

**Fallback:**
- `RobotManager` polls via REST every 5 seconds for robots without active SSE

### GitHub API

**Purpose:** Check for latest Valetudo release version
**Endpoint:** `https://api.github.com/repos/Hypfer/Valetudo/releases/latest`
**Client:** Direct `URLSession.shared` call in `ValetudoApp/ValetudoApp/Services/UpdateService.swift`
**Model:** `GitHubRelease` struct (tag_name, html_url, published_at, body)
**Auth:** None (public API)
**URL constant:** `ValetudoApp/ValetudoApp/Utilities/Constants.swift` -> `Constants.githubApiLatestReleaseUrl`

## Data Models for API Communication

**Request Models (in `ValetudoApp/ValetudoApp/Models/RobotState.swift`):**
- `BasicControlRequest` - `{action: "start"|"stop"|"pause"|"home"}`
- `SegmentCleanRequest` - `{action: "start_segment_action", segment_ids: [...], iterations: N, customOrder: bool?}`
- `GoToRequest` - `{action: "goto", coordinates: {x, y}}`
- `PresetControlRequest` - `{name: "preset_name"}`
- `ActionRequest` - `{action: "action_name"}` (generic for toggle/trigger)
- `ModeRequest` / `ModeResponse` - `{mode: "mode_name"}`
- `SegmentRenameRequest` - `{action: "rename_segment", segment_id, name}`
- `SpeakerVolumeRequest` - `{action: "set_volume", value: N}`
- `ManualControlRequest` - `{action, movement_speed?, angle?, duration?}`
- `HighResManualControlRequest` - `{action, vector: {velocity, angle}}`
- `QuirkSetRequest` - `{id, value}`
- `WifiConfigRequest` - `{ssid, credentials: {type: "wpa2_psk", typeSpecificSettings: {password}}}`
- `ZoneCleanRequest` - `{action: "clean", zones: [{points, iterations}]}`
- `VirtualRestrictionsRequest` - `{virtualWalls: [{points}], restrictedZones: [{points, type}]}`
- `JoinSegmentsRequest` - `{action: "join_segments", segment_a_id, segment_b_id}`
- `SplitSegmentRequest` - `{action: "split_segment", segment_id, pA, pB}`
- `SegmentMaterialRequest` - `{action: "set_material", segment_id, material}`

**Response Models:**
- `RobotInfo` - `{manufacturer?, modelName?, implementation?}` (`ValetudoApp/ValetudoApp/Models/RobotState.swift`)
- `RobotProperties` - `{firmwareVersion?, model?, manufacturer?, metaData?}` (`ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift`)
- `RobotAttribute` - `{__class, type?, subType?, value?, level?, flag?}` (`ValetudoApp/ValetudoApp/Models/RobotState.swift`)
- `RobotMap` - `{size?, pixelSize?, layers?, entities?}` (`ValetudoApp/ValetudoApp/Models/RobotMap.swift`)
- `MapLayer` - `{__class?, type?, pixels?, compressedPixels?, metaData?, dimensions?}` with RLE decompression
- `MapEntity` - `{__class?, type?, points?, metaData?}` for robot position, charger, paths, obstacles
- `Segment` - `{id, name?}` for rooms
- `Consumable` - in `ValetudoApp/ValetudoApp/Models/Consumable.swift`
- `ValetudoTimer` - in `ValetudoApp/ValetudoApp/Models/Timer.swift`
- `EnabledResponse` - `{enabled: bool|int}` (handles both Bool and Int from API)
- `Capabilities` = `[String]` (typealias for array of capability identifiers)
- `MQTTConfig` - Full MQTT configuration model with nested connection, identity, interfaces, customizations
- `NTPConfig` / `NTPStatus` - NTP client configuration and sync status
- `UpdaterState` - OTA update state with `__class` discriminator
- `ValetudoEvent` - Event log entries with `__class` discriminator
- `VoicePackState` - Current and supported voice packs

## Data Storage

**Robot Configuration:**
- UserDefaults key: `valetudo_robots`
- Format: JSON array of `RobotConfig`
- Managed by: `ValetudoApp/ValetudoApp/Services/RobotManager.swift`

**Credentials:**
- iOS Keychain via `ValetudoApp/ValetudoApp/Services/KeychainStore.swift`
- Service: `com.valetudio.robot.password`
- Account: Robot UUID string
- Accessibility: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- Migration: Passwords previously in UserDefaults JSON are auto-migrated to Keychain on load

**Map Cache:**
- Documents directory: `MapCache/<robotUUID>.json`
- Managed by: `ValetudoApp/ValetudoApp/Services/MapCacheService.swift`
- Persists last known map for instant display on app launch

**Background State:**
- UserDefaults key: `bg_last_status_<robotUUID>` - Last known robot status for background monitoring
- Managed by: `ValetudoApp/ValetudoApp/Services/BackgroundMonitorService.swift`

**GoTo Presets:**
- UserDefaults key: `goToPresets`
- Format: JSON array of `GoToPreset` (name, x, y, robotId)
- Managed by: `GoToPresetStore` in `ValetudoApp/ValetudoApp/Models/RobotState.swift`

## Authentication & Identity

**Auth Provider:** Custom - HTTP Basic Auth (optional per robot)
- Implementation: Per-request header injection in `ValetudoAPI.request()` and `requestVoid()`
- No OAuth, no tokens, no external identity providers
- All auth is direct robot-to-app on local network

## Network Discovery

**mDNS/Bonjour Discovery:**
- Service type: `_valetudo._tcp` on `.local` domain
- Client: `NWBrowser` in `ValetudoApp/ValetudoApp/Services/NWBrowserService.swift`
- TXT record fields: `friendlyName`, `model`
- Result: `DiscoveredRobot` struct with `host` resolved as `<name>.local`

**IP Subnet Scanning (fallback):**
- Client: `ValetudoApp/ValetudoApp/Services/NetworkScanner.swift`
- Scans `en0`/`en1` subnet (254 hosts) with 20-host concurrency batches
- Probes each host at `http://{ip}/api/v2/robot` with 1.5s timeout
- mDNS results merged with preference over IP scan results

**Discovery Flow:**
1. mDNS browsing starts immediately
2. Wait 3 seconds for mDNS results
3. IP scan runs in parallel as supplement
4. Results merged, mDNS entries preferred for metadata

## Notifications (Local Only)

**Service:** `ValetudoApp/ValetudoApp/Services/NotificationService.swift`
**Triggers:**
- Cleaning complete (status changed from `cleaning` to `docked`/`idle`)
- Robot stuck (`StatusStateAttribute.flag == "stuck"`)
- Robot error (status changed to `error`)
- Robot offline (API call fails after previously being online)
- Consumable low (below 15% remaining, checked max once per hour)

**User Preferences (toggleable):**
- `notify_cleaning_complete`, `notify_robot_error`, `notify_robot_stuck`, `notify_consumable_low`, `notify_robot_offline`

## Background Monitoring

**Service:** `ValetudoApp/ValetudoApp/Services/BackgroundMonitorService.swift`
**Task ID:** `de.simonluthe.ValetudiOS.backgroundRefresh`
**Schedule:** Every 15 minutes via `BGAppRefreshTaskRequest`
**Behavior:** Creates fresh `ValetudoAPI` instances, checks attributes, compares with persisted status, sends notifications on state changes

## In-App Purchases

**Provider:** Apple App Store (StoreKit 2)
**Products:** Three consumable tip amounts
- `de.godsapp.valetudoapp.support.small`
- `de.godsapp.valetudoapp.support.medium`
- `de.godsapp.valetudoapp.support.large`
**Client:** `ValetudoApp/ValetudoApp/Services/SupportManager.swift`
**UI:** `ValetudoApp/ValetudoApp/Views/SupportView.swift`, `ValetudoApp/ValetudoApp/Views/SupportReminderView.swift`

## Siri Shortcuts

**Framework:** AppIntents (`ValetudoApp/ValetudoApp/Intents/RobotIntents.swift`)
**Entities:**
- `RobotEntity` - Represents a robot for Siri queries
- `RoomEntity` - Represents a room/segment for Siri queries
**Queries:** Load robots/rooms from UserDefaults for Siri suggestions

## Logging

**Framework:** `os.Logger`
**Subsystem:** `Bundle.main.bundleIdentifier` (falls back to `"com.valetudio"`)
**Categories:**
- `API` - REST API calls (`ValetudoAPI`)
- `SSE` - SSE connection lifecycle (`SSEConnectionManager`)
- `mDNS` - Bonjour discovery (`NWBrowserService`)
- `Notifications` - Notification delivery (`NotificationService`)
- `RobotManager` - Robot state management
- `NetworkScanner` - IP subnet scanning
- `MapCacheService` - Map persistence
- `BackgroundMonitor` - Background task execution
- `UpdateService` - OTA update flow
- `SupportManager` - StoreKit transactions
- `KeychainStore` - Credential operations

## Third-Party Dependencies

**None.** The project uses exclusively Apple first-party frameworks. No CocoaPods, SPM, or other package managers are configured.

---

*Integration audit: 2026-04-04*
