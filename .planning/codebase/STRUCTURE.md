# Codebase Structure

**Analysis Date:** 2026-03-28

## Directory Layout

```
valetudo-app/
├── ValetudoApp/                           # Xcode project root
│   ├── ValetudoApp.xcodeproj/             # Xcode project metadata
│   │   ├── project.pbxproj                # Build configuration
│   │   └── xcshareddata/xcschemes/        # Scheme definitions
│   │
│   ├── ValetudoApp/                       # Main app source directory
│   │   ├── ValetudoApp.swift              # App entry point (@main), AppDelegate
│   │   ├── ContentView.swift              # Root TabView (Robots, Map, Settings)
│   │   │
│   │   ├── Views/                         # SwiftUI UI components (15 files)
│   │   │   ├── RobotListView.swift        # Robot inventory list
│   │   │   ├── RobotDetailView.swift      # Robot dashboard (1519 lines)
│   │   │   ├── MapView.swift              # Interactive map (3004 lines) — canvas, zones, walls, rooms
│   │   │   ├── RobotSettingsView.swift    # Robot config (Wi-Fi, MQTT, NTP, etc.) (1923 lines)
│   │   │   ├── SettingsView.swift         # App-level settings, notification prefs (372 lines)
│   │   │   ├── AddRobotView.swift         # New robot setup with network scanning (267 lines)
│   │   │   ├── OnboardingView.swift       # First-launch flow (172 lines)
│   │   │   ├── TimersView.swift           # Scheduled cleaning timers (334 lines)
│   │   │   ├── ConsumablesView.swift      # Consumable monitoring + reset (156 lines)
│   │   │   ├── StatisticsView.swift       # Cleaning stats display (147 lines)
│   │   │   ├── ManualControlView.swift    # Touchpad-style control (224 lines)
│   │   │   ├── RoomsManagementView.swift  # Room rename/join/split/material (721 lines)
│   │   │   ├── IntensityControlView.swift # Fan speed, water, mode picker (225 lines)
│   │   │   ├── DoNotDisturbView.swift     # DND schedule config (160 lines)
│   │   │   └── ObstaclePhotoView.swift    # Obstacle image viewer
│   │   │
│   │   ├── ViewModels/                    # MVVM business logic (3 files)
│   │   │   ├── RobotDetailViewModel.swift # Status, controls, updates, stats
│   │   │   ├── MapViewModel.swift         # Map state, edit modes, presets
│   │   │   └── RobotSettingsViewModel.swift # Settings state (if separated)
│   │   │
│   │   ├── Models/                        # Domain models & API DTOs (5 files)
│   │   │   ├── RobotConfig.swift          # Robot config (host, auth, SSL)
│   │   │   ├── RobotState.swift           # 50+ API types (818 lines) — attributes, controls, zones, MQTT, NTP, etc.
│   │   │   ├── RobotMap.swift             # Map visualization data
│   │   │   ├── Consumable.swift           # Consumable tracking
│   │   │   └── Timer.swift                # Timer models
│   │   │
│   │   ├── Services/                      # Business logic & integrations (7 files)
│   │   │   ├── RobotManager.swift         # Central orchestrator (493 lines); polling + SSE + notifications
│   │   │   ├── ValetudoAPI.swift          # REST client (actor, 584 lines); 40+ endpoints
│   │   │   ├── SSEConnectionManager.swift # Streaming pool (actor); per-robot SSE with reconnect
│   │   │   ├── NotificationService.swift  # Local push notifications (singleton, 154 lines)
│   │   │   ├── KeychainStore.swift        # Secure password storage
│   │   │   ├── NetworkScanner.swift       # LAN device discovery (173 lines)
│   │   │   └── NWBrowserService.swift     # mDNS/Bonjour browser
│   │   │
│   │   ├── Helpers/                       # Shared logic (3 files)
│   │   │   ├── ErrorRouter.swift          # Error state + alert presentation
│   │   │   ├── DebugConfig.swift          # Feature flags (showAllCapabilities)
│   │   │   └── PresetHelpers.swift        # Preset UI helpers (names, icons, colors)
│   │   │
│   │   ├── Utilities/                     # Additional utilities
│   │   │   └── [extension/helper files]
│   │   │
│   │   ├── Intents/                       # Siri/Shortcuts (1 file)
│   │   │   └── RobotIntents.swift         # 6 intents (314 lines) — Start, Stop, Pause, Home, CleanRooms, GoTo
│   │   │
│   │   ├── Resources/                     # Localization & fonts
│   │   │   ├── Localizable.xcstrings      # Multi-language catalog (152KB) — German + English
│   │   │   └── Fonts/                     # Custom font files (if any)
│   │   │
│   │   └── [Assets, entitlements, info.plist]
│   │
│   └── ValetudoAppTests/                  # Unit & integration tests
│       ├── ConsumableTests.swift
│       ├── TimerTests.swift
│       ├── MapLayerTests.swift
│       ├── KeychainStoreTests.swift
│       └── [other tests]
│
├── .planning/                             # Planning & analysis (generated)
│   ├── codebase/
│   │   ├── ARCHITECTURE.md                # App architecture, data flow, abstractions
│   │   ├── STRUCTURE.md                   # (You are here) Directory layout & file organization
│   │   ├── CONVENTIONS.md                 # Coding style, naming, patterns
│   │   ├── TESTING.md                     # Test framework, patterns, coverage
│   │   ├── STACK.md                       # Technology stack & versions
│   │   └── INTEGRATIONS.md                # External APIs, databases, services
│   └── config.json                        # Planning tool config
│
├── AppStoreMetadata/                      # App Store screenshots/metadata
├── Untitled.icon/                         # Icon source assets
├── .gitignore
├── README.md
└── [Other root files]
```

## Directory Purposes

**ValetudoApp/** (Source Root)
- Purpose: All application source code
- Contains: Views, ViewModels, Models, Services, Helpers, Utilities, Intents, Resources
- Organization: Feature-based grouping by layer (Views, Models, Services, etc.)

**Views/** (15 files, 8000+ LOC total)
- Purpose: All SwiftUI view components organized by feature/screen
- Pattern: `struct Name: View { ... }` with @StateObject/@EnvironmentObject
- Key complexity:
  - `MapView.swift` (3004 lines) — Handles map canvas rendering, pan/zoom, zone/wall/room drawing, gestures, editing modes
  - `RobotDetailView.swift` (1519 lines) — Dashboard with status, controls, consumables, updates, statistics sections
  - `RobotSettingsView.swift` (1923 lines) — Complete robot configuration (WiFi, MQTT, NTP, DND, quirks, etc.)
- Simple views: List-based screens with NavigationLink navigation
- Sheet presentations: AddRobotView, RobotSettingsView, TimersView as overlays

**ViewModels/** (3 files, ~400-600 lines each)
- Purpose: Business logic and state transformation for complex views
- Pattern: `@MainActor final class ViewModel: ObservableObject { @Published properties, methods }`
- Responsibilities:
  - `RobotDetailViewModel` — Status queries, consumables, statistics, capabilities, updates, control commands
  - `MapViewModel` — Map data loading, edit modes, zone/wall/preset drawing, room editing state
  - `RobotSettingsViewModel` — Settings form state, API calls for configuration (if separated from view)
- Initialization: Views create via `@StateObject(wrappedValue: ViewModel(robot:, robotManager:))`

**Models/** (5 files, 1100+ LOC total)
- Purpose: Domain models and API DTOs
- Single-responsibility: Each file covers one domain area
- Key files:
  - `RobotConfig.swift` — Robot connection config; Codable; persisted to UserDefaults; password excluded (Keychain-stored)
  - `RobotState.swift` — Largest (818 lines); defines 50+ types for API communication:
    - `RobotInfo`, `RobotAttribute`, `RobotStatus` — Status data
    - `Segment`, `Capabilities` — Room definitions
    - `BasicControlRequest`, `SegmentCleanRequest`, `GoToRequest` — Control commands
    - `FanSpeedPreset`, `WaterUsagePreset` — Intensity enums with display helpers
    - `Consumable`, `StatisticEntry`, `Zone*`, `Virtual*` — Domain models
    - `WiFi*`, `MQTT*`, `NTP*` — Integration config
    - `Updater*`, `Quirk`, `DoNotDisturb*` — Advanced features
    - `GoToPreset`, `GoToPresetStore` — Preset persistence
  - `RobotMap.swift` — Map layer, segment visualization, metadata
  - `Consumable.swift` — Consumable type + display formatting
  - `Timer.swift` — Scheduled timer definitions

**Services/** (7 files, 1500+ LOC total)
- Purpose: Core business logic, network communication, state management
- Architecture: Central RobotManager + specialized services
- Key files:
  - `RobotManager.swift` (493 lines) — Central orchestrator:
    - Loads/saves robot configs (UserDefaults)
    - Manages ValetudoAPI instances per robot (lazy-created)
    - Runs background polling task (5s loop) + SSE connection management
    - Aggregates state in `robotStates[UUID]: RobotStatus` (@Published)
    - Detects state transitions → triggers notifications
    - Handles Keychain password migration
    - Also defines `RobotStatus` struct (inline)
  - `ValetudoAPI.swift` (584 lines) — HTTP client actor:
    - Generic `request<T>()` method with JSON decoding
    - 40+ REST endpoints covering all robot capabilities
    - Basic Auth injection from Keychain
    - Two URLSession instances: one for SSE (infinite), one for normal (10s/30s)
    - SSL certificate validation with optional bypass
    - APIError enum for type-safe error handling
  - `SSEConnectionManager.swift` — Streaming connection pool (actor):
    - Per-robot long-lived SSE connection to `/api/v2/status/raw`
    - Auto-reconnect with 30s backoff
    - Graceful cancellation on task cancel
    - Parses SSE format: `data: {...}` → JSON decode
  - `NotificationService.swift` (154 lines) — Local push notifications:
    - Singleton pattern (@MainActor)
    - UNUserNotificationCenter integration
    - Categories: CLEANING_COMPLETE, ROBOT_ERROR, ROBOT_STUCK, CONSUMABLE_LOW, ROBOT_OFFLINE
    - User preferences via @AppStorage
  - `KeychainStore.swift` — Secure credential storage
  - `NetworkScanner.swift` (173 lines) — LAN subnet scanning
  - `NWBrowserService.swift` — mDNS/Bonjour browser implementation

**Helpers/** (3 files, ~150 LOC total)
- Purpose: Cross-cutting utilities and shared logic
- Pattern: Static functions or enums with computed properties
- Files:
  - `ErrorRouter.swift` — Global error state machine:
    - @MainActor ObservableObject
    - `show(error, retry:)`, `dismiss()` methods
    - Used by `.withErrorAlert(router:)` view modifier
  - `DebugConfig.swift` — Feature flags (showAllCapabilities)
  - `PresetHelpers.swift` — Display mapping:
    - `displayName()` for FanSpeedPreset, WaterUsagePreset, OperationMode
    - `icon()` mapping to SF Symbol names
    - Used by IntensityControlView picker

**Utilities/**
- Purpose: Additional utility functions and extensions
- Usage: Group extensions by type (Array, String, View, Date, etc.)
- Note: May be empty or sparse; use as holding area for miscellaneous helpers

**Intents/** (1 file)
- Purpose: Siri voice command and Shortcuts app integration
- File: `RobotIntents.swift` (314 lines)
  - 6 AppIntent structs: StartRobot, StopRobot, PauseRobot, SendRobotHome, CleanRooms, GoToLocation
  - 3 AppEntity types for entity resolution
  - RobotShortcuts AppShortcutsProvider for Siri phrases
- Pattern: Read RobotConfig from UserDefaults directly (not via RobotManager)
- Execution: Background without opening app

**Resources/**
- Purpose: Static assets (localization, fonts)
- Files:
  - `Localizable.xcstrings` — String catalog (152KB) supporting German (de) + English (en); 200+ keys
  - `Fonts/` — Custom font directory (exists but may be empty)
  - Asset catalogs (if any): AppIcon, Colors, Images

**ValetudoAppTests/**
- Purpose: Unit and integration tests
- Files: 4 known test classes
  - `ConsumableTests.swift` — Consumable model + display logic
  - `TimerTests.swift` — Timer model + UTC/local conversion
  - `MapLayerTests.swift` — Map rendering layers
  - `KeychainStoreTests.swift` — Secure storage operations
- Test target: Linked to main ValetudoApp target (via `@testable import`)

**.planning/codebase/**
- Purpose: Machine-generated codebase analysis documents
- Files: ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, STACK.md, INTEGRATIONS.md
- Not committed: Git history; updated per analysis run

## Key File Locations

**Entry Points:**
- `ValetudoApp/ValetudoApp.swift` — App root (@main struct), AppDelegate, notification handling, onboarding gate
- `ContentView.swift` — Tab bar router (switches between Robots, Map, Settings tabs)
- `Views/RobotListView.swift` — Primary robot list; navigation to RobotDetailView

**Configuration:**
- `Models/RobotConfig.swift` — Robot connection config structure (persisted in UserDefaults)
- `Resources/Localizable.xcstrings` — Multi-language string catalog
- `Helpers/DebugConfig.swift` — Runtime feature flags
- `.planning/config.json` — Planning tool configuration

**Core Business Logic:**
- `Services/RobotManager.swift` — Central state machine, polling, notifications
- `Services/ValetudoAPI.swift` — Complete REST API client
- `Services/SSEConnectionManager.swift` — Real-time streaming coordination
- `Services/NotificationService.swift` — Local push notification engine

**Map & Complex Visualization:**
- `Views/MapView.swift` — Interactive map with canvas rendering, gestures, zone/wall/room editing (3000+ lines)
- `ViewModels/MapViewModel.swift` — Map state management, edit modes, preset handling

**Data Persistence:**
- `Services/KeychainStore.swift` — Secure password storage
- `Models/RobotConfig.swift` — Config JSON serialization (UserDefaults)
- `Models/RobotState.swift` → `GoToPresetStore` class — Preset persistence (UserDefaults-backed ObservableObject)

**Testing:**
- `ValetudoAppTests/` — Test target; imports main app via `@testable import ValetudoApp`

## Naming Conventions

**Files:**
- Views: PascalCase + "View" (e.g., `RobotDetailView.swift`, `MapView.swift`)
- ViewModels: PascalCase + "ViewModel" (e.g., `RobotDetailViewModel.swift`)
- Models: PascalCase (e.g., `RobotConfig.swift`, `RobotState.swift`)
- Services: PascalCase + "Service"/"Manager"/"Store" (e.g., `RobotManager.swift`, `NotificationService.swift`, `KeychainStore.swift`)
- Helpers: PascalCase + "Router"/"Config"/"Helpers" (e.g., `ErrorRouter.swift`, `DebugConfig.swift`)
- Test files: ClassName + "Tests" (e.g., `KeychainStoreTests.swift`)

**Directories:**
- Plural for collections: Views/, Models/, Services/, Helpers/, Utilities/, Intents/, Resources/
- Matches Xcode project structure

**Classes/Structs:**
- Models (Codable): PascalCase (RobotConfig, RobotStatus, Segment)
- ViewModels: PascalCase + "ViewModel" (RobotDetailViewModel)
- Services: PascalCase + "Service"/"Manager" (RobotManager, NotificationService)
- Views: PascalCase + "View" (RobotListView, MapView)
- Error enums: PascalCase + "Error" or just singular (APIError)

**Functions/Methods:**
- camelCase (addRobot, refreshRobot, streamStateLines)
- Async: use `async` keyword (refreshRobot() async throws)
- Throwing: use `throws` keyword
- Predicates: `is*`, `has*` (isCleaning, hasManualControl)

**Properties:**
- camelCase (robotStates, isLoading, selectedRobotId)
- @Published: no prefix, camelCase (@Published var robots: [RobotConfig])
- Private: underscore optional, camelCase (private var _sseSession)

**Type Names:**
- Enums: PascalCase (BasicAction, StatusValue, APIError)
- Typealiases: PascalCase (Capabilities = [String])
- Associated types: PascalCase (CodingKeys)

## Where to Add New Code

**New Feature (e.g., "Mopping Mode Control"):**
1. **Models:** Add enum/struct to `Models/RobotState.swift`
   - Example: `enum MoppingMode: String, Codable { case off, light, medium, strong }`
   - Example: `struct MoppingModeRequest: Codable { let mode: String }`
2. **API Endpoint:** Add method to `Services/ValetudoAPI.swift`
   - Example: `func setMoppingMode(_ mode: MoppingMode) async throws`
   - Follow pattern: `let body = try JSONEncoder().encode(request); return try await request<EmptyResponse>(.../setMoppingMode, method: "POST", body: body)`
3. **ViewModel:** Add @Published property + method to ViewModels
   - Example: `@Published var currentMoppingMode: String?`, `func setMoppingMode(_ mode: String) async`
   - Fetch on init/appear; update on user interaction
4. **View:** Add UI controls to appropriate View file
   - Example: Picker in RobotDetailView or create new MoppingModeView.swift
   - Call viewModel.setMoppingMode() on selection change
5. **Tests:** Add test file `ValetudoAppTests/MoppingModeTests.swift`
   - Test model decoding, ViewModel logic, View integration

**New Component (e.g., "Device Selector Sheet"):**
1. **Create file:** `Views/DeviceSelectorView.swift`
2. **Pattern:** `struct DeviceSelectorView: View { @State var selection; @Binding var isPresented }`
3. **Layout:** Use List, NavigationLink, or Picker depending on use case
4. **Integration:** Present from parent via `.sheet(isPresented: $showSelector) { DeviceSelectorView(...) }`
5. **Styling:** Follow existing app color scheme and List styling

**New Utility Extension (e.g., "Array partition method"):**
1. **Location:** Create `Utilities/ArrayExtensions.swift` or add to existing
2. **Pattern:** `extension Array where Element: Comparable { func partitioned() -> (less: [Element], greater: [Element]) { ... } }`
3. **Tests:** Add test method to relevant test file
4. **Documentation:** Include comment explaining usage

**New Error Type:**
1. **Location:** Add case to APIError enum in `Services/ValetudoAPI.swift`
   - Example: `case rateLimited(Int)` for retry-after seconds
2. **Handle in throws:** Update all `throw` points where error can occur
3. **Display:** Add case to ErrorRouter error message mapping (if user-facing)

**New Background Task (e.g., "Periodic map refresh"):**
1. **Location:** Add Task spawn in `Services/RobotManager.swift` or create new service
2. **Pattern:** Create Task in init(), store reference, cancel in deinit
3. **Concurrency:** Use `@MainActor` if updating UI; use `actor` if thread-safe background work
4. **Testing:** Test task lifecycle (startup, cancellation)

**New Localized String:**
1. **Use in code:** `String(localized: "mopping_mode.label")`
2. **Xcstrings:** Xcode auto-discovers and adds key to `Resources/Localizable.xcstrings`
3. **Translate:** Open .xcstrings in editor, add German translation
4. **Plurals/Variables:** Use .strings syntax if needed (e.g., `"cleaning with \(count) zones"`)
5. **Keys:** Use hierarchical naming (feature.function, e.g., "mopping_mode.light")

**New Test:**
1. **Create file:** `ValetudoAppTests/FeatureNameTests.swift`
2. **Import:** `import XCTest` and `@testable import ValetudoApp`
3. **Setup:** Create fixtures or mock data
4. **Test methods:** Use `func test...() async throws` pattern
5. **Assertions:** XCTAssertEqual, XCTAssertTrue, XCTAssertThrowsError, etc.
6. **Cleanup:** Implement tearDown() if needed for resource cleanup

## Special Directories

**Xcode Build Artifacts:**
- `.xcodeproj/` — Project metadata (NOT source); tracks file references, build phases, schemes
- `DerivedData/` — Build outputs (NOT tracked); generated during build
- `.xcworkspace/` — Workspace file (if using CocoaPods or Swift packages)

**Generated/Not Committed:**
- Build artifacts: `Localizable.strings`, compiled `.xcassets`
- User state: `.xcworkspace/xcuserdata/`, `.xcodeproj/xcuserdata/`
- macOS metadata: `.DS_Store`
- Build directories: `Build/`, `DerivedData/`

**Committed:**
- Source code: `ValetudoApp/`
- Project config: `.xcodeproj/`, (optional) `.xcworkspace/`
- Tests: `ValetudoAppTests/`
- Analysis: `.planning/codebase/`
- Metadata: `.gitignore`, `README.md`

**Reserved/Empty (for future):**
- `Utilities/` — Planned for utility extensions/helpers
- `ViewModels/` — Currently populated with 3 ViewModels; room for expansion

---

*Structure analysis: 2026-03-28*
