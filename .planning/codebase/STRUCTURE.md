# Codebase Structure

**Analysis Date:** 2026-03-28

## Directory Layout

```
ValetudoApp/
├── ValetudoApp/
│   ├── ValetudoApp.swift               # App entry point, AppDelegate, scene setup
│   ├── ContentView.swift               # Tab bar root view (Robots, Map, Settings tabs)
│   ├── Resources/                      # Fonts, localization strings
│   │   ├── Localizable.xcstrings       # String localization (German + English)
│   │   └── Fonts/                      # Custom fonts
│   ├── Views/                          # SwiftUI view components
│   │   ├── RobotListView.swift         # List of all robots
│   │   ├── RobotDetailView.swift       # Single robot control panel
│   │   ├── MapView.swift               # Map rendering + editing (zones, walls, go-to)
│   │   ├── SettingsView.swift          # App-level settings
│   │   ├── RobotSettingsView.swift     # Per-robot configuration
│   │   ├── OnboardingView.swift        # First-launch flow
│   │   ├── AddRobotView.swift          # Manual robot setup or discovery
│   │   ├── ConsumablesView.swift       # Consumable status display
│   │   ├── TimersView.swift            # Timer scheduling UI
│   │   ├── ManualControlView.swift     # Joystick-style movement control
│   │   ├── RoomsManagementView.swift   # Room/segment rename + split
│   │   ├── StatisticsView.swift        # Cleaning stats display
│   │   ├── DoNotDisturbView.swift      # DND schedule configuration
│   │   ├── IntensityControlView.swift  # Fan speed + water usage presets
│   │   ├── ObstaclePhotoView.swift     # Obstacle image gallery
│   │   ├── SupportView.swift           # App support/donation UI
│   │   └── SupportReminderView.swift   # Periodic support prompt modifier
│   ├── ViewModels/                     # State management per feature
│   │   ├── MapViewModel.swift          # Map editing, restrictions, go-to presets
│   │   ├── RobotDetailViewModel.swift  # Cleaning actions, stats, consumables
│   │   └── RobotSettingsViewModel.swift# Per-robot toggle settings
│   ├── Models/                         # Data structures
│   │   ├── RobotConfig.swift           # Robot connection config (host, auth)
│   │   ├── RobotState.swift            # API response models (RobotAttribute, RobotStatus)
│   │   ├── RobotMap.swift              # Map layers, entities, decompression
│   │   ├── Timer.swift                 # Timer scheduling model
│   │   └── Consumable.swift            # Consumable wear tracking
│   ├── Services/                       # Core business logic + network layer
│   │   ├── ValetudoAPI.swift           # REST API client (actor, handles all HTTP + SSE)
│   │   ├── RobotManager.swift          # App state holder (robots config, status, SSE lifecycle)
│   │   ├── SSEConnectionManager.swift  # SSE streaming with reconnect (actor)
│   │   ├── NotificationService.swift   # Push notification lifecycle + handling
│   │   ├── NetworkScanner.swift        # Bonjour device discovery
│   │   ├── NWBrowserService.swift      # Network.framework browser service
│   │   ├── KeychainStore.swift         # Secure credential storage
│   │   └── SupportManager.swift        # Support/donation state
│   ├── Helpers/                        # Utilities + UI extensions
│   │   ├── ErrorRouter.swift           # Error alert + retry modal
│   │   ├── DebugConfig.swift           # Debug flags (showAllCapabilities)
│   │   └── PresetHelpers.swift         # Preset parsing utilities
│   ├── Intents/                        # Siri Shortcuts support
│   │   └── RobotIntents.swift          # AppIntents (RobotEntity, RoomEntity)
│   └── Media.xcassets/                 # App icons + images
│       └── AppIcon.appiconset/         # App icon variants
├── ValetudoAppTests/                   # Unit/integration tests
└── ValetudoApp.xcodeproj/              # Xcode project config
    └── xcshareddata/                   # Shared schemes for CI
```

## Directory Purposes

**Views:**
- Purpose: SwiftUI components rendering current state
- Contains: @State properties, navigation, layout, user interaction handling
- Key files: `RobotListView.swift`, `MapView.swift`, `RobotDetailView.swift`
- Pattern: Views receive injected dependencies (robotManager, viewModel) via parameters or environment
- Localization: All user text via String(localized: "key") using Localizable.xcstrings

**ViewModels:**
- Purpose: State management and API orchestration for complex views
- Contains: @Published properties, methods handling user actions
- Key files: `MapViewModel.swift` (largest, ~800 lines), `RobotDetailViewModel.swift`, `RobotSettingsViewModel.swift`
- Pattern: @MainActor class with computed property accessing api via robotManager.getAPI(for:)
- Naming: ViewModel suffix, specific to view domain (not generic "AppViewModel")

**Models:**
- Purpose: Decodable data structures mirroring API responses or internal domain
- Contains: Codable structs, enums, hashable identifiers
- Key files: `RobotState.swift` (enums, attributes), `RobotMap.swift` (map rendering data)
- Caching: MapLayer uses MapLayerCache (reference type) for run-length decompression
- Backward compatibility: RobotConfig custom Codable to handle legacy saved data

**Services:**
- Purpose: Stateful services and cross-cutting concerns
- Contains: Network I/O, state management, system integration
- Core: `ValetudoAPI` (actor), `RobotManager` (@MainActor), `SSEConnectionManager` (actor)
- Support: `NotificationService` (push lifecycle), `NetworkScanner` (mDNS discovery)
- Storage: `KeychainStore` (password vault), `SupportManager` (donation tracking)
- Lifecycle: RobotManager singleton created in App.init, passed via environment

**Helpers:**
- Purpose: Utilities and cross-cutting view extensions
- Contains: ErrorRouter (error UI), DebugConfig (feature flags), PresetHelpers (parsing)
- Error handling: withErrorAlert(router:) modifier attached to ContentView root
- Extensions: View extension for supportReminder() modifier

**Intents:**
- Purpose: Siri Shortcuts and AppIntents integration
- Contains: Entity definitions (RobotEntity, RoomEntity), EntityQuery implementations
- Access: Load RobotConfig from UserDefaults same way RobotManager does
- Limitation: Currently requires manual loading (not tied to live RobotManager)

**Resources:**
- Purpose: Localization and static assets
- Localizable.xcstrings: Stringsdict format supporting 1) German (de) 2) English (en) pluralization
- Fonts: Any custom fonts in Fonts/ directory
- Images: Media.xcassets for app icons, asset catalog organization

## Key File Locations

**Entry Points:**
- `ValetudoApp/ValetudoApp/ValetudoApp.swift`: App struct with @main, AppDelegate, scene setup, onboarding check
- `ValetudoApp/ValetudoApp/ContentView.swift`: Root TabView (Robots tab, Map tab if selected, Settings tab)

**Configuration:**
- `ValetudoApp/ValetudoApp/Models/RobotConfig.swift`: Robot connection metadata (host, username, SSL settings)
- `ValetudoApp/ValetudoApp/Helpers/DebugConfig.swift`: Feature flag showAllCapabilities (overrides API capability response)
- `ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings`: All user-facing strings

**Core Logic:**
- `ValetudoApp/ValetudoApp/Services/RobotManager.swift`: App state holder (robots array, status dict, API instances)
- `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift`: REST API client (request(), getState(), streamStateLines(), etc.)
- `ValetudoApp/ValetudoApp/Services/SSEConnectionManager.swift`: SSE lifecycle with exponential backoff reconnect
- `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift`: Map rendering state + drawing/restriction management

**Networking & Persistence:**
- `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift`: Thread-safe actor handling all HTTP
- `ValetudoApp/ValetudoApp/Services/KeychainStore.swift`: Password storage (never in UserDefaults)
- `ValetudoApp/ValetudoApp/Services/NetworkScanner.swift`: Bonjour discovery for robot auto-detection

**Notifications:**
- `ValetudoApp/ValetudoApp/Services/NotificationService.swift`: Push notification scheduling and action routing
- `ValetudoApp/ValetudoApp/ValetudoApp.swift`: AppDelegate.userNotificationCenter(didReceive:) intercepts responses
- Flow: Notification action → AppDelegate → NotificationService.handleNotificationResponse → robotManager state change

**Siri & Intents:**
- `ValetudoApp/ValetudoApp/Intents/RobotIntents.swift`: RobotEntity, RoomEntity, EntityQuery implementations

## Naming Conventions

**Files:**
- Views: PascalCase + "View" suffix (e.g., `RobotListView.swift`, `MapView.swift`)
- ViewModels: PascalCase + "ViewModel" suffix (e.g., `MapViewModel.swift`)
- Services/Managers: PascalCase + optional "Manager"/"Service" suffix (e.g., `RobotManager.swift`, `NotificationService.swift`)
- Models: PascalCase, domain-specific (e.g., `RobotConfig.swift`, `RobotState.swift`)
- Helpers: PascalCase, descriptive (e.g., `ErrorRouter.swift`, `DebugConfig.swift`)

**Code Identifiers:**
- Classes/Structs: PascalCase (e.g., `RobotManager`, `ValetudoAPI`, `RobotConfig`)
- Enums: PascalCase (e.g., `StatusValue`, `MapEditMode`, `BasicAction`)
- Functions/Variables: camelCase (e.g., `startCleaning()`, `getRobotName(for:)`)
- Constants: camelCase (e.g., `storageKey = "valetudo_robots"`)
- Published properties: camelCase (e.g., `@Published var robotStates: [UUID: RobotStatus]`)
- Private properties: camelCase with underscore prefix for backing storage (e.g., `_sseSession`)

**URL Patterns:**
- API endpoints: snake_case paths (e.g., `/api/v2/robot/state`, `/api/v2/segments`)
- Notification IDs: snake_case prefix (e.g., `"cleaning_complete_\(UUID())"`)

## Where to Add New Code

**New Feature (e.g., new robot capability):**
1. **Model**: Add Codable struct to `Models/RobotState.swift` or create new model file
2. **API**: Add method to `Services/ValetudoAPI.swift` actor (e.g., func getNewCapability() async throws -> Type)
3. **ViewModel**: If UI-heavy, create `ViewModels/FeatureViewModel.swift`; else add @Published properties to existing ViewModel
4. **View**: Create `Views/FeatureView.swift` receiving viewModel and robotManager via parameters
5. **Integration**: Wire in parent view (e.g., add tab or sheet to `RobotDetailView.swift`)

**New API Endpoint:**
1. Add method to `Services/ValetudoAPI.swift`:
   ```swift
   func getNewData() async throws -> NewDataModel {
       let result: NewDataModel = try await request("/endpoint", method: "GET")
       return result
   }
   ```
2. Call from ViewModel via `api?.getNewData()`
3. Bind result to @Published property
4. Render in View

**New View/Screen:**
1. Create `Views/NewFeatureView.swift` as SwiftUI struct
2. Receive injected dependencies: `let robot: RobotConfig`, `@EnvironmentObject var robotManager: RobotManager`
3. Instantiate ViewModel if needed: `@StateObject private var viewModel = NewFeatureViewModel(...)`
4. Use localized strings: `String(localized: "feature.title")`
5. Add to navigation or tab from parent view

**Notification Handling:**
1. Define action identifier in `NotificationService.setupCategories()` (e.g., `"ROBOT_ACTION"`)
2. Add action button in notification content (e.g., `content.categoryIdentifier = "CLEANING_COMPLETE"`)
3. Implement handler in `NotificationService.handleNotificationResponse(actionIdentifier:)` to dispatch robot action
4. AppDelegate.userNotificationCenter(didReceive:) routes to NotificationService

**Siri Shortcut:**
1. Define AppEntity in `Intents/RobotIntents.swift` (struct conforming to AppEntity)
2. Implement EntityQuery for async entity lookup
3. Define Intent action using @AppIntent macro
4. Test in Siri or Shortcuts app

## Special Directories

**Media.xcassets:**
- Purpose: Asset catalog for images and app icons
- Generated: No (managed by Xcode)
- Committed: Yes (essential for app branding)

**build/ and .build/:**
- Purpose: Xcode build artifacts
- Generated: Yes (by Xcode during build)
- Committed: No (.gitignore)

**ValetudoApp.xcodeproj/xcshareddata/:**
- Purpose: Shared build schemes for Xcode Cloud CI
- Generated: No (manually configured)
- Committed: Yes (CI depends on these)

**ValetudoAppTests/:**
- Purpose: Unit and integration tests
- Generated: No (manually written)
- Committed: Yes (test suite)

---

*Structure analysis: 2026-03-28*
