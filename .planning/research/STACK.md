# Stack Research

**Domain:** iOS Valetudo Robot Controller — v1.2.0 Quality & API Completeness
**Researched:** 2026-03-27
**Confidence:** HIGH (all additions are Apple-native, documented frameworks)

---

## Context: What is NOT Changing

The existing stack is validated and stays untouched:

- Swift 5.9, SwiftUI, iOS 17+
- URLSession, Foundation, Network, UserNotifications, AppIntents
- UserDefaults for non-sensitive config, XcodeGen for project generation
- Zero external dependencies — this constraint is maintained for all additions below

---

## New Framework Additions for v1.2.0

### Core Technologies

| Technology | Framework | Available Since | Purpose | Why This |
|------------|-----------|-----------------|---------|----------|
| Security (Keychain) | Security.framework | iOS 2.0 | Store robot credentials (username/password) securely | Only encrypted credential store on iOS. Survives app uninstall with correct `kSecAttrAccessGroup`. Excluded from unencrypted backups by default. |
| NWBrowser | Network.framework | iOS 13.0 | mDNS/Bonjour service discovery for `_valetudo._tcp` | Already imported in the project (`NetworkScanner.swift`). Replaces brute-force IP scan. Valetudo advertises `_valetudo._tcp` natively. `NSBonjourServices` key already in Info.plist. |
| URLSession.AsyncBytes | Foundation | iOS 15.0 | Server-Sent Events (SSE) streaming from Valetudo | Built into URLSession. No external dependency. Uses Swift structured concurrency (`for await`). Parses SSE line-by-line via `.lines`. |
| os.Logger | os.framework (OSLog) | iOS 14.0 | Structured logging replacing all `print()` calls | Integrates with Xcode console and Console.app. Supports log levels (debug/info/error/fault). Privacy controls for sensitive values. Subsystem+category filtering. |
| XCTest | XCTest.framework | iOS 8.0 | Unit tests for business logic (parsers, calculators, state) | Apple's standard test framework. Built into Xcode. No configuration beyond adding a test target to `project.yml`. |

### Supporting Patterns (No New Frameworks)

| Pattern | Existing Foundation | Purpose |
|---------|---------------------|---------|
| JSONDecoder + Codable | Foundation (already used) | Parse Valetudo OpenAPI/Swagger JSON fetched from `/swagger/openapi.json` on the robot |
| URLSession data task | Foundation (already used) | Fetch the OpenAPI definition from the live robot at runtime |
| @testable import | XCTest | Expose `internal` declarations in test target without changing access modifiers |

---

## Integration Points with Existing Code

### 1. Keychain — replaces UserDefaults credential storage

**Where to integrate:** `RobotManager.swift` (lines 196–209), `RobotConfig.swift`

**Pattern:**
```swift
import Security

// Store
let query: [CFString: Any] = [
    kSecClass: kSecClassGenericPassword,
    kSecAttrService: "de.simonluthe.ValetudiOS",
    kSecAttrAccount: robotId,          // unique per robot
    kSecValueData: passwordData,
    kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
]
SecItemAdd(query as CFDictionary, nil)

// Retrieve
var result: AnyObject?
SecItemCopyMatching(query as CFDictionary, &result)

// Delete
SecItemDelete(query as CFDictionary)
```

**Migration path:** `RobotConfig` keeps all fields in UserDefaults except `username` and `password`. On first load of an existing config, if credentials exist in UserDefaults, migrate to Keychain and delete from UserDefaults.

**Key:** Use `robotId` (a stable UUID per robot) as `kSecAttrAccount` so multiple robots each have independent Keychain entries.

**`kSecAttrAccessible` choice:** `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — correct for credentials that are only needed when the app is in the foreground (no background network task currently). Does not migrate to new device via iCloud backup, which is appropriate for LAN-bound robot credentials.

---

### 2. NWBrowser — replaces brute-force IP scan

**Where to integrate:** `NetworkScanner.swift` — replace the 254-IP loop with NWBrowser as primary path, keep IP scan as fallback.

**Pattern:**
```swift
import Network

let browser = NWBrowser(
    for: .bonjourWithTXTRecord(type: "_valetudo._tcp", domain: "local."),
    using: .tcp
)
browser.browseResultsChangedHandler = { results, changes in
    for result in results {
        if case .service(let name, _, _, _) = result.endpoint {
            // result.endpoint can be used directly with NWConnection to resolve IP
        }
    }
}
browser.stateUpdateHandler = { state in ... }
browser.start(queue: .main)
```

**IP resolution:** Create a temporary `NWConnection` to the discovered `NWEndpoint` — the Network framework resolves the mDNS hostname to an IP during connection setup. Extract the resolved IP from `NWConnection`'s `currentPath`.

**Info.plist:** `NSBonjourServices` already declares `_valetudo._tcp` in the existing project. No additional entitlements needed.

**Fallback:** Keep the existing IP-scan loop in `NetworkScanner.swift` as fallback if `NWBrowser` finds nothing after a 5-second timeout.

---

### 3. URLSession.AsyncBytes — SSE for real-time robot state

**Important finding:** Valetudo does NOT natively expose an SSE endpoint. Real-time push from Valetudo is MQTT-only. The REST API is request/response only.

**Consequence:** "Adaptive Polling / SSE" in the milestone must be implemented as **adaptive polling** — not true SSE. The SSE path would require a gateway/proxy in front of Valetudo, which is out of scope.

**Recommended approach — Adaptive Polling with URLSession.AsyncBytes ready:**
- Reduce polling interval from 5s to 2s when robot is active (cleaning/returning)
- Increase interval to 30s when robot is docked/idle
- Use `URLSession.AsyncBytes` now to structure the polling pipeline as a streaming `AsyncSequence`, so it can be upgraded to SSE later if Valetudo adds support

**Pattern for adaptive polling:**
```swift
actor RobotPoller {
    private var interval: Duration {
        switch robotState.status {
        case .cleaning, .returning: return .seconds(2)
        case .docked, .idle:        return .seconds(30)
        default:                    return .seconds(5)
        }
    }

    func startPolling() async {
        while !Task.isCancelled {
            await fetchState()
            try? await Task.sleep(for: interval)
        }
    }
}
```

**If/when Valetudo adds SSE** — upgrade path using `URLSession.AsyncBytes`:
```swift
let (bytes, _) = try await URLSession.shared.bytes(from: sseURL)
for try await line in bytes.lines {
    if line.hasPrefix("data:") {
        // parse JSON event
    }
}
```

---

### 4. os.Logger — structured logging

**Where to integrate:** All files with `print()` calls — primarily `ValetudoAPI.swift`, `MapView.swift`, `RobotSettingsView.swift`, `ConsumablesView.swift`, `RobotManager.swift`.

**Pattern:**
```swift
import os

// Define once per subsystem, reuse across files
extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier!

    static let api      = Logger(subsystem: subsystem, category: "API")
    static let map      = Logger(subsystem: subsystem, category: "Map")
    static let scanner  = Logger(subsystem: subsystem, category: "Scanner")
    static let robot    = Logger(subsystem: subsystem, category: "Robot")
    static let ui       = Logger(subsystem: subsystem, category: "UI")
}

// Usage (replaces print())
Logger.api.debug("Fetching robot attributes")
Logger.api.error("Connection failed: \(error.localizedDescription, privacy: .public)")
```

**Privacy:** Mark user-provided values (robot host, username) as `.private` or redact with `\(value, privacy: .private)`. Error descriptions are safe to mark `.public`.

**Debug guard:** `os.Logger` already gates `debug`-level output — it does not appear in production device logs by default. No `#if DEBUG` needed around logger calls.

**Replace all `print()` one-for-one:**
- `[API DEBUG]` → `Logger.api.debug(...)`
- `[DEBUG]` → appropriate category `.debug(...)`
- Error paths → `.error(...)`
- User-visible failures → `.fault(...)` (persists in system log)

---

### 5. XCTest — test target setup

**Where to integrate:** `project.yml` — add a new `ValetudoAppTests` target.

**XcodeGen `project.yml` addition:**
```yaml
targets:
  # ... existing ValetudoApp target ...

  ValetudoAppTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - ValetudoAppTests
    dependencies:
      - target: ValetudoApp
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: de.simonluthe.ValetudoAppTests
```

**Directory to create:** `ValetudoApp/ValetudoAppTests/` — XcodeGen will pick up `.swift` files automatically.

**Priority test subjects** (from CONCERNS.md):
1. `ValetudoTimer` — UTC/local time conversion (pure logic, easy to test)
2. `Consumable.remainingPercent` — calculation correctness across robot models
3. `MapLayer.decompressedPixels` — RLE decompression correctness
4. Keychain wrapper — read/write/delete round-trip (requires device, not simulator)
5. API response parsing — `JSONDecoder` correctness for edge cases in `RobotState`, `RobotMap`

**`@testable import`:** Add `@testable import ValetudoApp` to test files to access `internal` declarations without changing access modifiers in production code.

---

### 6. Valetudo OpenAPI/Swagger — fetching API definition

**Finding:** Valetudo serves its OpenAPI definition at `http://ROBOT_IP/swagger/openapi.json`. The spec is generated at build time from capability-specific JSON schema fragments across the Valetudo source tree.

**Approach:** Fetch the spec at runtime using existing `URLSession`. Do not bundle a static copy — the spec varies by robot model and Valetudo version.

**Pattern:**
```swift
// Fetch at app startup or on robot add
let url = URL(string: "http://\(robot.host)/swagger/openapi.json")!
let (data, _) = try await URLSession.shared.data(from: url)
let spec = try JSONDecoder().decode(OpenAPISpec.self, from: data)
```

**What to decode:** Model only the paths and capability names needed to drive UI decisions (which capabilities are available on the connected robot). Do not attempt to decode the full spec — it is large and varies. A partial `Codable` struct that only decodes `paths` keys is sufficient.

**Where to store:** In-memory in `RobotManager` or `ValetudoAPI` — capabilities are session-scoped, not persisted. Cache invalidation: re-fetch on reconnect.

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Any SSE/EventSource Swift package (mattt/EventSource, Recouse/EventSource) | Valetudo has no SSE endpoint; package would be unused. Breaks zero-deps constraint. | Adaptive polling via URLSession async tasks |
| SwiftData / CoreData for credential migration | Massive scope increase for what is a two-field migration | Keychain (Security.framework) + UserDefaults for non-sensitive fields |
| Combine for polling pipeline | Unnecessary when Swift structured concurrency (async/await + actor) already used throughout the app | Swift concurrency: `Task`, `AsyncSequence`, `actor` |
| Third-party logging libraries (CocoaLumberjack, swift-log) | Break zero-deps constraint; `os.Logger` is equally capable and integrates with system Console.app | os.Logger from os.framework |
| Third-party mock/test helpers (Quick, Nimble) | Break zero-deps constraint; XCTest provides sufficient assertions for unit tests at this scope | XCTest native assertions (`XCTAssertEqual`, `XCTAssertNil`, etc.) |
| MQTT client library | Out of scope per PROJECT.md — app is REST-only. MQTT would be a new architectural dependency, not a quality fix | Adaptive polling |

---

## Alternatives Considered

| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| Security.framework Keychain | CryptoKit + custom encrypted UserDefaults | Keychain is the platform-standard solution. CryptoKit encryption of UserDefaults is more code with the same security model, minus OS backup exclusion guarantees. |
| NWBrowser (Network.framework) | NetServiceBrowser (Foundation/Bonjour) | NetServiceBrowser is Objective-C-era API, deprecated in favor of Network.framework since iOS 13. NWBrowser is already in use in the project for network interface enumeration. |
| URLSession.AsyncBytes | WebSocket (URLSessionWebSocketTask) | Valetudo does not expose WebSocket. AsyncBytes is the correct tool for HTTP streaming and is future-compatible with SSE if Valetudo adds it. |
| os.Logger | OSLog (lower-level C API) | os.Logger is the Swift-idiomatic wrapper for OSLog introduced in iOS 14. Same performance, better ergonomics, string interpolation with privacy annotations. iOS 14 is below the iOS 17 deployment target. |
| XCTest | Swift Testing (swift-testing package) | Swift Testing is available as part of Xcode 16+ without a package dependency, but XCTest is more established, better documented, and has full UITest support. Either is valid — XCTest is the safer default for an initial test setup. |

---

## Version Compatibility

All additions target iOS 17.0+ (existing deployment target). All APIs were available well before iOS 17:

| API | Available Since | iOS 17 Compatible |
|-----|-----------------|-------------------|
| Security.framework Keychain | iOS 2.0 | Yes |
| NWBrowser | iOS 13.0 | Yes |
| URLSession.AsyncBytes | iOS 15.0 | Yes |
| os.Logger | iOS 14.0 | Yes |
| XCTest | iOS 8.0 | Yes |

No minimum version bumps required.

---

## Sources

- Apple Developer Documentation: Keychain Services — `kSecClassGenericPassword`, `SecItemAdd`, `SecItemCopyMatching` (HIGH confidence, platform standard since iOS 2.0)
- Apple Developer Documentation: NWBrowser — [https://developer.apple.com/documentation/foundation/bonjour](https://developer.apple.com/documentation/foundation/bonjour) (HIGH confidence, verified via Apple Developer Forums thread)
- Apple WWDC21 "Use async/await with URLSession" — [https://developer.apple.com/videos/play/wwdc2021/10095/](https://developer.apple.com/videos/play/wwdc2021/10095/) — URLSession.AsyncBytes confirmed iOS 15+ (HIGH confidence)
- SwiftLee: OSLog and Unified Logging — [https://www.avanderlee.com/debugging/oslog-unified-logging/](https://www.avanderlee.com/debugging/oslog-unified-logging/) (MEDIUM confidence, verified against Apple WWDC2020 content)
- XcodeGen test target fixture — [https://github.com/yonaskolb/XcodeGen/blob/master/Tests/Fixtures/TestProject/project.yml](https://github.com/yonaskolb/XcodeGen/blob/master/Tests/Fixtures/TestProject/project.yml) — `bundle.unit-test` target type confirmed (HIGH confidence)
- Valetudo Newcomer Guide — [https://valetudo.cloud/pages/general/newcomer-guide.html](https://valetudo.cloud/pages/general/newcomer-guide.html) — REST API with Swagger UI at `/swagger/`, no native SSE confirmed (MEDIUM confidence; SSE absence confirmed via GitHub search returning 0 results)
- Valetudo Discussion #968 — [https://github.com/Hypfer/Valetudo/discussions/968](https://github.com/Hypfer/Valetudo/discussions/968) — OpenAPI spec added in 2021.06.0 (HIGH confidence)

---

*Stack research for: ValetudiOS v1.2.0 — iOS native robot controller*
*Researched: 2026-03-27*
