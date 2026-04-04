# Technology Stack

**Analysis Date:** 2026-04-04

## Languages

**Primary:**
- Swift 5.9 - All application code (`ValetudoApp/ValetudoApp/**/*.swift`)

**Secondary:**
- YAML - XcodeGen project definition (`ValetudoApp/project.yml`)
- JSON - String Catalog localization (`ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings`)

## Runtime

**Environment:**
- iOS 17.0+ (minimum deployment target)
- Xcode 15.0+ (required, specified in `ValetudoApp/project.yml`)

**Package Manager:**
- No external package dependencies whatsoever (zero third-party libraries)
- No SPM `Package.swift`, no CocoaPods, no Carthage

## Frameworks

**UI:**
- SwiftUI - All views (`ValetudoApp/ValetudoApp/Views/*.swift`, `ValetudoApp/ValetudoApp/ContentView.swift`)
- Canvas API (SwiftUI) - Map rendering in `ValetudoApp/ValetudoApp/Views/MapView.swift` and `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift`
- SpatialTapGesture - Room selection by tapping on map regions

**State Management:**
- Observation framework (`@Observable` macro) - All service classes and ViewModels
- `@ObservationIgnored` for non-tracked properties (timers, tasks, delegates)
- `@AppStorage` - UserDefaults-backed preferences
- `@Environment` - SwiftUI environment injection for `RobotManager`, `ErrorRouter`
- Note: Combine / `@Published` / `ObservableObject` are NOT used; the codebase uses iOS 17's `@Observable` exclusively

**Networking:**
- URLSession - All HTTP communication with Valetudo REST API (`ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift`)
- URLSession.AsyncBytes - SSE streaming for real-time state and map updates
- Custom `SSLSessionDelegate` - Self-signed certificate support

**Network Discovery:**
- Network framework (`NWBrowser`) - Bonjour/mDNS robot discovery (`ValetudoApp/ValetudoApp/Services/NWBrowserService.swift`)
- Subnet IP scanning as fallback (`ValetudoApp/ValetudoApp/Services/NetworkScanner.swift`)

**Security:**
- Security framework (Keychain Services) - Robot password storage (`ValetudoApp/ValetudoApp/Services/KeychainStore.swift`)

**Background & Notifications:**
- BackgroundTasks (`BGAppRefreshTask`) - Background robot monitoring (`ValetudoApp/ValetudoApp/Services/BackgroundMonitorService.swift`)
- UserNotifications - Local push notifications (`ValetudoApp/ValetudoApp/Services/NotificationService.swift`)

**App Store:**
- StoreKit 2 - In-app tip jar (`ValetudoApp/ValetudoApp/Services/SupportManager.swift`)

**Siri:**
- AppIntents - Siri Shortcuts for robot control (`ValetudoApp/ValetudoApp/Intents/RobotIntents.swift`)
- Uses `AppEntity`, `EntityQuery`, and `AppIntent` protocol implementations

**Logging:**
- os.Logger - Structured logging in every service with subsystem/category pattern

**Testing:**
- XCTest - Unit tests (`ValetudoApp/ValetudoAppTests/`)

## Build System

**Project Generation:**
- XcodeGen generates `.xcodeproj` from `ValetudoApp/project.yml`
- Run `xcodegen generate` in `ValetudoApp/` after changing project structure or adding files
- Generated output: `ValetudoApp/ValetudoApp.xcodeproj/`

**Build Configuration:**
- Bundle ID: `de.simonluthe.ValetudiOS`
- Display name: `ValetudiOS`
- Marketing version: `2.1.0` (in `project.yml`; latest milestone is v2.2.0 per git tags)
- Development Team: `J459G9CJT5`

**Test Target:**
- `ValetudoAppTests` (bundle ID: `de.simonluthe.ValetudiOSTests`)
- Configured as hosted unit test (`TEST_HOST` pointing to app binary)

## Key Dependencies

**All Apple first-party, zero third-party:**

| Framework | Purpose | Key Files |
|-----------|---------|-----------|
| SwiftUI | UI rendering, Canvas map drawing | `Views/*.swift` |
| Observation | `@Observable` state management | All services, ViewModels |
| Foundation | URLSession, JSON, UserDefaults | `Services/ValetudoAPI.swift` |
| Network | mDNS robot discovery | `Services/NWBrowserService.swift` |
| Security | Keychain password storage | `Services/KeychainStore.swift` |
| UserNotifications | Local notifications | `Services/NotificationService.swift` |
| BackgroundTasks | BGAppRefreshTask | `Services/BackgroundMonitorService.swift` |
| StoreKit | In-app purchases | `Services/SupportManager.swift` |
| AppIntents | Siri Shortcuts | `Intents/RobotIntents.swift` |
| os | Structured logging | All services |

## Configuration

**Per-Robot Configuration:**
- Stored as JSON array in UserDefaults key `valetudo_robots`
- Model: `RobotConfig` in `ValetudoApp/ValetudoApp/Models/RobotConfig.swift`
- Fields: id (UUID), name, host, username, useSSL, ignoreCertificateErrors
- Passwords stored separately in Keychain (never serialized to UserDefaults)

**App Preferences (via @AppStorage):**
- `hasCompletedOnboarding` - Onboarding flow completed
- `notify_cleaning_complete`, `notify_robot_error`, `notify_robot_stuck`, `notify_consumable_low`, `notify_robot_offline` - Notification toggles
- `supportReminderShown`, `hasSupported`, `appLaunchCount` - Support/tip tracking
- GoTo presets: UserDefaults key `goToPresets` (JSON array of `GoToPreset`)

**Map Cache:**
- Documents directory: `MapCache/<robotUUID>.json`
- Managed by `ValetudoApp/ValetudoApp/Services/MapCacheService.swift`

## Platform Requirements

**Development:**
- macOS with Xcode 15.0+
- XcodeGen installed (`brew install xcodegen`)
- Swift 5.9+ compiler

**Production:**
- iOS 17.0+ (iPhone and iPad)
- iPhone orientations: Portrait, Landscape Left, Landscape Right
- iPad orientations: All four
- `UIRequiresFullScreen: true`
- Local network access required (Bonjour `_valetudo._tcp` service)
- Background App Refresh capability

**Concurrency Model:**
- `actor` keyword for thread-safe API clients: `ValetudoAPI`, `SSEConnectionManager`
- `@MainActor` for UI-bound classes: `RobotManager`, `NetworkScanner`, `NWBrowserService`, `NotificationService`, `SupportManager`, `UpdateService`
- Structured concurrency with `Task`, `TaskGroup`, `async/await` throughout

**StoreKit Product IDs:**
- `de.godsapp.valetudoapp.support.small`
- `de.godsapp.valetudoapp.support.medium`
- `de.godsapp.valetudoapp.support.large`
- Defined in `ValetudoApp/ValetudoApp/Utilities/Constants.swift`

---

*Stack analysis: 2026-04-04*
