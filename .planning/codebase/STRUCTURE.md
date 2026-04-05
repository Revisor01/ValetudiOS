# Codebase Structure

**Analysis Date:** 2026-04-04

## Directory Layout

```
ValetudoApp/
├── ValetudoApp/
│   ├── ValetudoApp.swift              # App entry point, AppDelegate
│   ├── ContentView.swift              # Root view (tab bar)
│   ├── Helpers/                       # Utilities and routing
│   │   ├── ErrorRouter.swift          # Global error handling
│   │   ├── DebugConfig.swift          # Debug feature flags
│   │   └── PresetHelpers.swift        # GoTo preset helpers
│   ├── Intents/                       # Siri Shortcuts
│   │   └── RobotIntents.swift
│   ├── Models/                        # Data structures
│   │   ├── RobotConfig.swift
│   │   ├── RobotState.swift
│   │   ├── RobotMap.swift
│   │   ├── Consumable.swift
│   │   └── Timer.swift
│   ├── Services/                      # Core business logic
│   │   ├── RobotManager.swift         # Central state container
│   │   ├── ValetudoAPI.swift          # REST API client
│   │   ├── SSEConnectionManager.swift # Real-time streaming
│   │   ├── KeychainStore.swift        # Secure storage
│   │   ├── NotificationService.swift  # Push/local notifications
│   │   ├── UpdateService.swift        # Firmware updates
│   │   ├── BackgroundMonitorService.swift
│   │   ├── MapCacheService.swift
│   │   ├── SupportManager.swift       # StoreKit
│   │   ├── NetworkScanner.swift       # MDns discovery
│   │   └── NWBrowserService.swift     # Network browsing
│   ├── Utilities/                     # Helpers
│   │   ├── Constants.swift
│   │   └── MapGeometry.swift          # Coordinate math
│   ├── ViewModels/                    # Presentation logic
│   │   ├── RobotDetailViewModel.swift
│   │   ├── MapViewModel.swift
│   │   └── RobotSettingsViewModel.swift
│   ├── Views/                         # UI components
│   │   ├── RobotListView.swift
│   │   ├── RobotDetailView.swift
│   │   ├── AddRobotView.swift
│   │   ├── MapView.swift              # Map container
│   │   ├── MapInteractiveView.swift   # Interactive map
│   │   ├── MapDrawingOverlay.swift    # Zone/wall drawing
│   │   ├── MapMiniMapView.swift
│   │   ├── MapControlBarsView.swift   # Map controls
│   │   ├── MapOverlayViews.swift
│   │   ├── MapSheetsView.swift
│   │   ├── RoomsManagementView.swift  # Room editing
│   │   ├── ConsumablesView.swift
│   │   ├── SettingsView.swift
│   │   ├── RobotSettingsView.swift
│   │   ├── TimersView.swift
│   │   ├── DoNotDisturbView.swift
│   │   ├── StatisticsView.swift
│   │   ├── ManualControlView.swift
│   │   ├── IntensityControlView.swift
│   │   ├── OnboardingView.swift
│   │   ├── SupportView.swift
│   │   ├── SupportReminderView.swift
│   │   ├── ObstaclePhotoView.swift
│   │   ├── RobotDetailSections.swift  # Composed sections
│   │   ├── Detail/                    # Detail page sections
│   │   │   ├── RobotStatusHeaderView.swift
│   │   │   ├── RobotControlSectionView.swift
│   │   │   ├── CleanRouteSectionView.swift
│   │   │   ├── RoomsSectionView.swift
│   │   │   ├── ConsumablesPreviewSectionView.swift
│   │   │   ├── EventsSectionView.swift
│   │   │   ├── ObstaclesSectionView.swift
│   │   │   ├── StatisticsSectionView.swift
│   │   │   ├── LiveStatsChipView.swift
│   │   │   ├── AttachmentChipsView.swift
│   │   │   ├── UpdateStatusBannerView.swift
│   │   │   └── UpdateOverlayView.swift
│   │   └── Settings/                  # Settings subviews
│   │       ├── WifiSettingsView.swift
│   │       ├── MQTTSettingsView.swift
│   │       ├── StationSettingsView.swift
│   │       ├── AutoEmptyDockSettingsView.swift
│   │       ├── NTPSettingsView.swift
│   │       └── QuirksView.swift
│   ├── Resources/
│   │   └── Fonts/
│   ├── Media.xcassets                 # Images, icons
│   ├── Info.plist
│   └── ValetudoApp.xcodeproj/
├── ValetudoAppTests/                  # Unit tests
├── build/                             # Xcode build artifacts
└── README.md                          # Project documentation
```

## Directory Purposes

**ValetudoApp/:**
- Purpose: Main application source code
- Contains: Swift source files, assets, localization strings
- Key files: `ValetudoApp.swift` (entry point), `ContentView.swift` (root UI), `RobotManager.swift` (state)

**Helpers/:**
- Purpose: Cross-cutting utilities
- Contains: ErrorRouter (global error handling), DebugConfig (feature flags), PresetHelpers (GoTo logic)
- Key files: `ErrorRouter.swift` (error presentation), `DebugConfig.swift` (conditional features)

**Intents/:**
- Purpose: Siri Shortcuts integration
- Contains: AppIntents for voice control
- Key files: `RobotIntents.swift`

**Models/:**
- Purpose: Data structures and Codable types
- Contains: RobotConfig, RobotState, RobotMap, Consumable, Timer
- Key files: All are direct representations of Valetudo API responses

**Services/:**
- Purpose: Business logic and system integration
- Contains: 12 service classes handling API, state, notifications, storage
- Key files:
  - `RobotManager.swift` — Single source of truth for robot data
  - `ValetudoAPI.swift` — REST client with SSL/auth support
  - `SSEConnectionManager.swift` — Streaming connection pool
  - `KeychainStore.swift` — Secure credential storage
  - `NotificationService.swift` — Push notifications and state change alerts
  - `UpdateService.swift` — Firmware update orchestration

**Utilities/:**
- Purpose: Reusable helper functions
- Contains: Constants, map coordinate math
- Key files: `MapGeometry.swift` (pixel-to-coordinate conversion), `Constants.swift` (URLs, StoreKit IDs)

**ViewModels/:**
- Purpose: Presentation logic and data binding
- Contains: 3 main observable view models
- Key files:
  - `RobotDetailViewModel.swift` — Detail page state and actions
  - `MapViewModel.swift` — Map rendering and interaction state
  - `RobotSettingsViewModel.swift` — Settings form state

**Views/:**
- Purpose: UI components
- Contains: 60+ SwiftUI View structs organized by feature
- Key files:
  - Top-level: RobotListView, RobotDetailView, AddRobotView, MapView
  - Detail/: Reusable sections for RobotDetailView
  - Settings/: Robot-specific settings screens

**Media.xcassets/:**
- Purpose: App icons and assets
- Contains: AppIcon set, any image assets

## Key File Locations

**Entry Points:**
- `ValetudoApp/ValetudoApp.swift`: App launch, AppDelegate for background tasks
- `ValetudoApp/ContentView.swift`: Tab bar root view

**Configuration:**
- `ValetudoApp/Models/RobotConfig.swift`: Robot connection details (URL, auth, SSL)
- `ValetudoApp/Utilities/Constants.swift`: GitHub API URLs, StoreKit product IDs

**Core Logic:**
- `ValetudoApp/Services/RobotManager.swift`: Central state, SSE/polling orchestration, robot lifecycle
- `ValetudoApp/Services/ValetudoAPI.swift`: REST client, JSON parsing, SSL/auth handling
- `ValetudoApp/Services/SSEConnectionManager.swift`: Real-time event streaming per robot

**State & Data:**
- `ValetudoApp/Models/RobotState.swift`: Status attributes (battery, cleaning state, etc.)
- `ValetudoApp/Models/RobotMap.swift`: Map layers, segments, pixel decompression
- `ValetudoApp/Services/MapCacheService.swift`: Map image persistence

**Testing:**
- `ValetudoAppTests/`: Unit test directory (currently minimal)

## Naming Conventions

**Files:**
- View files: `{Feature}View.swift` (e.g., `RobotListView.swift`, `MapView.swift`)
- ViewModel files: `{Feature}ViewModel.swift` (e.g., `MapViewModel.swift`)
- Service files: `{Feature}Service.swift` (e.g., `NotificationService.swift`, `UpdateService.swift`)
- Model files: Singular noun (e.g., `RobotConfig.swift`, `Consumable.swift`)
- Helper files: Descriptive name (e.g., `ErrorRouter.swift`, `PresetHelpers.swift`)

**Directories:**
- Feature-based (Views/, Services/, Models/, ViewModels/)
- Nested by feature within Views/ (Detail/, Settings/)

**Code:**
- Types: PascalCase (RobotManager, ValetudoAPI, ErrorRouter)
- Variables/parameters: camelCase (selectedRobotId, robotStates, isOnline)
- Constants: UPPER_CASE (taskIdentifier) or camelCase for enum cases
- URL paths: Quoted strings with full path (e.g., "/api/v0/robot/state")

## Where to Add New Code

**New Feature (entire flow):**
- Primary code: Create View file in `ValetudoApp/Views/{Feature}.swift`
- ViewModel: `ValetudoApp/ViewModels/{Feature}ViewModel.swift` (if complex state)
- API endpoints: Add method to `ValetudoApp/Services/ValetudoAPI.swift`
- Models: Add struct to existing `ValetudoApp/Models/{Entity}.swift` or new file
- Tests: Create `ValetudoAppTests/{Feature}Tests.swift`
- Example: New room editing feature
  - `Views/RoomsManagementView.swift` → `ViewModels/RoomsViewModel.swift` → Add API method to ValetudoAPI → Add data models → Test file

**New Component/Module:**
- Implementation: `ValetudoApp/Views/{ComponentName}.swift` for UI or `ValetudoApp/Services/{ServiceName}.swift` for logic
- If it's a sub-component of a feature: Create in that feature's directory or use a suffix (e.g., `MapMiniMapView.swift` inside Views/)
- Example: New control button
  - Add to `RobotDetailSections.swift` or create `Views/Detail/{ControlName}View.swift`

**Utilities:**
- Shared helpers: `ValetudoApp/Utilities/{HelperName}.swift`
- Example: Map coordinate conversion function → Add to `MapGeometry.swift`

**Settings/Configuration:**
- App-wide constants: `ValetudoApp/Utilities/Constants.swift`
- Feature flags: `ValetudoApp/Helpers/DebugConfig.swift`
- Robot-specific settings: Add property to `RobotConfig` struct

**Networking:**
- REST endpoints: Add method to `ValetudoAPI` as actor-isolated async function
- Streaming logic: Add to `SSEConnectionManager` (already pooled per robot)
- Request/response models: Add Codable struct to appropriate `ValetudoApp/Models/{Entity}.swift`

## Special Directories

**build/:**
- Purpose: Xcode build output (Debug, Release binaries and metadata)
- Generated: Yes
- Committed: No (.gitignore)

**Media.xcassets/:**
- Purpose: Image and icon assets
- Generated: No (user-created)
- Committed: Yes

**ValetudoApp.xcodeproj/:**
- Purpose: Xcode project metadata (build settings, schemes, workspace)
- Generated: Partially (some user data like xcschemes)
- Committed: Xcshareddata (schemes), project.pbxproj; xcuserdata ignored

## Localization

**Structure:**
- Strings are defined inline using `String(localized: "key")` syntax
- Localization files are generated by Xcode and stored in project bundle
- Supported languages: German (de), English (en)
- Per-language folders: `build/.../de.lproj/`, `build/.../en.lproj/`

## Dependencies

**SwiftUI Framework:**
- Uses: @State, @Environment, @Observable, @MainActor
- Located: Standard Apple framework (iOS 17+)

**Network Framework:**
- URLSession (standard) for REST and SSE
- Network framework for mDNS discovery (NWBrowser)

**Local Storage:**
- UserDefaults for robot list and settings
- Keychain (via KeychainStore) for passwords
- FileSystem for map cache (MapCacheService)

**Notifications:**
- UserNotifications framework for push/local notifications
- BackgroundTasks for background refresh scheduling

**StoreKit:**
- Used by SupportManager for in-app purchases

---

*Structure analysis: 2026-04-04*
