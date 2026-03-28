# External Integrations

**Analysis Date:** 2026-03-28

## APIs & External Services

**Valetudo Robot API:**
- Service: Valetudo 2024.06.0+ (local network vacuum robot)
- What it's used for: Robot control, status polling, consumable tracking, map rendering
  - SDK/Client: Custom `ValetudoAPI` actor in `Services/ValetudoAPI.swift`
  - Base endpoint: `/api/v2/*` (REST API)
  - Auth: Basic HTTP authentication (optional)
    - Credentials stored in Keychain, retrieved per-request
    - Header: `Authorization: Basic <base64(username:password)>`
  - Protocol: HTTP/HTTPS with self-signed certificate support via `SSLSessionDelegate`
  - Session configuration:
    - Standard requests: 10s timeout (request), 30s timeout (resource)
    - SSE requests: infinite timeout for streaming

**Valetudo Robot Streaming:**
- Service: Valetudo SSE endpoint
- What it's used for: Real-time robot state updates via Server-Sent Events
  - Endpoint: `/api/v2/robot/state/stream`
  - Manager: `SSEConnectionManager` actor in `Services/SSEConnectionManager.swift`
  - Connection handling: Per-robot task management with auto-reconnect
  - Backoff strategy: Exponential retry with maximum of 5 attempts
  - Decoding: JSON events parsed as `[RobotAttribute]` updates
  - State: Tracks connection per robot via `isConnected[UUID]` dictionary

## Data Storage

**Databases:**
- None — app is stateless for runtime data
- All configuration stored locally on device (see below)

**File Storage:**
- Local filesystem only — no cloud storage
- Uses iOS sandbox directory structure

**Local Storage:**
- **Configuration:**
  - Robot configs: Stored as JSON in UserDefaults under key `valetudo_robots`
    - Structure: Array of `RobotConfig` (id, name, host, username, useSSL, ignoreCertificateErrors)
    - Persistence handled by `RobotManager` in `Services/RobotManager.swift`

- **Credentials:**
  - Passwords: iOS Keychain via `Services/KeychainStore.swift`
    - Service: `com.valetudio.robot.password`
    - Account: Robot UUID string
    - Accessibility: `.whenUnlockedThisDeviceOnly`

- **User Preferences:**
  - Notification settings (via @AppStorage):
    - `notify_cleaning_complete`, `notify_robot_error`, `notify_robot_stuck`, `notify_consumable_low`, `notify_robot_offline`
  - Onboarding state: `hasCompletedOnboarding`
  - Support tracking: `supportReminderShown`, `hasSupported`, `appLaunchCount`

**Caching:**
- In-memory: Robot states cached in `RobotManager.robotStates[UUID: RobotStatus]`
- In-memory: Last consumable check timestamps in `lastConsumableCheck[UUID: Date]`
- No persistent cache — data refreshed on next connection

## Authentication & Identity

**Auth Provider:**
- Custom — HTTP Basic Auth (optional, robot-configured)
  - Implementation: Per-request credentials in `ValetudoAPI.request()` method
  - Credentials retrieved from Keychain if username provided
  - Robot can be configured with or without authentication

**No Third-Party Authentication:**
- No OAuth, no external identity providers
- All auth is robot-to-app only (local network only)

## Monitoring & Observability

**Error Tracking:**
- None — no external error reporting service
- Errors handled locally in error handling views and services

**Logging:**
- Native os.Logger framework
  - Subsystem: `Bundle.main.bundleIdentifier` (e.g., `com.valetudio`)
  - Categories: `API`, `SSE`, `mDNS`, `Notifications`, `RobotManager`
  - Levels: info, warning, error configured per logger instance
  - Examples: `Services/ValetudoAPI.swift`, `Services/SSEConnectionManager.swift`

**Debug Support:**
- `Helpers/DebugConfig.swift` - Debug configuration and logging control
- Console logging available in Xcode debugger

## CI/CD & Deployment

**Hosting:**
- App Store (iOS App Store distribution)
- Bundle ID: `de.simonluthe.ValetudiOS`
- Requires Xcode Cloud or manual signing

**CI Pipeline:**
- Xcode Cloud integration present (CI configuration files modified in recent commits)
- Automatic code signing configured in Xcode project
- Test target configured for archive export

**Code Signing:**
- Automatic signing enabled
- Development team: Apple Developer account holder
- Certificates: Managed by Xcode/Apple

## Entitlements

**Required Capabilities:**
- Local Network access (for mDNS robot discovery)
  - Usage description: "Access local network to communicate with Valetudo robots"
  - Required Info.plist key: `NSLocalNetworkUsageDescription`
- Keychain access (implicit for password storage)

## Environment Configuration

**Required env vars:**
- None — app is fully self-contained
- All configuration happens in-app via UI

**Secrets location:**
- iOS Keychain (secure enclave-backed on supported devices)
- No .env files, no hardcoded secrets

## Webhooks & Callbacks

**Incoming:**
- None — app is client-only, receives no inbound connections

**Outgoing:**
- None — app does not initiate callbacks to external servers
- Only outbound connections: To Valetudo robots on local network

## Push Notifications

**Local Notifications Only:**
- Service: UserNotifications (local device only)
- Triggers: Robot state changes detected by `SSEConnectionManager` and `RobotManager`
- Categories:
  - `CLEANING_COMPLETE` - Cleaning finished
  - `ROBOT_ERROR` - Robot error state
  - `ROBOT_STUCK` - Robot stuck detected
  - `CONSUMABLE_LOW` - Consumable below threshold
  - `ROBOT_OFFLINE` - Robot connection lost
- Implementation: `Services/NotificationService.swift`
- User preferences control each notification type via @AppStorage

## In-App Purchase (StoreKit 2)

**Support Donations:**
- Provider: Apple App Store
- Products:
  - `de.godsapp.valetudoapp.support.small` — €0.99 (coffee)
  - `de.godsapp.valetudoapp.support.medium` — €2.99 (gift)
  - `de.godsapp.valetudoapp.support.large` — €5.99 (sparkles)
- Handling: `Services/SupportManager.swift`
  - Product fetching: `Product.products(for: productIds)`
  - Purchase flow: `product.purchase()` with verification
  - Transaction finishing: Verified transactions marked as `.finish()`
- UI: `Views/SupportView.swift`, `Views/SupportReminderView.swift`
- Tracking: @AppStorage flags (`hasSupported`, `appLaunchCount`)

## Siri Shortcuts Integration

**Framework:**
- Intents Framework (`Intents/RobotIntents.swift`)
- App Intents API for Siri command execution

**Supported Shortcuts:**
- Robot control intents for common actions (start, stop, home, etc.)
- Implemented as donatable user activities

## Network Discovery

**mDNS Service Discovery:**
- Service Type: `_valetudo._tcp` on `.local` domain
- Browsing: `NWBrowser` from Network Framework in `Services/NWBrowserService.swift`
- TXT Record Parsing:
  - `friendlyName` - Robot display name
  - `model` - Robot model identifier
- Discovery Result: `DiscoveredRobot` struct with host resolution to `<name>.local`

## Third-Party Dependencies

**None Detected:**
- Project uses exclusively native iOS frameworks
- No CocoaPods, SPM, or other package managers configured
- All dependencies are built-in to iOS 17.0+

---

*Integration audit: 2026-03-28*
