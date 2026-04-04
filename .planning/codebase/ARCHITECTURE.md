# Architecture

**Analysis Date:** 2026-04-04

## Pattern Overview

**Overall:** MVVM (Model-View-ViewModel) with Swift Observation framework and actor-based concurrency

**Key Characteristics:**
- SwiftUI with `@Observable` macro (Swift Observation framework, not legacy `ObservableObject`)
- `@MainActor` annotation on all ViewModels and managers for thread safety
- Three primary ViewModels managing distinct domains (Map, RobotDetail, RobotSettings)
- Actor-based network layer (`ValetudoAPI`) for thread-safe concurrent requests
- Server-Sent Events (SSE) streaming for real-time robot state updates with auto-reconnect
- Environment-based dependency injection (`@Environment(RobotManager.self)`)
- Keychain-backed credential storage for robot authentication
- Ordered arrays (`[String]`) for room selection to support cleaning order

## Layers

**Presentation (Views):**
- Purpose: SwiftUI views rendering UI state from ViewModels
- Location: `ValetudoApp/ValetudoApp/Views/`
- Contains: 20 view files organized by feature; large views split into companion files (e.g., `RobotDetailView.swift` + `RobotDetailSections.swift`)
- Depends on: ViewModels, Models
- Used by: SwiftUI scene graph, environment propagation
- Map views further split: `MapView.swift` (main content + coordinate transforms), `MapInteractiveView.swift` (Canvas rendering), `MapControlBarsView.swift` (bottom toolbar), `MapSheetsView.swift` (modal sheets), `MapMiniMapView.swift` (preview)

**ViewModels:**
- Purpose: State management, user interaction handling, API orchestration
- Location: `ValetudoApp/ValetudoApp/ViewModels/`
- Contains: `MapViewModel`, `RobotDetailViewModel`, `RobotSettingsViewModel`
- Depends on: RobotManager, ValetudoAPI, Models
- Used by: Views via `@State private var viewModel` initialization
- Pattern: `@MainActor @Observable final class` with direct property access (no `@Published` needed)
- All ViewModels receive `robot: RobotConfig` and `robotManager: RobotManager` in init

**Services & Managers:**
- Purpose: Stateful service orchestration and cross-cutting concerns
- Location: `ValetudoApp/ValetudoApp/Services/`
- Contains:
  - `RobotManager` (`@MainActor @Observable class`): Central state holder for all robots, manages API instances, periodic refresh, SSE lifecycle
  - `ValetudoAPI` (`actor`): Thread-safe network client for Valetudo REST API v2
  - `SSEConnectionManager` (`actor`): Per-robot SSE connections with exponential backoff reconnect
  - `NotificationService` (`@MainActor @Observable` singleton): Push notification scheduling and action handling
  - `BackgroundMonitorService` (singleton): BGAppRefreshTask for background robot polling every 15 minutes
  - `MapCacheService` (singleton): Disk-based map JSON cache for offline display
  - `UpdateService` (`@MainActor @Observable`): OTA update lifecycle (check/download/apply/reboot)
  - `NetworkScanner` / `NWBrowserService`: Device discovery via Bonjour mDNS
  - `KeychainStore` (struct): Secure credential persistence
  - `SupportManager` (`@MainActor @Observable` singleton): StoreKit donation/support tracking

**Models:**
- Purpose: Data structures for API responses, internal state, and UI representation
- Location: `ValetudoApp/ValetudoApp/Models/`
- Contains:
  - `RobotConfig`: Robot connection metadata (host, auth, SSL settings) with custom Codable for backward compat
  - `RobotState.swift`: `RobotAttribute`, `RobotInfo`, `Segment`, `BasicAction`, request/response structs (~877 lines, largest model file)
  - `RobotMap.swift`: Map layers with run-length decompression cache (`MapLayerCache` reference type), entities, zones, virtual restrictions
  - `Timer.swift`: Timer scheduling model (`ValetudoTimer`, `CreateTimerRequest`)
  - `Consumable.swift`: Consumable wear tracking with computed `remainingPercent`
- Depends on: None (pure data structures)
- Used by: Services, ViewModels, Views

**Helpers & Utilities:**
- Purpose: Cross-cutting utilities and shared UI logic
- Location: `ValetudoApp/ValetudoApp/Helpers/` and `ValetudoApp/ValetudoApp/Utilities/`
- Contains:
  - `ErrorRouter.swift`: Centralized error alert with optional retry action, injected via `@Environment(ErrorRouter.self)`
  - `DebugConfig.swift`: Single flag `showAllCapabilities` to show all UI sections during development
  - `PresetHelpers.swift`: Display name and color mapping for preset strings (fan speed, water usage, operation mode)
  - `Constants.swift`: GitHub API URLs, StoreKit product IDs, external links

**Intents:**
- Purpose: Siri Shortcuts and AppIntents integration
- Location: `ValetudoApp/ValetudoApp/Intents/`
- Contains: `RobotEntity`, `RoomEntity`, `EntityQuery` implementations, `StartCleaningIntent`, `StopCleaningIntent`, etc.
- Access: Reads `RobotConfig` from UserDefaults independently (not tied to live RobotManager)

## Data Flow

**App Initialization:**
1. `AppDelegate.didFinishLaunchingWithOptions` registers BGTask handler and sets up `UNUserNotificationCenter`
2. `ValetudoApp.body` creates `@State private var robotManager = RobotManager()`
3. `RobotManager.init()` loads robots from UserDefaults, creates `ValetudoAPI` per robot, starts 5-second refresh loop
4. `robotManager` injected into views via `.environment(robotManager)`
5. `ErrorRouter` created as second `@State` and injected similarly
6. `NotificationService.robotManagerRef` set in `.onAppear` for notification action routing

**Real-Time Updates (SSE):**
1. `RobotManager.startRefreshing()` loop checks each robot for active SSE
2. If not active, calls `sseManager.connect(robotId:api:onAttributesUpdate:onConnectionChange:)`
3. `SSEConnectionManager` spawns Task calling `streamWithReconnect`
4. Task reads `api.streamStateLines()` -> `/api/v2/robot/state/attributes/sse`
5. Each `data:` line parsed as `[RobotAttribute]` JSON
6. `onAttributesUpdate` callback fires on MainActor -> `RobotManager.applyAttributeUpdate()`
7. `RobotManager.robotStates[id]` updated -> Views re-render via Observation
8. Connection dropout -> SSE marked inactive -> next refresh loop iteration polls and reconnects

**Map Refresh Flow:**
1. `MapContentView.task` calls `viewModel.loadMap()` then `viewModel.startMapRefresh()`
2. `loadMap()`: fetches capabilities, virtual restrictions, map data, segments in sequence
3. `startMapRefresh()`: 2-second polling loop fetching `api.getMap()`
4. On failure: loads cached map from `MapCacheService`, sets `isOffline = true`
5. On success: updates `map` property, saves to cache, clears offline flag

**Room Selection & Cleaning (v2.2.0 pattern):**
1. User taps room on map -> `SpatialTapGesture` in `InteractiveMapView` triggers
2. `selectedSegmentIds: [String]` (ordered array, not Set) is toggled via `toggleSegment()`
3. Order of taps determines cleaning order (first tapped = cleaned first)
4. Bottom bar shows selected rooms with numbered badges indicating order
5. "Start" sends `api.cleanSegments(ids: selectedSegmentIds, customOrder: true)` preserving order

**State Management:**
- `RobotManager` holds authoritative state: `robots: [RobotConfig]`, `robotStates: [UUID: RobotStatus]`, `robotUpdateAvailable: [UUID: Bool]`
- ViewModels access state via computed properties: `var status: RobotStatus? { robotManager.robotStates[robot.id] }`
- ViewModels maintain local state for UI-specific concerns (editMode, drawing state, loading flags)
- Two-way sync: ViewModel reads `robotManager.robotStates`, writes via API calls that trigger `robotManager.refreshRobot()`
- Persistence: `RobotConfig` array in UserDefaults; passwords in Keychain; map cache in Documents/MapCache/

## Key Abstractions

**ValetudoAPI (actor):**
- Purpose: All network communication to Valetudo REST API v2
- Location: `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift` (815 lines)
- Pattern: One actor instance per `RobotConfig`, held in `RobotManager.apis[UUID]`
- Core methods: `request<T>()` (generic GET/PUT/POST), `requestVoid()` (no response body), `streamStateLines()` / `streamMapLines()` (SSE)
- Thread safety: Actor isolation ensures serial execution of all network operations per robot
- SSL: Optional self-signed certificate bypass via `SSLSessionDelegate` inner class
- Auth: HTTP Basic Auth header built from `config.username` + `KeychainStore.password(for: config.id)`

**SSEConnectionManager (actor):**
- Purpose: Lifecycle management for SSE streaming connections
- Location: `ValetudoApp/ValetudoApp/Services/SSEConnectionManager.swift`
- Pattern: Single instance in `RobotManager`, manages per-robot Tasks
- Thread safety: Actor serializes `connect`/`disconnect`/`isSSEActive` queries
- Reconnection: Automatic with backoff, cancellation-safe cleanup

**RobotManager (@MainActor @Observable):**
- Purpose: Single source of truth for robot configuration and runtime state
- Location: `ValetudoApp/ValetudoApp/Services/RobotManager.swift` (359 lines)
- State: `robots` (config array), `robotStates` (status dict), `robotUpdateAvailable` (update flags)
- Lifecycle: Loads from UserDefaults on init, re-saves on add/update/remove
- Refresh: 5-second polling loop; SSE-connected robots skip polling
- Password migration: Automatic migration from legacy UserDefaults JSON to Keychain on load
- Dependency injection: Passed to all views/ViewModels via `@Environment(RobotManager.self)`

**MapViewModel (@MainActor @Observable):**
- Purpose: Map rendering state, edit modes, room selection, restrictions, go-to presets
- Location: `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift` (500 lines)
- Edit modes: `MapEditMode` enum (none, zone, noGoArea, noMopArea, virtualWall, goTo, savePreset, roomEdit, splitRoom, deleteRestriction)
- Room selection: `selectedSegmentIds: [String]` as ordered array for cleaning order support
- Drawing state: `drawnZones`, `drawnNoGoAreas`, `drawnNoMopAreas`, `drawnVirtualWalls` arrays
- Preset store: `GoToPresetStore` for named go-to locations

**RobotDetailViewModel (@MainActor @Observable):**
- Purpose: Robot control actions, segment cleaning, consumables, events, statistics, update management
- Location: `ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift` (476 lines)
- Room selection: `selectedSegments: [String]` (ordered array for cleaning order)
- Update service: Holds optional `UpdateService` instance as single source of truth (STATE-04 pattern)
- Capability flags: Boolean properties gated by `DebugConfig.showAllCapabilities || capabilities.contains(...)`
- Live stats: Optional 5-second polling task for active cleaning statistics

**RobotSettingsViewModel (@MainActor @Observable):**
- Purpose: Robot-specific toggles, presets, map management
- Location: `ValetudoApp/ValetudoApp/ViewModels/RobotSettingsViewModel.swift` (543 lines)
- Pattern: Loads all settings in `loadSettings()` with individual do/catch per capability
- `isInitialLoad` flag prevents onChange handlers from firing during load

**ErrorRouter (@MainActor @Observable):**
- Purpose: Centralized error alert with optional retry
- Location: `ValetudoApp/ValetudoApp/Helpers/ErrorRouter.swift`
- Usage: `errorRouter.show(error, retry: { await action() })`; `.withErrorAlert(router:)` modifier on root views

## Entry Points

**App Entry:**
- Location: `ValetudoApp/ValetudoApp/ValetudoApp.swift`
- Triggers: System app launch
- Responsibilities: Register BGTask handler, instantiate RobotManager and ErrorRouter, show onboarding or main ContentView

**Tab Navigation:**
- Location: `ValetudoApp/ValetudoApp/ContentView.swift`
- Structure: `TabView` with 3 tabs:
  - Tab 0 (Robots): `NavigationStack` > `RobotListView` > `RobotDetailView`
  - Tab 1 (Map): `MapTabView` - only visible when a robot is selected via `selectedRobotId`
  - Tab 2 (Settings): `SettingsView`
- Robot selection: `selectedRobotId: UUID?` binding shared between `RobotListView` and Map tab

**Navigation (Robot Detail):**
- Location: `ValetudoApp/ValetudoApp/Views/RobotListView.swift`
- Pattern: `.navigationDestination(item: $navigateToRobot)` pushes `RobotDetailView`
- `RobotDetailView` contains inline map preview, control buttons, and NavigationLinks to sub-pages:
  - `RobotSettingsView` (robot-specific settings, Device Info as sub-page)
  - `ConsumablesView`, `TimersView`, `StatisticsView`, `ManualControlView`, `RoomsManagementView`

**Notification Response:**
- Location: `ValetudoApp/ValetudoApp/ValetudoApp.swift` AppDelegate
- Triggers: User taps notification action
- Flow: `AppDelegate.userNotificationCenter(didReceive:)` -> `NotificationService.handleNotificationResponse(actionIdentifier:)` -> dispatches robot action via `robotManagerRef`

**Background Refresh:**
- Location: `ValetudoApp/ValetudoApp/Services/BackgroundMonitorService.swift`
- Triggers: iOS BGTaskScheduler every ~15 minutes
- Responsibilities: Check all robots, send notifications for state changes

## Error Handling

**Strategy:** Per-call try/catch with silent degradation for non-critical features

**Patterns:**
- Network errors (`APIError` enum): `invalidURL`, `networkError`, `invalidResponse`, `httpError(Int)`, `decodingError`
- ViewModel pattern: Each API call wrapped in do/catch; errors logged via `os.Logger`; non-critical failures silently ignored
- ErrorRouter: Available but used sparingly; most errors are logged and silently degraded (e.g., capability not supported -> hide UI section)
- Capability detection: Try-catch to detect unsupported capabilities; on failure, set `hasFeature = false` to hide UI
- SSE errors: Logged, trigger reconnect cycle; polling fallback for robots without active SSE
- Offline handling: Map falls back to `MapCacheService` disk cache; `isOffline` flag shows banner

## Cross-Cutting Concerns

**Logging:**
- Framework: `os.Logger` (Apple unified logging)
- Pattern: Each class/actor/struct creates `Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "ComponentName")`
- Privacy: Sensitive data marked `.private`, identifiers marked `.public`

**Validation:**
- Request payloads built via Codable structs (e.g., `SegmentCleanRequest`, `PresetControlRequest`)
- Response validation: HTTP status code check (200-299) in `request()` method
- URL validation: Explicit nil check on `config.baseURL` and `URL(string:relativeTo:)`

**Authentication:**
- Storage: Passwords in Keychain via `KeychainStore` (never in UserDefaults)
- Migration: Automatic from legacy UserDefaults JSON to Keychain on `loadRobots()`
- Transmission: HTTP Basic Auth header in each request (Base64 username:password)
- SSL: Per-robot `useSSL` and `ignoreCertificateErrors` flags

**Localization:**
- Pattern: `String(localized: "key")` throughout all views
- File: `ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings`
- Languages: German (de) and English (en)

---

*Architecture analysis: 2026-04-04*
