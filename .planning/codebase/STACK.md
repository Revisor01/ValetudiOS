# Technology Stack

**Analysis Date:** 2026-03-28

## Languages

**Primary:**
- Swift 5.9+ - All application code, UI, services, and tests

## Runtime

**Environment:**
- iOS 17.0+ (minimum deployment target)
- Xcode 15.0+ (required to build)

**Platform:**
- Apple iOS / iPadOS (native SwiftUI app)

## Frameworks

**Core Framework:**
- SwiftUI - UI framework for all views (`ValetudoApp/Views/*.swift`, `ValetudoApp/ContentView.swift`)
- Foundation - Core data types, networking, codable support
- Combine - Reactive data flow via `@Published` and `ObservableObject`

**Networking:**
- URLSession - HTTP/HTTPS requests with custom SSL handling
  - Custom `SSLSessionDelegate` in `Services/ValetudoAPI.swift` for self-signed certificate support
  - Separate configuration for SSE with infinite timeout (`Services/SSEConnectionManager.swift`)

**Network Discovery:**
- Network Framework - mDNS browsing for robot discovery
  - `NWBrowser` for `_valetudo._tcp` service discovery in `Services/NWBrowserService.swift`
  - Bonjour TXT record parsing for robot metadata

**Local Storage:**
- AppKit/Security - Keychain integration via `Services/KeychainStore.swift`
  - Stores robot passwords with service: `com.valetudo.robot.password`
  - Per-robot UUID-based accounts with device-only accessibility
- UserDefaults (via @AppStorage) - App preferences and state

**Notifications:**
- UserNotifications - Local push notifications for robot events
  - Cleaning completion, errors, stuck state, consumable warnings, offline alerts
  - Custom notification categories in `Services/NotificationService.swift`

**App Store & Monetization:**
- StoreKit 2 (`import StoreKit`) - In-app purchases for support donations
  - Product IDs: `de.godsapp.valetudoapp.support.{small,medium,large}`
  - Verified transaction handling in `Services/SupportManager.swift`

**System Integration:**
- UserNotifications (UNUserNotificationCenter) - Local notification handling
- os.Logger - Unified logging with subsystem `com.valetudio` across services

**Testing:**
- XCTest - Native testing framework
  - 57 unit tests in `ValetudoAppTests/` covering API, models, ViewModels, and utilities

## Build System

**Build Tool:**
- Xcode 15+ with `.pbxproj` project format
- Test target: `ValetudoAppTests` (bundle ID: `de.simonluthe.ValetudiOS.Tests`)

**Code Generation:**
- Localizable.xcstrings for multi-language support (German/English)
- Media.xcassets for app icon and image resources

## Configuration

**Environment:**
- No .env files — configuration injected via `RobotConfig` struct passed to APIs
- Bundle identifier: `de.simonluthe.ValetudiOS`
- Deployment target: iOS 17.0

**Build Configurations:**
- Debug - Development builds with logging enabled
- Release - App Store builds with code optimization

**Entitlements:**
- Local Network access (for mDNS robot discovery)
- Keychain access (for credential storage)

## Key Dependencies

**Critical Built-in Frameworks:**
- SwiftUI - UI rendering and state management
- Foundation - JSON decoding, URL handling, data structures
- Network - mDNS service discovery
- Security - Keychain password storage
- UserNotifications - Push notification delivery
- StoreKit - App Store in-app purchases

**No Third-Party Package Dependencies:** Project uses only native iOS frameworks

## Platform Requirements

**Development:**
- macOS 11.0+ with Xcode 15+
- Swift 5.9+ compiler
- Target device: iPhone with iOS 17.0+

**Production:**
- iOS 17.0+ (iPhone models supporting iOS 17)
- Valetudo 2024.06.0+ vacuum robot firmware
- Local network connectivity to robot

**Network:**
- TCP/IP connectivity to robot on local network
- HTTP or HTTPS (with optional self-signed certificate support)
- Server-Sent Events (SSE) stream for real-time updates

## Notable Architectural Patterns

**Actor-based concurrency:**
- `ValetudoAPI` uses `actor` keyword for thread-safe API calls
- `SSEConnectionManager` is an `actor` for managing concurrent robot streams
- `@MainActor` for UI-bound classes like `RobotManager`, `NWBrowserService`

**SwiftUI Patterns:**
- `@StateObject` for lifecycle-managed observables (`robotManager`, `errorRouter`)
- `@EnvironmentObject` for view hierarchy distribution
- `@AppStorage` for UserDefaults persistence
- `@Published` properties for reactive state

**Async/Await:**
- Structured concurrency throughout (Foundation-based)
- URLSession with async/await wrapper
- Task-based lifecycle management in services

---

*Stack analysis: 2026-03-28*
