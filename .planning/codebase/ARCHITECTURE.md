# Architecture

**Analysis Date:** 2026-03-28

## Pattern Overview

**Overall:** MVVM (Model-View-ViewModel) with actor-based concurrency for network operations

**Key Characteristics:**
- SwiftUI as UI framework with @Published state binding
- Three primary ViewModels managing distinct domains (Map, RobotDetail, RobotSettings)
- Actor-based network layer (`ValetudoAPI`) for thread-safe concurrent requests
- Server-Sent Events (SSE) streaming for real-time robot state updates
- AppDelegate integration for notification handling
- Environment object propagation for dependency injection
- Keychain-backed credential storage for robot authentication

## Layers

**Presentation (Views):**
- Purpose: SwiftUI views rendering UI state from ViewModels
- Location: `ValetudoApp/ValetudoApp/Views/`
- Contains: View components organized by feature (RobotListView, MapView, SettingsView, etc.)
- Depends on: ViewModels, Models
- Used by: SwiftUI scene graph, environment propagation

**ViewModels:**
- Purpose: State management, user interaction handling, API orchestration
- Location: `ValetudoApp/ValetudoApp/ViewModels/`
- Contains: `MapViewModel`, `RobotDetailViewModel`, `RobotSettingsViewModel`
- Depends on: RobotManager, ValetudoAPI, Models
- Used by: Views via @StateObject/@EnvironmentObject binding
- Pattern: @MainActor class conforming to ObservableObject with @Published properties

**Services & Managers:**
- Purpose: Stateful service orchestration and cross-cutting concerns
- Location: `ValetudoApp/ValetudoApp/Services/`
- Contains:
  - `RobotManager` (@MainActor class): Central state holder for all robots, manages APIs, periodic refresh, SSE lifecycle
  - `ValetudoAPI` (actor): Thread-safe network client, handles HTTP requests and SSE streaming
  - `SSEConnectionManager` (actor): Manages per-robot SSE connections with reconnect logic
  - `NotificationService` (@MainActor singleton): Push notification scheduling and handling
  - `NetworkScanner` (class): Device discovery via Bonjour mDNS
  - `KeychainStore` (struct): Credential persistence layer
  - `SupportManager` (class): Donation/support state tracking

**Models:**
- Purpose: Data structures for API responses, internal state, and UI representation
- Location: `ValetudoApp/ValetudoApp/Models/`
- Contains:
  - `RobotConfig`: Robot connection metadata (host, auth, SSL settings)
  - `RobotState`: `RobotAttribute`, `RobotStatus`, `StatusValue` enums
  - `RobotMap`: Map layers, entities, segments with run-length decompression cache
  - `Timer`, `Consumable`: Domain models for robot state
- Depends on: None (pure data structures)
- Used by: Services, ViewModels, Views

**App Delegate & Lifecycle:**
- Purpose: Notification handling, app lifecycle configuration
- Location: `ValetudoApp/ValetudoApp/ValetudoApp.swift`
- Triggers: System notification responses, app launch
- Responsibilities: Delegate UNUserNotificationCenter, pass robot manager reference to NotificationService for action routing

## Data Flow

**App Initialization:**
1. AppDelegate.didFinishLaunchingWithOptions → UNUserNotificationCenter delegate setup
2. ValetudoApp scene → RobotManager @StateObject init
3. RobotManager.init → loadRobots from UserDefaults → create ValetudoAPI instances → startRefreshing
4. RobotManager.startRefreshing → periodic refresh task (every 5 seconds)
5. Views mounted → receive robotManager via environment

**Real-Time Updates (SSE):**
1. MapViewModel appears → calls api.startSSE()
2. SSEConnectionManager.connect() spawns Task calling streamWithReconnect
3. Task loops on api.streamStateLines() → reads /attributes/robot_state SSE stream
4. Each SSE line (data: JSON) parsed into [RobotAttribute]
5. Callback onAttributesUpdate fires → MapViewModel receives attributes
6. MapViewModel processes attributes → updates @Published properties
7. Views re-render based on changed properties
8. Connection dropout → exponential backoff (1s → 5s → 30s) auto-reconnect

**Request Flow (Example: Start Cleaning):**
1. View calls viewModel.startCleaning()
2. ViewModel dispatches api.basicAction("start")
3. ValetudoAPI.request (actor) queues work on actor executor
4. Thread-safe HTTP request → URLSession data task
5. Response decode → return to ViewModel
6. ViewModel updates @Published state
7. View subscribes to property → re-renders

**State Management:**
- `RobotManager` holds authoritative state: robots: [RobotConfig], robotStates: [UUID: RobotStatus], robotUpdateAvailable: [UUID: Bool]
- ViewModels subscribe to RobotManager via robotManager.robotStates[robot.id] computed property
- ViewModels maintain local @Published state for UI-specific concerns (editMode, UI loading flags)
- Two-way sync: ViewModel reads robotManager.robotStates, writes via API calls that trigger RobotManager refresh
- AppDelegate.UNUserNotificationCenter intercepts notification responses → calls NotificationService.handleNotificationResponse → updates robot state via robotManager

## Key Abstractions

**ValetudoAPI (actor):**
- Purpose: All network communication to Valetudo REST API
- Examples: `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift`
- Pattern: Single actor per RobotConfig instance, held by RobotManager.apis[UUID]
- Methods: request<T>(), getState(), getMap(), getSegments(), streamStateLines() (SSE), basicAction(), etc.
- Thread safety: Actor isolation ensures serial execution of all network operations for a single robot
- SSL: Optional self-signed certificate bypass via SSLSessionDelegate

**SSEConnectionManager (actor):**
- Purpose: Lifecycle management for streaming connections
- Examples: `ValetudoApp/ValetudoApp/Services/SSEConnectionManager.swift`
- Pattern: Single global instance in RobotManager, manages per-robot Tasks
- Thread safety: Actor serializes connect/disconnect/status queries
- Reconnection: Exponential backoff with Task.sleep, cancellation token cleanup

**RobotManager (@MainActor):**
- Purpose: Single source of truth for robot configuration and state
- Examples: `ValetudoApp/ValetudoApp/Services/RobotManager.swift`
- State: robots (config array), robotStates (status dict), robotUpdateAvailable (update availability dict)
- Lifecycle: Loads from UserDefaults.standard on init, syncs on add/update/remove
- Refresh: 5-second periodic poll of getStatus() for all robots
- Dependency injection: Passed to ViewModels and Views via environment

**ViewModels:**
- `MapViewModel`: Manages map rendering, edit modes (zone/wall drawing), go-to presets, virtual restrictions, room renaming
- `RobotDetailViewModel`: Manages control actions, segment cleaning, consumables, settings presets, statistics polling
- `RobotSettingsViewModel`: Manages robot-specific toggles (carpet mode, key lock) and preset loading
- All @MainActor to ensure UI thread safety
- All ObservableObject with @Published properties driving SwiftUI reactivity
- Receive robot config and robotManager in init, query api via robotManager.getAPI(for:)

**ErrorRouter:**
- Purpose: Centralized error alert UX with optional retry
- Examples: `ValetudoApp/ValetudoApp/Helpers/ErrorRouter.swift`
- Pattern: @MainActor class held as @EnvironmentObject in ContentView
- Usage: Show error with errorRouter.show(error, retry: {})

## Entry Points

**App Entry:**
- Location: `ValetudoApp/ValetudoApp/ValetudoApp.swift`
- Triggers: System app launch
- Responsibilities: Setup AppDelegate, instantiate RobotManager, show onboarding or main UI based on AppStorage flag

**Notification Response:**
- Location: `ValetudoApp/ValetudoApp/ValetudoApp.swift` AppDelegate.userNotificationCenter(didReceive:withCompletionHandler:)
- Triggers: User taps notification action
- Responsibilities: Extract actionIdentifier, call NotificationService.handleNotificationResponse (dispatches robot action)

**View Mount (Map):**
- Location: `ValetudoApp/ValetudoApp/Views/MapView.swift` MapTabView
- Triggers: User selects Map tab
- Responsibilities: Instantiate MapViewModel, start SSE connection

## Error Handling

**Strategy:** Layered error propagation with user-facing alerts and retry logic

**Patterns:**
- Network errors (APIError): Caught in request<T>(), propagated to ViewModel
- ViewModel catches and calls errorRouter.show(error, retry: { await action() })
- User taps Retry button → action() re-executed
- CancellationError: Swallowed cleanly (expected in Task cancellation)
- Decoding errors: Logged but not surfaced (graceful degradation, e.g., SSE line parse failures)
- SSE connection errors: Logged, trigger exponential backoff reconnect

## Cross-Cutting Concerns

**Logging:**
- Framework: os.Logger (Apple's unified logging)
- Pattern: Each class/actor creates Logger(subsystem: Bundle.main.bundleIdentifier, category: "ComponentName")
- Usage: logger.info(), logger.warning(), logger.error() throughout async operations

**Validation:**
- Request payloads: Built into Codable structs (e.g., SegmentCleanRequest, PresetControlRequest)
- Response validation: HTTP status codes checked in request() method (throws APIError.httpError(Int))
- URL validation: Explicit checks in request() to throw APIError.invalidURL

**Authentication:**
- Storage: Passwords in Keychain via KeychainStore (never in UserDefaults)
- Transmission: HTTP Basic Auth header in each request (Base64-encoded username:password)
- SSL: Optional per-robot configuration with ignoreCertificateErrors flag for self-signed certs

---

*Architecture analysis: 2026-03-28*
