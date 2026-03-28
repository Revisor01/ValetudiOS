# External Integrations

**Analysis Date:** 2026-03-28

## APIs & External Services

**Valetudo REST API:**
- Protocol: HTTP/HTTPS
- Base Path: `/api/v2` (relative to robot's baseURL)
- Authentication: Basic Auth (username:password)
- Purpose: Full robot control, status updates, configuration management
  - SDK/Client: Custom `ValetudoAPI` actor at `ValetudoApp/Services/ValetudoAPI.swift`
  - Endpoints handled:
    - `/status` - Robot status (battery, mode, state)
    - `/segments` - Room/zone definitions
    - `/consumables` - Filter, brush, sensor wear
    - `/timers` - Scheduled cleaning
    - `/map` - Current cleaning map
    - `/capabilities` - Robot feature detection
    - `/statistics` - Cleaning statistics
    - `/dnd` - Do-Not-Disturb configuration
    - `/preferences` - Fan speed, water usage presets
    - Control actions: `/action` (clean, pause, stop, home)
    - Advanced: `/clean/segment`, `/go/to` (GoTo), `/locate`, `/speaker`

**Server-Sent Events (SSE):**
- Endpoint: `/api/v2/status/stream` (GET)
- Purpose: Real-time robot state updates (attributes streaming)
- Implementation: `SSEConnectionManager` actor at `ValetudoApp/Services/SSEConnectionManager.swift`
- Data format: `data: [RobotAttribute]` JSON lines
- Connection: Infinite timeout URLSession, auto-reconnect with exponential backoff
- Delivers to: `onAttributesUpdate` callback for state mutations

## Data Storage

**Local Storage:**
- **Type:** On-device only (no cloud)
- **Robots Config:** Persisted in JSON via `UserDefaults` (key: `valetudo_robots`)
  - Each robot: UUID, name, hostname/IP, port, SSL setting, username
  - Location: `RobotManager.loadRobots()` / `saveRobots()` in `ValetudoApp/Services/RobotManager.swift`

- **Credentials:** iOS Keychain (Security framework)
  - Service ID: `com.valetudio.robot.password`
  - Stored by robot UUID
  - Location: `KeychainStore.swift`
  - Access level: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`

- **User Preferences:** SwiftUI AppStorage
  - Settings keys: `hasCompletedOnboarding`, `notify_cleaning_complete`, `notify_robot_error`, `notify_robot_stuck`, `notify_consumable_low`, `notify_robot_offline`
  - Backed by iOS UserDefaults

## Authentication & Identity

**Auth Type:** Basic Authentication (HTTP)

**Implementation:**
- Username + password per robot
- Location: `ValetudoAPI.swift` lines 90-96 (request headers)
- Password retrieval: `KeychainStore.password(for: config.id)`
- Header format: `Authorization: Basic base64(username:password)`

**SSL/TLS:**
- Custom SSLSessionDelegate at `ValetudoApp/Services/ValetudoAPI.swift` lines 65-75
- Accepts self-signed certificates when `config.ignoreCertificateErrors = true`
- URLSession delegates certificate validation bypass for development/local networks

## Network Discovery

**mDNS/Bonjour:**
- Service Type: `_valetudo._tcp.local.`
- Browser: `NWBrowserService` at `ValetudoApp/Services/NWBrowserService.swift`
- TXT Record Keys Parsed:
  - `friendlyName` - Display name for robot
  - `model` - Hardware model identifier
- Framework: Network.framework (NWBrowser)
- Usage: Automatic robot discovery on local network during onboarding

## Notifications

**Push Notification Categories:**

1. `CLEANING_COMPLETE` - Task completed actions
2. `ROBOT_ERROR` - Critical error alerts
3. `ROBOT_STUCK` - Robot stuck notifications
4. `CONSUMABLE_LOW` - Maintenance warnings
5. `ROBOT_OFFLINE` - Connectivity loss alerts

**Implementation:** `NotificationService` at `ValetudoApp/Services/NotificationService.swift`
- Framework: UserNotifications (UNUserNotificationCenter)
- Content: Title, body, sound, badges
- User opt-in: Preference toggles in app settings (AppStorage-backed)
- Permissions: Requested at app launch

## Monitoring & Observability

**Error Tracking:**
- Manual error handling via `ErrorRouter` at `ValetudoApp/Helpers/ErrorRouter.swift`
- Display via `.withErrorAlert()` view modifier (custom SwiftUI extension)
- No external error service (e.g., Sentry, Firebase Crashlytics)

**Logs:**
- Framework: os.Logger (Apple unified logging)
- Subsystem: Bundle identifier (e.g., `com.valetudio`)
- Categories: "API", "SSE", "mDNS", "RobotManager", "Notifications"
- Visibility: Console + Console.app on device
- No external logging pipeline

## Siri Shortcuts & Intents

**Shortcuts Support:**
- Intents defined at `ValetudoApp/Intents/RobotIntents.swift`
- Custom Siri commands for robot actions
- Deep linking to app views with parameters

## CI/CD & Deployment

**Hosting:**
- App Store (planned, not yet live)
- Ad-hoc builds via Xcode

**Build System:**
- XcodeGen generates .xcodeproj from `project.yml`
- Target: ValetudoApp + ValetudoAppTests
- Code signing: Team ID J459G9CJT5 (Simon Luthe's Apple Developer account)
- Bundle ID: `de.simonluthe.ValetudiOS` (released), `de.simonluthe.ValetudoApp` (development)

**CI Pipeline:**
- Xcode Cloud (detected in recent commits: ci/xcode-cloud configuration)
- Automatic code signing via Xcode Cloud
- Test target: ValetudoAppTests

## Environment Configuration

**Required env vars:**
- None hardcoded. All configuration via in-app UI:
  - Robot IP/hostname: User input in `AddRobotView.swift`
  - Port: User input (default 80 for HTTP, 443 for HTTPS)
  - Username/Password: User input with Keychain encryption
  - SSL toggle: User choice in robot settings

**App Settings Persisted:**
- Notification preferences (AppStorage)
- Completed onboarding flag
- Robot list + metadata

## Webhooks & Callbacks

**Incoming:** None (pull-based architecture via REST + SSE)

**Outgoing:** 
- Siri Shortcuts (app can be invoked with custom parameters)
- Local notifications to device (no external callbacks)

---

*Integration audit: 2026-03-28*
