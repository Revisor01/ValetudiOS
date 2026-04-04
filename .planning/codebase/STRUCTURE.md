# Codebase Structure

**Analysis Date:** 2026-04-04

## Directory Layout

```
valetudo-app/
├── .planning/                             # GSD planning documents
│   └── codebase/                          # Architecture analysis docs
├── AppStoreMetadata/                      # App Store screenshots & metadata
├── ValetudoApp/
│   ├── ValetudoApp.xcodeproj/             # Xcode project config
│   │   └── xcshareddata/xcschemes/        # Shared build schemes
│   ├── ValetudoApp/                       # Main source code
│   │   ├── ValetudoApp.swift              # @main App entry, AppDelegate
│   │   ├── ContentView.swift              # Root TabView (Robots, Map, Settings)
│   │   ├── Helpers/                       # Cross-cutting utilities
│   │   │   ├── DebugConfig.swift          # Debug feature flags
│   │   │   ├── ErrorRouter.swift          # Centralized error alert + retry
│   │   │   └── PresetHelpers.swift        # Preset display name/color mapping
│   │   ├── Intents/                       # Siri Shortcuts
│   │   │   └── RobotIntents.swift         # AppIntents entities & actions
│   │   ├── Media.xcassets/                # App icons & images
│   │   │   └── AppIcon.appiconset/
│   │   ├── Models/                        # Data structures
│   │   │   ├── Consumable.swift           # Consumable wear tracking
│   │   │   ├── RobotConfig.swift          # Robot connection config
│   │   │   ├── RobotMap.swift             # Map layers, entities, zones
│   │   │   ├── RobotState.swift           # Attributes, segments, requests
│   │   │   └── Timer.swift                # Timer scheduling model
│   │   ├── Resources/                     # Localization & fonts
│   │   │   ├── Fonts/                     # Custom font files
│   │   │   └── Localizable.xcstrings      # String catalog (de + en)
│   │   ├── Services/                      # Business logic & network
│   │   │   ├── BackgroundMonitorService.swift  # BGTask background polling
│   │   │   ├── KeychainStore.swift        # Secure credential storage
│   │   │   ├── MapCacheService.swift       # Disk-based map JSON cache
│   │   │   ├── NetworkScanner.swift        # Bonjour TCP scanner
│   │   │   ├── NotificationService.swift   # Push notification lifecycle
│   │   │   ├── NWBrowserService.swift      # Network.framework browser
│   │   │   ├── RobotManager.swift          # Central app state holder
│   │   │   ├── SSEConnectionManager.swift  # SSE streaming + reconnect
│   │   │   ├── SupportManager.swift        # StoreKit donation tracking
│   │   │   ├── UpdateService.swift         # OTA update lifecycle
│   │   │   └── ValetudoAPI.swift           # REST API client (actor)
│   │   ├── Utilities/                     # Constants & shared values
│   │   │   └── Constants.swift            # URLs, StoreKit product IDs
│   │   ├── ViewModels/                    # State management per feature
│   │   │   ├── MapViewModel.swift         # Map editing, rooms, restrictions
│   │   │   ├── RobotDetailViewModel.swift # Controls, segments, stats
│   │   │   └── RobotSettingsViewModel.swift # Robot-specific toggles
│   │   └── Views/                         # SwiftUI view components
│   │       ├── AddRobotView.swift         # Robot setup (manual + discovery)
│   │       ├── ConsumablesView.swift      # Consumable status & reset
│   │       ├── DoNotDisturbView.swift     # DND schedule config
│   │       ├── IntensityControlView.swift # Fan speed + water usage
│   │       ├── ManualControlView.swift    # Joystick movement control
│   │       ├── MapControlBarsView.swift   # Map bottom toolbar buttons
│   │       ├── MapInteractiveView.swift   # Canvas-based map rendering
│   │       ├── MapMiniMapView.swift       # Map preview (detail page)
│   │       ├── MapSheetsView.swift        # Map modal sheets (rename, preset)
│   │       ├── MapView.swift              # Map content + coordinate transforms
│   │       ├── ObstaclePhotoView.swift    # Obstacle image gallery
│   │       ├── OnboardingView.swift       # First-launch welcome flow
│   │       ├── RobotDetailSections.swift  # Reusable detail UI components
│   │       ├── RobotDetailView.swift      # Single robot control panel
│   │       ├── RobotListView.swift        # Robot list with navigation
│   │       ├── RobotSettingsSections.swift # Settings section components
│   │       ├── RobotSettingsView.swift    # Per-robot configuration
│   │       ├── RoomsManagementView.swift  # Room rename, join, split, material
│   │       ├── SettingsView.swift         # App-level settings
│   │       ├── StatisticsView.swift       # Cleaning statistics
│   │       ├── SupportReminderView.swift  # Periodic support prompt
│   │       ├── SupportView.swift          # Donation/support UI
│   │       └── TimersView.swift           # Timer scheduling
│   └── ValetudoAppTests/                  # Unit tests
│       ├── ConsumableTests.swift
│       ├── KeychainStoreTests.swift
│       ├── MapLayerTests.swift
│       ├── MapViewModelTests.swift
│       ├── RobotDetailViewModelTests.swift
│       ├── RobotSettingsViewModelTests.swift
│       ├── TimerTests.swift
│       └── ValetudoAPITests.swift
├── AppIcon.png                            # Source app icon
├── LICENSE
└── README.md
```

## Directory Purposes

**Views/ (20 files, ~7500 lines):**
- Purpose: SwiftUI view components rendering current state
- Contains: `@State` properties, navigation, layout, user interaction handling
- Key files: `RobotDetailView.swift` (1208 lines), `MapView.swift` (878 lines), `MapInteractiveView.swift` (710 lines)
- Pattern: Views receive dependencies via environment or init parameters; no direct API calls
- Split pattern: Large views have companion `*Sections.swift` files for reusable components
- Map view family: `MapView.swift` (main container + gestures), `MapInteractiveView.swift` (Canvas pixel rendering), `MapControlBarsView.swift` (toolbar), `MapSheetsView.swift` (modals), `MapMiniMapView.swift` (preview)

**ViewModels/ (3 files, ~1519 lines):**
- Purpose: State management and API orchestration for complex views
- Contains: `@Observable` properties, async methods calling API, capability detection
- Key files: `RobotSettingsViewModel.swift` (543 lines), `MapViewModel.swift` (500 lines), `RobotDetailViewModel.swift` (476 lines)
- Pattern: `@MainActor @Observable final class` receiving `robot: RobotConfig` + `robotManager: RobotManager`
- API access: `var api: ValetudoAPI? { robotManager.getAPI(for: robot.id) }`

**Models/ (5 files, ~1207 lines):**
- Purpose: Decodable data structures mirroring API responses
- Contains: Codable structs, enums, request/response types
- Key files: `RobotState.swift` (877 lines - all attribute types, request structs, enums), `RobotMap.swift` (165 lines)
- `RobotState.swift` contains: `RobotAttribute`, `RobotInfo`, `Segment`, `BasicAction`, `SegmentCleanRequest`, `GoToRequest`, zone/restriction types, statistics, MQTT/NTP config, WiFi status, quirks, events, and more
- Caching: `MapLayerCache` (reference type) for run-length decompression memoization

**Services/ (11 files, ~2879 lines):**
- Purpose: Core business logic, network I/O, system integration
- Key files: `ValetudoAPI.swift` (815 lines), `RobotManager.swift` (359 lines), `UpdateService.swift` (264 lines)
- Concurrency: `ValetudoAPI` and `SSEConnectionManager` are actors; `RobotManager`, `NotificationService`, `UpdateService`, `SupportManager` are `@MainActor @Observable`
- Singletons: `NotificationService.shared`, `BackgroundMonitorService.shared`, `MapCacheService.shared`, `SupportManager.shared`

**Helpers/ (3 files):**
- Purpose: Cross-cutting utilities and shared logic
- `ErrorRouter.swift`: Error alert + retry; injected via `@Environment(ErrorRouter.self)`
- `DebugConfig.swift`: Single `showAllCapabilities` flag to show all UI sections during development
- `PresetHelpers.swift`: `PresetHelpers` and `OperationModeHelpers` enums for display name/icon/color mapping

**Utilities/ (1 file):**
- Purpose: App-wide constants
- `Constants.swift`: GitHub API URL, Valetudo website URL, app GitHub URL, StoreKit product IDs

**Intents/ (1 file):**
- Purpose: Siri Shortcuts and App Intents
- `RobotIntents.swift` (314 lines): `RobotEntity`, `RoomEntity`, entity queries, `StartCleaningIntent`, `StopCleaningIntent`, `PauseCleaningIntent`, `ReturnToHomeIntent`, `CleanRoomIntent`

**Resources/:**
- `Localizable.xcstrings`: String catalog with German (de) and English (en) translations
- `Fonts/`: Custom font files

## Key File Locations

**Entry Points:**
- `ValetudoApp/ValetudoApp/ValetudoApp.swift`: `@main` App struct, AppDelegate, BGTask registration, scene setup
- `ValetudoApp/ValetudoApp/ContentView.swift`: Root `TabView` with 3 tabs (Robots, Map, Settings)

**Configuration:**
- `ValetudoApp/ValetudoApp/Models/RobotConfig.swift`: Robot connection metadata (host, username, SSL, ignoreCertErrors)
- `ValetudoApp/ValetudoApp/Helpers/DebugConfig.swift`: Feature flag `showAllCapabilities`
- `ValetudoApp/ValetudoApp/Utilities/Constants.swift`: App-wide constants (URLs, product IDs)
- `ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings`: All user-facing strings

**Core Logic:**
- `ValetudoApp/ValetudoApp/Services/RobotManager.swift`: Authoritative state for robots, status, APIs
- `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift`: REST + SSE client (actor)
- `ValetudoApp/ValetudoApp/Services/SSEConnectionManager.swift`: SSE lifecycle with reconnect
- `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift`: Map editing, room selection, restrictions

**Map Rendering Pipeline:**
- `ValetudoApp/ValetudoApp/Views/MapView.swift`: `MapContentView` (coordinate transforms, gesture handling, drawing overlay), `MapTabView`, `MapPreviewView`, `MapView` (sheet)
- `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift`: `InteractiveMapView` (Canvas-based pixel rendering, room tap with SpatialTapGesture, labels, order badges)
- `ValetudoApp/ValetudoApp/Views/MapControlBarsView.swift`: Bottom toolbar buttons for map actions
- `ValetudoApp/ValetudoApp/Views/MapSheetsView.swift`: Modal sheets (rename room, save preset, manage presets)
- `ValetudoApp/ValetudoApp/Views/MapMiniMapView.swift`: Small preview map used in detail view

**Robot Detail Page:**
- `ValetudoApp/ValetudoApp/Views/RobotDetailView.swift`: Main detail page (update banner, map preview, controls, rooms, stats)
- `ValetudoApp/ValetudoApp/Views/RobotDetailSections.swift`: Reusable components (`ControlButton`, `PulseAnimation`, `RobotRowView`)
- `ValetudoApp/ValetudoApp/Views/RobotSettingsView.swift`: Robot settings page (speaker, toggles, map management)
- `ValetudoApp/ValetudoApp/Views/RobotSettingsSections.swift`: Settings section components (WiFi, quirks, MQTT, NTP, device info)

**Testing:**
- `ValetudoApp/ValetudoAppTests/`: 8 test files covering API, ViewModels, models, Keychain

## Naming Conventions

**Files:**
- Views: PascalCase + "View" suffix (e.g., `RobotListView.swift`, `MapView.swift`)
- Section companions: PascalCase + "Sections" suffix (e.g., `RobotDetailSections.swift`, `RobotSettingsSections.swift`)
- ViewModels: PascalCase + "ViewModel" suffix (e.g., `MapViewModel.swift`)
- Services: PascalCase + "Manager"/"Service" suffix (e.g., `RobotManager.swift`, `UpdateService.swift`)
- Models: PascalCase, domain-specific (e.g., `RobotConfig.swift`, `RobotState.swift`)

**Code Identifiers:**
- Classes/Structs: PascalCase (`RobotManager`, `ValetudoAPI`, `RobotConfig`)
- Enums: PascalCase (`StatusValue`, `MapEditMode`, `BasicAction`, `UpdatePhase`)
- Functions/Variables: camelCase (`startCleaning()`, `getRobotName(for:)`)
- Constants: camelCase in enum namespace (`Constants.githubApiLatestReleaseUrl`)
- Private backing: underscore prefix (`_sseSession`)
- Localization keys: dot-separated lowercase (`"status.idle"`, `"map.tap_to_expand"`, `"rooms.rename"`)

## Where to Add New Code

**New Robot Capability (e.g., new Valetudo feature):**
1. **Model**: Add request/response structs to `Models/RobotState.swift` (keep all API types in one file)
2. **API**: Add methods to `Services/ValetudoAPI.swift` following existing pattern:
   ```swift
   func getNewFeature() async throws -> NewFeatureResponse {
       try await request("/robot/capabilities/NewCapability")
   }
   func setNewFeature(value: String) async throws {
       let body = try JSONEncoder().encode(["value": value])
       try await requestVoid("/robot/capabilities/NewCapability", body: body)
   }
   ```
3. **ViewModel**: Add capability flag + data property to the relevant ViewModel:
   - Control actions -> `RobotDetailViewModel`
   - Toggle settings -> `RobotSettingsViewModel`
   - Map features -> `MapViewModel`
4. **View**: Add section/row to the relevant view file
5. **Capability detection**: Add `hasFeature = capabilities.contains("FeatureCapability")` in `loadCapabilities()`

**New View/Screen:**
1. Create `Views/NewFeatureView.swift` as SwiftUI struct
2. Accept `robot: RobotConfig` and access `@Environment(RobotManager.self) var robotManager`
3. If complex state needed, create `ViewModels/NewFeatureViewModel.swift` as `@MainActor @Observable final class`
4. Wire ViewModel: `@State private var viewModel: NewFeatureViewModel` initialized in `init()`
5. Use localized strings: `String(localized: "feature.title")`
6. Add navigation from parent view (NavigationLink in detail page, or new tab)

**New View Component (reusable):**
1. If for detail page: add to `Views/RobotDetailSections.swift`
2. If for settings: add to `Views/RobotSettingsSections.swift`
3. If for map: add to `Views/MapControlBarsView.swift` or create new companion file

**New Siri Shortcut:**
1. Add Intent struct conforming to `AppIntent` in `Intents/RobotIntents.swift`
2. Implement `perform()` method loading `RobotConfig` from UserDefaults and creating `ValetudoAPI`
3. Define `ParameterSummary` for Shortcuts UI

**New Notification Type:**
1. Add category in `NotificationService.setupCategories()`
2. Add notification method in `NotificationService` (e.g., `notifyNewEvent(robotName:...)`)
3. Call from `RobotManager.checkStateChanges()` or relevant polling location

**New Test:**
- Add test file to `ValetudoApp/ValetudoAppTests/` following pattern `FeatureTests.swift`
- Test ViewModels by mocking API responses
- Test models by decoding sample JSON

## Special Directories

**Media.xcassets/:**
- Purpose: Asset catalog for app icons and images
- Generated: No (managed by Xcode)
- Committed: Yes

**build/:**
- Purpose: Xcode build artifacts
- Generated: Yes (by Xcode)
- Committed: No (.gitignore)

**ValetudoApp.xcodeproj/xcshareddata/:**
- Purpose: Shared build schemes
- Generated: No (manually configured)
- Committed: Yes

**ValetudoAppTests/:**
- Purpose: Unit tests (8 test files)
- Generated: No
- Committed: Yes

**AppStoreMetadata/:**
- Purpose: App Store screenshots and metadata
- Generated: No
- Committed: Yes

**.planning/:**
- Purpose: GSD planning and codebase analysis documents
- Generated: By Claude Code analysis
- Committed: Yes

---

*Structure analysis: 2026-04-04*
