# Architecture

**Analysis Date:** 2026-03-28

## Pattern Overview

**Overall:** MVVM (Model-View-ViewModel) with Service-based Data Management and SSE Streaming

**Key Characteristics:**
- SwiftUI-based presentation layer with reactive @Published data binding
- Centralized state management through `RobotManager` (ObservableObject acting as orchestrator)
- Real-time Server-Sent Events (SSE) streaming with 5-second polling fallback
- Service-oriented HTTP communication via `ValetudoAPI` actor (thread-safe)
- Formal ViewModel layer: `RobotDetailViewModel`, `MapViewModel`, `RobotSettingsViewModel`
- AppDelegate integration for notification center delegation
- Comprehensive error handling with user-facing alerts via `ErrorRouter`

## Layers

**Presentation Layer (Views):**
- Purpose: Render UI and respond to user interactions
- Location: `ValetudoApp/ValetudoApp/Views/*.swift` (15 files)
- Contains: SwiftUI View structures using List, NavigationStack, TabView, Canvas (for map)
- Key files:
  - `RobotListView.swift` — Robot inventory list
  - `RobotDetailView.swift` — Detail dashboard (status, updates, consumables, stats)
  - `MapView.swift` — Interactive map with zones, walls, goto presets, room editing
  - `RobotSettingsView.swift` — Robot-specific configuration
  - `SettingsView.swift` — App settings, notification preferences
  - Supporting views: `AddRobotView`, `OnboardingView`, `TimersView`, `ConsumablesView`, `StatisticsView`, `ManualControlView`, `RoomsManagementView`, `IntensityControlView`, `DoNotDisturbView`, `ObstaclePhotoView`
- Depends on: ViewModels, RobotManager, ErrorRouter (environment objects)
- Used by: SwiftUI runtime

**ViewModel Layer:**
- Purpose: Transform raw API state into UI-ready computed properties; orchestrate user interactions
- Location: `ValetudoApp/ValetudoApp/ViewModels/*.swift`
  - `RobotDetailViewModel` — Status, control, consumables, updates, statistics, capabilities
  - `MapViewModel` — Map data, zones, walls, presets, room editing state, edit modes
  - `RobotSettingsViewModel` — Robot-specific settings (if separated; may be in RobotSettingsView)
- Pattern: @MainActor ObservableObject classes with @Published properties
- Depends on: Models, ValetudoAPI (via robotManager.getAPI()), RobotManager
- Used by: Views with @StateObject/@ObservedObject

**Service Layer:**
- Purpose: Core business logic, network communication, state management, notifications, discovery
- Location: `ValetudoApp/ValetudoApp/Services/*.swift`
  - `RobotManager` (central orchestrator)
    - Manages robot list persistence (UserDefaults)
    - Lazy-creates and caches ValetudoAPI instances per robot
    - Runs background polling task (5-second loop) + SSE connection loop
    - Aggregates robot state in `robotStates[UUID]: RobotStatus`
    - Triggers notifications on state transitions
    - Handles Keychain migration for legacy password storage
  - `ValetudoAPI` (HTTP client, actor-based)
    - Generic `request<T>()` method for type-safe JSON decoding
    - Separate URLSession for SSE (infinite timeout) vs. normal (10s request/30s resource)
    - Basic Auth injection from Keychain
    - SSL certificate validation with optional bypass (SSLSessionDelegate)
    - Error types: invalidURL, networkError, invalidResponse, httpError, decodingError
  - `SSEConnectionManager` (connection pool, actor-based)
    - Per-robot long-lived connection to `/api/v2/status/raw`
    - Auto-reconnect with 30s backoff on network failures
    - Graceful cancellation on task cancel
    - Parses SSE format: `data: {...}` → JSON attributes
  - `NotificationService` (singleton, @MainActor)
    - Local push notification scheduling via UNUserNotificationCenter
    - Categories: CLEANING_COMPLETE, ROBOT_ERROR, ROBOT_STUCK, CONSUMABLE_LOW, ROBOT_OFFLINE
    - User preferences backed by @AppStorage
  - `KeychainStore` — Secure password storage (replace legacy UserDefaults storage)
  - `NetworkScanner` / `NWBrowserService` — mDNS/Bonjour robot discovery
- Depends on: Models, Foundation, os.Logger
- Used by: ViewModels, Views (indirect via RobotManager)

**Model Layer:**
- Purpose: Define domain structures and API request/response DTOs
- Location: `ValetudoApp/ValetudoApp/Models/*.swift`
  - `RobotConfig.swift` — Persistent robot identity (UUID, name, host, username, SSL flags). Password excluded (Keychain-stored). Codable with backward-compat decoder.
  - `RobotState.swift` — All API response types:
    - `RobotInfo` — Manufacturer, model name, implementation
    - `RobotAttribute` — Generic container with `__class`, type, value, level, flag
    - `RobotStatus` — Aggregated state (online flag, attributes[], info) with computed getters (batteryLevel, statusValue, cleanedArea, attachment states)
    - `Segment`, `BasicAction`, `BasicControlRequest`, `PresetControl*`, `SpeakerVolume*`, `Carpet/Persistent/Map`, `Statistics`, `Zone*`, `VirtualWall*`, `Manual/HighResControl`, `Quirk`, `WiFi*`, `MQTT*`, `NTP*`, `Valetudo*`, `Updater*`, `Event*`
  - `RobotMap.swift` — Map visualization data (segments, image, metadata)
  - `Consumable.swift` — Consumable (name, type, remaining %)
  - `Timer.swift` — Timer definitions
  - `GoToPresetStore` — Preset management (@MainActor ObservableObject for UserDefaults-backed persistence)
- Depends on: Foundation only
- Used by: Services, ViewModels, Views

**Helper/Utility Layer:**
- Purpose: Cross-cutting concerns and shared logic
- Location: `ValetudoApp/ValetudoApp/Helpers/*.swift` & `ValetudoApp/ValetudoApp/Utilities/*.swift`
  - `ErrorRouter.swift` — Global error state + alert presentation (show, dismiss, retry)
  - `DebugConfig.swift` — Feature flags (showAllCapabilities, etc.)
  - `PresetHelpers.swift` — Display names, icons, colors for presets
- Depends on: SwiftUI, Models
- Used by: Views, ViewModels

**AppDelegate & App Entry:**
- Purpose: Lifecycle management, notification delegation
- Location: `ValetudoApp/ValetudoApp/ValetudoApp.swift`
- Contains:
  - `AppDelegate` class (NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate) — handles didFinishLaunching, notification responses
  - `@main ValetudoApp` (App) — @UIApplicationDelegateAdaptor, creates RobotManager and ErrorRouter as @StateObject, onboarding gate via @AppStorage, environment injection
- Depends on: RobotManager, ErrorRouter, NotificationService
- Used by: iOS runtime

**Intents Layer (Siri/Shortcuts):**
- Purpose: Voice command and shortcut integration
- Location: `ValetudoApp/ValetudoApp/Intents/RobotIntents.swift`
- Contains: 6 intents (Start, Stop, Pause, Home, CleanRooms, GoToLocation) + entity resolution + shortcuts provider
- Depends on: Models, ValetudoAPI (creates own instances), UserDefaults
- Used by: Siri, Shortcuts app

## Data Flow

**Real-time Status Refresh (Primary):**

1. **Init:** `RobotManager.init()` loads saved robots from UserDefaults, initializes APIs, calls `startRefreshing()`
2. **SSE Connection Phase:** In `startRefreshing()` background task:
   - For each robot without active SSE: Call `SSEConnectionManager.connect()`
   - Manager spawns task calling `api.streamStateLines()` → opens long-lived GET to `/api/v2/status/raw`
   - Parses SSE format: `data: {...attributes JSON...}`
   - Decodes into `[RobotAttribute]`, invokes `onAttributesUpdate` callback
   - Callback updates `RobotManager.robotStates[id]` on MainActor
3. **Fallback Polling:** If no SSE active, `refreshRobot()` is called by polling phase
   - Calls `ValetudoAPI.getAttributes()` + `getRobotInfo()`
   - Wraps result in `RobotStatus`, stores in `robotStates[id]`
   - Polling interval: 5 seconds (via Task.sleep)
4. **State Mutation:** `robotStates[id]` is @Published → triggers View redraws
5. **Notification Triggers:** `checkStateChanges()` detects transitions:
   - Cleaning → Docked/Idle → notifyCleaningComplete()
   - New stuck flag → notifyRobotStuck()
   - Error state → notifyRobotError()
6. **Error Handling:** Network errors → robot marked offline → notifyRobotOffline()
7. **SSE Reconnect:** On SSE failure, waits 30s then retries; continues polling until reconnected

**User Interaction Flow (Example: Start Cleaning):**

1. **User taps "Start" in RobotDetailView**
2. **View calls `viewModel.startCleaning()`** → sets isLoading = true
3. **ViewModel calls `api?.basicControl(action: .start)`** → POST to `/api/v2/robot/action`
4. **API response received** (success or error); ViewModel updates state or shows error via ErrorRouter
5. **Polling/SSE cycle delivers new RobotStatus** with `statusValue == "cleaning"`
6. **RobotManager updates `robotStates[id]`** → View sees isLoading = false, status changed
7. **On completion, checkStateChanges() fires notification**

**State Change Tracking:**

- **Previous State:** `RobotManager.previousStates[UUID]` stores prior RobotStatus
- **Current State:** `RobotManager.robotStates[UUID]` holds live RobotStatus
- **Comparison:** `checkStateChanges()` diffs statusValue, statusFlag, other key fields
- **Notification Trigger:** Only fires if meaningful transition detected (prevents spam)

## Key Abstractions

**RobotManager (Central Orchestrator):**
- **Purpose:** Single source of truth for robot state; manages API/SSE lifecycle
- **Pattern:** @MainActor ObservableObject with persistent background Task
- **Key Properties:**
  - `robots: [RobotConfig]` — Configured robots (persisted to UserDefaults)
  - `robotStates[UUID]: RobotStatus` — Live state per robot (@Published)
  - `robotUpdateAvailable[UUID]: Bool` — Update availability flags
  - Private `apis[UUID]: ValetudoAPI` — Lazy-created API clients
  - Private `sseManager: SSEConnectionManager` — Streaming connection pool
  - Private `previousStates[UUID]: RobotStatus` — State change detection
- **Key Methods:**
  - `addRobot()` — Store config, create API, save Keychain password
  - `refreshRobot()` — Poll state; emit notifications on transitions
  - `startRefreshing()` — Background loop: SSE connection + polling
  - `applyAttributeUpdate()` — Handle incoming SSE attributes
  - `checkStateChanges()` — Detect transitions, trigger notifications
- **Lifecycle:** Init → startRefreshing() background task loop; deinit cancels task

**ValetudoAPI (Thread-safe HTTP Client):**
- **Purpose:** All network communication with Valetudo REST API v2
- **Pattern:** Swift actor with generic `request<T: Decodable>()` base
- **Key Properties:**
  - `config: RobotConfig` — Target robot (host, auth, SSL)
  - `session: URLSession` — Normal HTTP (10s request, 30s resource timeout)
  - `sseSession: URLSession` — SSE-specific (infinite timeout)
  - `sessionDelegate: SSLSessionDelegate?` — Optional cert bypass
- **Key Methods:**
  - `request<T>()` — Base generic method: constructs URL, injects Basic Auth, decodes JSON, handles errors
  - `streamStateLines()` — Returns AsyncSequence of SSE lines (long-lived)
  - `getAttributes()`, `getRobotInfo()` — State queries
  - `basicControl()`, `startSegmentClean()`, `goTo()` — Control commands
  - `getMap()`, `getCapabilities()`, `getUpdaterState()` — Queries
  - `*PresetControl()`, `setVolume()`, `*VirtualRestrictions()` — Advanced controls
- **Error Handling:** APIError enum with specific cases; throws to caller

**SSEConnectionManager (Streaming Resilience):**
- **Purpose:** Manage per-robot long-lived SSE connections with auto-reconnect
- **Pattern:** Actor with per-robot task tracking
- **Key Methods:**
  - `connect()` — Spawn streaming task for robot
  - `disconnect()` — Clean shutdown
  - `isSSEActive()` — Check connection status
  - `streamWithReconnect()` — Retry loop with 30s backoff
- **Behavior:** On network failure, waits 30s then retries; never throws (gracefully handles cancellation)

**RobotConfig (Configuration):**
- **Purpose:** Persistent robot identity
- **Pattern:** Codable, Identifiable, Equatable, Hashable
- **Fields:** UUID, name, host, username, useSSL, ignoreCertificateErrors (no password)
- **Computed:** `baseURL` property (constructs http/https URL)
- **Decoder:** Custom to exclude password from UserDefaults JSON (Keychain-stored separately)

**RobotStatus (State Snapshot):**
- **Purpose:** Aggregate live attributes + info into derived properties
- **Pattern:** Value type struct with computed getters
- **Fields:** isOnline, attributes: [RobotAttribute], info: RobotInfo?
- **Computed Getters:**
  - `batteryLevel`, `batteryStatus` — From BatteryStateAttribute
  - `statusValue`, `statusFlag` — From StatusStateAttribute
  - `cleanedArea` — From LatestCleanupStatisticsAttribute
  - `dustbinAttached`, `mopAttached`, `waterTankAttached` — From AttachmentStateAttribute
  - `hasMissingAttachments` — Convenience check
- **Immutable:** Created fresh from API response, no mutation after creation

**ErrorRouter (Error Presentation):**
- **Purpose:** Global error state + retry mechanism
- **Pattern:** @MainActor ObservableObject
- **Methods:**
  - `show(_ error:, retry:)` — Show error with optional retry action
  - `dismiss()` — Hide error
- **Usage:** `.withErrorAlert(router:)` view modifier renders alert with Retry + OK buttons

## Entry Points

**App Initialization (`ValetudoApp.swift`):**
- **Trigger:** iOS app launch
- **Responsibilities:**
  - Create AppDelegate, set notification center delegate
  - Initialize RobotManager as @StateObject (persists across redraws)
  - Initialize ErrorRouter as @StateObject
  - Check hasCompletedOnboarding flag (@AppStorage)
  - Show OnboardingView or ContentView + environment injection
  - Set NotificationService.robotManagerRef for notification callbacks

**ContentView.swift:**
- **Trigger:** After onboarding completion
- **Responsibilities:**
  - TabView with 3 tabs: Robots, Map, Settings
  - Manage selectedRobotId state
  - Conditional Map tab visibility (only if robot selected)
  - Route to RobotListView, MapTabView (MapContentView), SettingsView
  - Handle robot selection → auto-switch from Map tab if deselected

**RobotDetailView.swift:**
- **Trigger:** Tap on robot in RobotListView
- **Responsibilities:**
  - Create RobotDetailViewModel (@StateObject)
  - Display status banner, updates, consumables, statistics
  - Buttons for control actions (Start, Stop, Pause, Home)
  - Routes to MapView (fullscreen sheet), TimersView, settings sub-views
  - Shows update available banner + upgrade flow

**MapView.swift:**
- **Trigger:** Select Map tab or open from RobotDetailView
- **Responsibilities:**
  - Create MapViewModel (@StateObject)
  - Render map canvas with segments, zones, walls, paths
  - Support pan/zoom gestures
  - Edit modes: zone drawing, go-to targeting, room editing, restriction management
  - Preset management (save, list, delete go-to locations)
  - Cleaning control: full map, segments, zones

## Error Handling

**Strategy:** Layered error propagation with user-facing alerts + silent background failure

**Patterns:**

1. **API Layer (`ValetudoAPI`):**
   - Catches URLSession errors → wraps in `APIError` enum
   - HTTP errors (4xx, 5xx) → `APIError.httpError(code)`
   - Decoding errors → `APIError.decodingError(error)`
   - Throws to caller (propagates via async/await)

2. **Service Layer (`RobotManager`):**
   - `refreshRobot()` catches API errors → marks robot offline, no throw
   - Notification checks (`checkUpdateForRobot`, `checkConsumables`) silently catch + ignore
   - SSE connection errors logged; reconnect loop hides failures
   - Result: Robot shows "offline" in UI rather than crash or alert

3. **ViewModel Layer:**
   - Wraps API calls in `do/catch` or `try?`
   - Sets `isLoading = false` on error
   - Passes error to `ErrorRouter.show(error)` on user-initiated actions
   - ErrorRouter displays alert with optional Retry button

4. **View Layer:**
   - Applies `.withErrorAlert(router: errorRouter)` modifier to root View
   - Renders alert when `errorRouter.currentError != nil`
   - Alert offers "Retry" (re-executes retry action) + "OK" (dismiss)

5. **SSE Streaming (`SSEConnectionManager`):**
   - JSON decode errors: logged as warning, continue parsing next line
   - Network disconnects: log warning, trigger reconnect loop (30s backoff)
   - Task cancellation: caught explicitly, exit cleanly without error

## Cross-Cutting Concerns

**Logging:**
- Framework: os.Logger (Apple's unified logging)
- Subsystem: Bundle ID (com.valetudio)
- Categories: "RobotManager", "API", "SSE", "Notifications"
- Levels: info, warning, error
- Privacy: privacy: .public redaction for URLs, UUIDs

**Validation:**
- Config validation: Non-empty host, valid URL parsing
- API response validation: Strict JSON decoding (fails if schema mismatch)
- Attribute extraction: Safe optional unwrapping + type casting
- Connection check: `ValetudoAPI.checkConnection()` in AddRobotView before saving

**Authentication:**
- Basic Auth: `username:password` base64 in `Authorization: Basic ...` header
- Credentials: Username in RobotConfig (plain), password in Keychain (encrypted)
- SSL: URLSession with SSLSessionDelegate optionally bypasses cert validation
- No token/OAuth; stateless per-request

**State Persistence:**
- Configs: UserDefaults JSON (robots list, go-to presets, onboarding flag)
- Passwords: Keychain (OS-level encryption)
- Preferences: @AppStorage (notification toggles, app settings)
- Migration: On RobotManager.init(), move legacy passwords from UserDefaults → Keychain
- Transient: RobotStatus, segments, map data not persisted (fresh fetch per session)

**Notifications (Local Push):**
- Trigger: `RobotManager.checkStateChanges()` detects state transition
- Categories: CLEANING_COMPLETE, ROBOT_ERROR, ROBOT_STUCK, CONSUMABLE_LOW, ROBOT_OFFLINE
- User Preferences: @AppStorage toggles (per notification type)
- Delivery: UNUserNotificationCenter.current().add() with identifier + 0.5s trigger
- Actions: Go Home, Locate buttons (handled by AppDelegate.userNotificationCenter)
- Authorization: Requested on RobotManager.init() via NotificationService.requestAuthorization()

**Internationalization:**
- Strings: All localized via `String(localized:)` (compile-time resolved)
- Catalog: `Localizable.xcstrings` (Xcode 14.3+)
- Supported: German (de) + English (en)
- Plural/Gender: Handled via plural rules in .xcstrings

---

*Architecture analysis: 2026-03-28*
