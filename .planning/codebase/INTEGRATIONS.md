# External Integrations

**Analysis Date:** 2026-04-04

## APIs & External Services

**Valetudo REST API:**
- Valetudo Robot API - Remote control, status, configuration
  - Client: `ValetudoAPI` actor (custom URLSession-based)
  - Auth: HTTP Basic Authentication (optional username/password)
  - Endpoint: `/api/v2/*` on robot's local IP/hostname
  - SSL: Supports self-signed certificates with optional certificate verification bypass

**Network Discovery:**
- Bonjour/mDNS (`_valetudo._tcp`) - Robot auto-discovery
  - Framework: Network framework with NWBrowser
  - Service: `NWBrowserService` in `ValetudoApp/Services/NWBrowserService.swift`
  - Fallback: IP address scanning for networks without mDNS support

## Data Storage

**Local Storage:**
- iOS UserDefaults - App settings and preferences
  - Keys: `hasCompletedOnboarding`, `notify_*` preferences
  - Storage: `AppStorage` wrapper in SwiftUI

**Keychain Storage:**
- iOS Security framework Keychain - Sensitive credential storage
  - Service: `com.valetudio.robot.password`
  - Service: `com.valetudio.robot.config`
  - Implementation: `KeychainStore` (static methods)
  - Location: `ValetudoApp/Services/KeychainStore.swift`
  - Access: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (device-locked encryption)
  - Stored Data: Robot passwords, robot configurations (RobotConfig Codable)

**Local Files:**
- Map cache: `MapCacheService` (image caching)
  - Purpose: Cache robot map images to reduce API calls
  - Location: `ValetudoApp/Services/MapCacheService.swift`

## Authentication & Identity

**Auth Provider:**
- Custom HTTP Basic Authentication
  - Implementation: Robot-side only (no external auth service)
  - Credentials storage: Keychain
  - Flow: Optional username/password per robot config
  - Header injection in `ValetudoAPI.request()` method

**No External Identity Services:**
- No OAuth, SSO, or third-party authentication
- No user accounts or cloud sync
- All authentication is local per-device

## Real-Time Communication

**Server-Sent Events (SSE):**
- Valetudo SSE endpoint: `/api/v2/robot/state/attributes/subscribe`
  - Manager: `SSEConnectionManager` actor
  - Purpose: Real-time robot state updates (battery, cleaning status, etc.)
  - Connection: Persistent HTTP connection with infinite timeout
  - Reconnection: Exponential backoff (1s → 5s → 30s)
  - Data format: JSON lines (newline-delimited JSON)
  - Location: `ValetudoApp/Services/SSEConnectionManager.swift`

## Notifications & Monitoring

**Local Push Notifications:**
- Framework: UserNotifications
  - Service: `NotificationService` (shared singleton)
  - Categories: `ROBOT_ERROR`, `ROBOT_STUCK`, `CLEANING_COMPLETE`, `CONSUMABLE_LOW`, `ROBOT_OFFLINE`
  - Actions: "Go Home" and "Locate" robot
  - Location: `ValetudoApp/Services/NotificationService.swift`
  - User Preferences: Stored in AppStorage with keys `notify_*`

**Logging:**
- Framework: os (OSLog)
  - Subsystem: Bundle identifier (`de.simonluthe.ValetudiOS`)
  - Categories: Robot-specific (RobotManager, API, SSE, etc.)
  - Destination: System log (Xcode console, device logs)

## Background Operations

**Background App Refresh:**
- Framework: BackgroundTasks
  - Identifier: `de.simonluthe.ValetudiOS.backgroundRefresh`
  - Manager: `BackgroundMonitorService`
  - Purpose: Periodic background monitoring in low-power scenarios
  - Location: `ValetudoApp/Services/BackgroundMonitorService.swift`
  - Scheduling: Triggered on app backgrounding via scenePhase observer

## CI/CD & Deployment

**Hosting:**
- Apple App Store (intended) - Not yet available as of README
- Manual distribution via Xcode for testing

**Version Management:**
- Marketing Version: 2.1.0
- Build Number: 1
- Git tags for releases

**No External CI/CD:**
- No GitHub Actions, GitLab CI, or similar detected
- Manual build and distribute workflow via Xcode

## URL Scheme & Deep Linking

**None Detected:**
- No custom URL schemes configured
- No app links or universal links
- No webhook/callback URLs

## External Libraries

**None:**
- Swift Package Manager (SPM) not used
- CocoaPods not used
- No third-party dependencies
- 100% native iOS frameworks only

## Environment Configuration

**Required Robot Configuration:**
- Robot hostname or IP address (e.g., `192.168.1.100` or `valetudo.local`)
- Optional: Username for HTTP Basic Auth
- Optional: Password for HTTP Basic Auth (stored in Keychain)
- Optional: SSL/HTTPS toggle with certificate verification control

**Runtime Permissions:**
- Local Network Access - `NSLocalNetworkUsageDescription`
- Notification Permissions - Requested at runtime via `requestAuthorization()`

**No Environment Variables:**
- No `.env` files or external configuration
- All robot config stored locally in Keychain

## Data Flow

**Robot Connection Lifecycle:**

1. User enters robot details (hostname, credentials)
2. `RobotConfig` stored in Keychain via `KeychainStore.saveRobotConfig()`
3. `RobotManager` creates `ValetudoAPI` instance with URLSession
4. API performs HTTP Basic Auth on each request if credentials present
5. SSE stream established to `/api/v2/robot/state/attributes/subscribe`
6. State updates streamed as JSON lines, decoded into `RobotAttribute` models
7. Updates flow via SwiftUI Observable to UI views
8. Notifications triggered based on state changes

---

*Integration audit: 2026-04-04*
