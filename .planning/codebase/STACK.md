# Technology Stack

**Analysis Date:** 2026-04-04

## Languages

**Primary:**
- Swift 5.9 - Native iOS application implementation

## Runtime

**Environment:**
- iOS 17.0+ (Deployment Target)
- Xcode 15.0+

**Platform:**
- Apple iOS (Native)

## Frameworks

**Core UI:**
- SwiftUI - Declarative UI framework (55 imports across codebase)
- UIKit - Integration layer for AppDelegate and background tasks

**Networking:**
- Foundation URLSession - HTTP client for REST API calls
- Network framework - Bonjour/mDNS discovery and network detection

**Concurrency:**
- Swift async/await - Async operations and concurrent task management
- Observation framework - Observable property binding and state management

**System Integration:**
- BackgroundTasks - Background app refresh scheduling
- UserNotifications - Local push notifications
- Security framework - Keychain secure credential storage

**Development:**
- Xcode Project Generation (XcodeGen) - Project definition via `project.yml`

## Key Dependencies

**Critical:**
- Foundation - Core language library for JSON, networking, logging
- os (OSLog) - Unified logging system for debugging
- StoreKit - In-app purchase and app store integration (2 files)
- AppIntents - Siri Shortcuts integration

**Infrastructure:**
- URLSession with custom SSLSessionDelegate - Self-signed certificate support
- JSONDecoder/JSONEncoder - JSON serialization for API data

## Configuration

**Environment:**
- Xcode 15.0+ required
- iOS 17.0+ required for deployment
- Swift 5.9 compiler version
- Development Team: J459G9CJT5 (Apple Developer ID)

**Build:**
- Project configuration: `ValetudoApp/project.yml` (XcodeGen)
- App identifier: `de.simonluthe.ValetudiOS`
- Test host: `de.simonluthe.ValetudiOSTests`
- Marketing version: 2.1.0
- Build configuration: 1

**App Capabilities:**
- Local Network access (NSLocalNetworkUsageDescription in `Info.plist`)
- Bonjour services (`_valetudo._tcp`)
- Background refresh task identifier: `de.simonluthe.ValetudiOS.backgroundRefresh`

## Platform Requirements

**Development:**
- Xcode 15.0 or later
- iOS 17.0 SDK
- Swift 5.9 compiler
- macOS developer machine

**Production:**
- iOS 17.0 or later on iPhone/iPad
- Local network connectivity to Valetudo robot endpoints
- Valetudo 2024.06.0+ firmware compatibility

**Testing:**
- Unit test target: `ValetudoAppTests`
- Test framework: XCTest (implicit via Xcode)
- Test host configuration in project.yml

---

*Stack analysis: 2026-04-04*
