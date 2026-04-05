# Architecture

**Analysis Date:** 2026-04-04

## Pattern Overview

**Overall:** MVVM with SwiftUI + Centralized State Management

**Key Characteristics:**
- Single source of truth via `RobotManager` (Observable, MainActor-bound)
- View Models mediate between Views and Services
- SSE (Server-Sent Events) streaming for real-time updates, with HTTP polling fallback
- Decentralized network access via `ValetudoAPI` (actor-isolated for thread safety)
- Environment-based dependency injection for RobotManager and ErrorRouter

## Layers

**Presentation Layer (Views):**
- Purpose: Display UI and handle user interaction
- Location: `ValetudoApp/Views/`, `ValetudoApp/Views/Settings/`, `ValetudoApp/Views/Detail/`
- Contains: SwiftUI View structs implementing UI for tabs, robot list, map, settings
- Depends on: ViewModels, RobotManager (via @Environment), ErrorRouter
- Used by: ContentView (tab orchestration), Navigation stacks

**Presentation Logic Layer (ViewModels):**
- Purpose: Coordinate data binding and business logic for Views
- Location: `ValetudoApp/ViewModels/`
- Contains: RobotDetailViewModel, MapViewModel, RobotSettingsViewModel
- Depends on: RobotManager, ValetudoAPI, Services (UpdateService, etc.)
- Used by: Detail and Map views via @State initialization

**Application State Layer (RobotManager):**
- Purpose: Centralized state container for robot configurations, statuses, room selections
- Location: `ValetudoApp/Services/RobotManager.swift`
- Contains: robot list, robot states (status/battery/cleaning), update availability, room/iteration selections
- Depends on: ValetudoAPI, SSEConnectionManager, KeychainStore, NotificationService, UpdateService
- Used by: Views, ViewModels via @Environment(RobotManager.self)

**Network/API Layer:**
- Purpose: REST API communication and real-time streaming
- Location: `ValetudoApp/Services/ValetudoAPI.swift`, `ValetudoApp/Services/SSEConnectionManager.swift`
- Contains: HTTP requests (GET, POST, PUT), JSON parsing, SSL/TLS handling, SSE connection pooling
- Depends on: URLSession, RobotConfig (configuration data)
- Used by: RobotManager (refresh polling), ViewModels (imperative actions)

**Service Layer:**
- Purpose: Cross-cutting concerns and specialized operations
- Location: `ValetudoApp/Services/`
- Contains:
  - `KeychainStore`: Secure password storage
  - `NotificationService`: Push notifications and local alerts
  - `UpdateService`: Firmware update orchestration
  - `BackgroundMonitorService`: Background task scheduling
  - `MapCacheService`: Map image caching and persistence
  - `SupportManager`: StoreKit transactions
- Depends on: RobotManager, ValetudoAPI, System frameworks
- Used by: RobotManager, ViewModels

**Data/Model Layer:**
- Purpose: Data structures and codable representations
- Location: `ValetudoApp/Models/`
- Contains: RobotConfig, RobotState, RobotMap, Consumable, Timer, Segment structures
- Depends on: Foundation only
- Used by: All layers for serialization/deserialization

## Data Flow

**Real-Time Status Updates:**

1. RobotManager.startRefreshing() → connects SSEConnectionManager for each robot
2. SSEConnectionManager.connect() → opens persistent SSE stream via ValetudoAPI
3. SSE events arrive → onAttributesUpdate callback → RobotManager.applyAttributeUpdate()
4. RobotManager updates robotStates[UUID] → @Observable triggers UI refresh
5. Views re-render via SwiftUI's observation system

**Fallback Polling (when SSE unavailable):**

1. startRefreshing() polls every 5 seconds → RobotManager.refreshRobot(robotId)
2. ValetudoAPI.getAttributes() → HTTP GET /api/v0/robot/state
3. RobotStatus computed from attributes → robotStates[UUID] updated
4. Same UI refresh as SSE path

**Robot Control Actions:**

1. User taps button → View calls await viewModel.action()
2. ViewModel calls await robotManager.api.call() or imperative RobotManager method
3. ValetudoAPI sends REST request (POST /api/v0/robot/action/*)
4. Response triggers immediate refresh via SSE or next poll cycle
5. UI updates via robotStates reactive binding

**Room Selection State:**

1. User toggles room in map → MapViewModel.selectedSegmentIds setter triggers
2. MapViewModel.selectedSegmentIds didSet → robotManager.roomSelections[robotId] = selectedSegmentIds
3. RobotDetailViewModel reflects change via selectedSegments didSet
4. State persists in RobotManager for cross-view access
5. Passed to API when cleaning by room is initiated

**State Management:**

- Robot list and configs: RobotManager.robots (persisted to UserDefaults via saveRobots/loadRobots)
- Robot statuses: RobotManager.robotStates (ephemeral, rebuilt from SSE/polling)
- UI state (selections, sheets): Local @State in Views and ViewModels
- Sensitive data (passwords): iOS Keychain via KeychainStore
- Map cache: MapCacheService filesystem storage

## Key Abstractions

**RobotManager:**
- Purpose: Single source of truth for all robot data and multi-robot coordination
- Examples: `ValetudoApp/Services/RobotManager.swift`
- Pattern: @Observable class with @MainActor isolation, persistent storage, SSE/polling orchestration

**ValetudoAPI:**
- Purpose: Encapsulate REST protocol and session management
- Examples: `ValetudoApp/Services/ValetudoAPI.swift`
- Pattern: Actor-isolated class for thread safety, supports SSL/self-signed certs, request/response decoding

**ViewModel Pattern:**
- Purpose: Bridge Views and RobotManager with local UI state
- Examples: `ValetudoApp/ViewModels/RobotDetailViewModel.swift`, `MapViewModel.swift`, `RobotSettingsViewModel.swift`
- Pattern: @Observable @MainActor classes initialized in @State, coordinate capabilities and data loading

**ErrorRouter:**
- Purpose: Global error handling and retry logic
- Examples: `ValetudoApp/Helpers/ErrorRouter.swift`
- Pattern: Observable singleton passed via @Environment, alert presentation triggered by currentError state

**SSEConnectionManager:**
- Purpose: Manage persistent streaming connections per robot
- Examples: `ValetudoApp/Services/SSEConnectionManager.swift`
- Pattern: Actor-isolated pool of concurrent Tasks, reconnection logic, callback-based updates

## Entry Points

**Application:**
- Location: `ValetudoApp/ValetudoApp.swift`
- Triggers: App launch (UIApplicationDelegate lifecycle)
- Responsibilities: Initialize AppDelegate for background task registration, create RobotManager, inject environment, route to Onboarding or ContentView

**Root Content:**
- Location: `ValetudoApp/ContentView.swift`
- Triggers: After onboarding completion
- Responsibilities: Tab bar orchestration (Robots/Map/Settings), robot selection, map tab visibility

**Robot Detail:**
- Location: `ValetudoApp/Views/RobotDetailView.swift`
- Triggers: User selects robot from list
- Responsibilities: Display robot status, control buttons, room/zone/settings access, update warnings

**Map:**
- Location: `ValetudoApp/Views/MapView.swift`
- Triggers: User selects Map tab (when robot selected) or opens full map from detail
- Responsibilities: Interactive map rendering, zone/wall drawing, room editing, GoTo preset management

## Error Handling

**Strategy:** Structured error types with user-facing localization, retry capability via ErrorRouter

**Patterns:**

- **Network Errors:** APIError enum (invalidURL, networkError, httpError, decodingError) → caught in RobotManager.refreshRobot() → robotStates marked offline → offline UI
- **Robot Offline:** Network failure → RobotStatus(isOnline: false) → notifyRobotOffline() → push notification
- **API Validation Failures:** HTTP 4xx/5xx → APIError.httpError(code) → ErrorRouter.show() with user message and optional retry
- **Decoding Failures:** Malformed JSON → APIError.decodingError() → logged, error shown, robot treated as offline
- **Capability Loading:** ValetudoAPI.getCapabilities() failures cached for 24hrs → allows UI to gracefully degrade

## Cross-Cutting Concerns

**Logging:**
- Approach: os.Logger (Apple's unified logging) with subsystem "com.valetudio" and categories per module
- Examples: RobotManager, MapViewModel, ValetudoAPI, SSEConnectionManager
- Access: Console.app with filter (subsystem:com.valetudio) in development

**Validation:**
- Approach: Model-level validation in Codable init/CodingKeys
- Examples: RobotConfig ignores passwords in CodingKeys (passwords stored in Keychain), MapLayer supports both raw and compressed pixels
- UI validation: ViewModel methods check state before API calls (e.g., selectedSegments not empty for room clean)

**Authentication:**
- Approach: Optional username/password in RobotConfig, stored separately (username in UserDefaults, password in Keychain)
- Implementation: URLSession Basic Auth via ValetudoAPI.request() headers
- SSL/Certs: SSLSessionDelegate allows self-signed certificates when ignoreCertificateErrors = true

**Performance Optimization:**
- Segment pixel caching: MapLayerCache on MapLayer struct (class reference for mutability in let contexts)
- Capabilities caching: 24-hour TTL in RobotManager.capabilitiesCache
- Map re-render prevention: MapViewModel.staticLayerImage pre-renders static layers, Canvas redraws only dynamic elements
- Selective polling: Only poll robots without active SSE; when activeRobotId set, skip background robots

---

*Architecture analysis: 2026-04-04*
