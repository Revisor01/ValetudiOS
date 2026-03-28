# Technology Stack

**Analysis Date:** 2026-03-28

## Languages

**Primary:**
- Swift 5.9+ - All source code, app logic, views, services, models

## Runtime

**Environment:**
- iOS 17.0+ (minimum deployment target)
- Xcode 15.0+

**Package Manager:**
- None (native iOS development, no external package dependencies)
- Build system: XcodeGen (project.yml) + native Xcode project

## Frameworks

**Core UI:**
- SwiftUI - All UI views and components
- UIKit (minimal) - UIApplicationDelegate for notification handling via AppDelegate

**Networking:**
- Foundation URLSession - HTTP requests to Valetudo API
- Network Framework - mDNS/Bonjour discovery via NWBrowser

**System Frameworks:**
- UserNotifications - Push notifications and notification categories
- Security - Keychain access for credential storage

**Build/Dev:**
- XcodeGen - Project generation from YAML configuration
- Swift Concurrency (async/await) - Async API calls and background tasks

## Key Dependencies

**Critical:**
- URLSession with custom SSL handling - Communication with Valetudo robots (HTTP & HTTPS with self-signed cert support)
- NWBrowser (Network.framework) - Local network discovery via mDNS _valetudo._tcp service
- UNUserNotificationCenter - Push notifications for cleaning status, errors, consumables

**Infrastructure:**
- AppStorage - Local user preferences and app settings persistence
- Keychain (Security framework) - Secure password storage for robot credentials

## Configuration

**Environment:**
- App configuration via SwiftUI AppStorage for user settings
- Robot credentials encrypted in iOS Keychain
- No environment files or secrets; all local storage

**Build:**
- `project.yml` - XcodeGen configuration (deployment target, Swift version, bundle identifiers)
- Auto-generated Info.plist with Bonjour service declaration (_valetudo._tcp)

## Platform Requirements

**Development:**
- macOS with Xcode 15.0+
- Swift 5.9 support
- iOS 17.0+ SDK

**Production:**
- iPhone/iPad running iOS 17.0+
- Local network connectivity to Valetudo robots
- Valetudo firmware 2024.06.0+

## Network Protocols

**Robot Communication:**
- REST API via HTTP/HTTPS (URLSession)
- Server-Sent Events (SSE) for real-time state streaming via URLSession with infinite timeout
- Basic Authentication (username:password in base64)
- Self-signed SSL certificate support via custom URLSessionDelegate

**Local Network Discovery:**
- mDNS browsing (_valetudo._tcp domain)
- Bonjour TXT record parsing for robot metadata (friendlyName, model)
- Network.framework NWBrowser for service discovery

---

*Stack analysis: 2026-03-28*
