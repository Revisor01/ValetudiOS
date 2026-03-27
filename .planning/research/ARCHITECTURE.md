# Architecture Research

**Domain:** iOS SwiftUI App — Refactoring & Feature Integration (ValetudiOS v1.2.0)
**Researched:** 2026-03-27
**Confidence:** HIGH

## Standard Architecture

### System Overview (Target State after v1.2.0)

```
┌──────────────────────────────────────────────────────────────────────┐
│                        View Layer                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │
│  │ MapView      │  │RobotDetailV. │  │RobotSettings │               │
│  │(~500 lines)  │  │(~400 lines)  │  │(~500 lines)  │               │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘               │
│         │ @StateObject     │ @StateObject     │ @StateObject          │
├─────────┴─────────────────┴─────────────────┴───────────────────────┤
│                        ViewModel Layer (new)                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │
│  │MapViewModel  │  │RobotDetail   │  │RobotSettings │               │
│  │              │  │ViewModel     │  │ViewModel     │               │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘               │
│         │ @MainActor       │                  │                       │
├─────────┴─────────────────┴─────────────────────────────────────────┤
│                        Service Layer                                  │
│  ┌──────────────┐  ┌────────────────┐  ┌──────────────────────────┐ │
│  │RobotManager  │  │ValetudoAPI     │  │SSEConnectionManager (new)│ │
│  │(ObsObject)   │  │(actor)         │  │(actor)                   │ │
│  └──────┬───────┘  └──────┬─────────┘  └────────────┬─────────────┘ │
│         │                 │                          │               │
├─────────┴─────────────────┴──────────────────────────┴──────────────┤
│                        Infrastructure Layer                           │
│  ┌──────────────┐  ┌────────────────┐  ┌──────────────────────────┐ │
│  │KeychainStore │  │UserDefaults    │  │NWBrowserService (new)    │ │
│  │(new)         │  │(non-sensitive) │  │                          │ │
│  └──────────────┘  └────────────────┘  └──────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Status | Responsibility | Notes |
|-----------|--------|---------------|-------|
| `RobotManager` | Modified | Central state, coordinates polling + SSE, fires notifications | Loses direct UserDefaults credential access |
| `ValetudoAPI` | Modified | HTTP client, adds SSE stream method | New `streamState()` method using `URLSession.bytes` |
| `SSEConnectionManager` | New | Owns all active SSE connections per robot, lifecycle management | Actor for thread safety |
| `MapViewModel` | New | Map interaction state extracted from MapView | Gestures, edit modes, zone drawing |
| `RobotDetailViewModel` | New | Robot dashboard logic extracted from RobotDetailView | Control actions, loading state |
| `RobotSettingsViewModel` | New | Settings fetch/update logic extracted from RobotSettingsView | Per-capability state |
| `KeychainStore` | New | Secure credential storage, migration from UserDefaults | Wraps SecItem APIs |
| `NWBrowserService` | New | mDNS/Bonjour discovery, wraps NWBrowser | Falls back gracefully |
| `ErrorRouter` | New | Central error display coordination | View modifier + state |

## Recommended Project Structure

```
ValetudoApp/ValetudoApp/
├── Models/              # Unchanged — Codable DTOs
├── Services/
│   ├── ValetudoAPI.swift          # Modified: add streamState()
│   ├── RobotManager.swift         # Modified: integrate SSE, remove credentials
│   ├── SSEConnectionManager.swift # NEW: actor managing SSE streams per robot
│   ├── NetworkScanner.swift       # Modified: delegate to NWBrowserService
│   ├── NWBrowserService.swift     # NEW: mDNS via Network.framework
│   ├── NotificationService.swift  # Unchanged (notification actions separate)
│   └── KeychainStore.swift        # NEW: SecItem wrapper for credentials
├── ViewModels/          # NOW POPULATED
│   ├── MapViewModel.swift          # NEW: extracted from MapView
│   ├── RobotDetailViewModel.swift  # NEW: extracted from RobotDetailView
│   └── RobotSettingsViewModel.swift # NEW: extracted from RobotSettingsView
├── Views/               # Thinned views, same file names
│   ├── MapView.swift               # Modified: delegates to MapViewModel
│   ├── RobotDetailView.swift       # Modified: delegates to RobotDetailViewModel
│   ├── RobotSettingsView.swift     # Modified: delegates to RobotSettingsViewModel
│   └── ... (others mostly unchanged)
├── Helpers/
│   ├── PresetHelpers.swift         # Unchanged
│   ├── DebugConfig.swift           # Unchanged
│   └── ErrorRouter.swift           # NEW: ViewModifier + @MainActor state
└── Intents/
    └── RobotIntents.swift          # Modified: use KeychainStore instead of UserDefaults
```

### Structure Rationale

- **ViewModels/ populated:** Views bind to local `@StateObject` ViewModels. ViewModels call `RobotManager` for shared state and `ValetudoAPI` for direct commands. This keeps views declarative.
- **SSEConnectionManager separate:** SSE lifecycle (connect, reconnect, teardown) is complex enough to own its own actor, keeping `RobotManager` focused on state aggregation.
- **KeychainStore in Services/:** It is a service (I/O), not a helper. Intents also need it directly.
- **NWBrowserService separate:** Isolates Network.framework dependency. NetworkScanner delegates to it, keeping IP-fallback path intact.
- **ErrorRouter in Helpers/:** It is display logic (maps errors to user strings), not business logic.

## Architectural Patterns

### Pattern 1: ViewModel Extraction via Protocol + @StateObject

**What:** Extract a `@MainActor final class FooViewModel: ObservableObject` for each massive view. The view creates it with `@StateObject`. The ViewModel receives `RobotManager` and/or `ValetudoAPI` as constructor dependencies (not via `@EnvironmentObject`), enabling unit testing.

**When to use:** For MapView, RobotDetailView, RobotSettingsView — the three files over 1500 lines.

**Trade-offs:** Adds files. Solves testability and view file size. Does not require migrating to `@Observable` macro — `ObservableObject` works identically on iOS 17+.

**Example:**
```swift
// ViewModels/RobotDetailViewModel.swift
@MainActor
final class RobotDetailViewModel: ObservableObject {
    @Published private(set) var isStarting = false
    @Published private(set) var errorMessage: String?

    private let api: ValetudoAPI
    private let robotManager: RobotManager

    init(api: ValetudoAPI, robotManager: RobotManager) {
        self.api = api
        self.robotManager = robotManager
    }

    func startCleaning() async {
        isStarting = true
        defer { isStarting = false }
        do {
            try await api.basicControl(action: .start)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// Views/RobotDetailView.swift (thinned)
struct RobotDetailView: View {
    @StateObject private var viewModel: RobotDetailViewModel
    @EnvironmentObject var robotManager: RobotManager

    init(robot: RobotConfig, robotManager: RobotManager) {
        let api = robotManager.getAPI(for: robot.id)!
        _viewModel = StateObject(wrappedValue: RobotDetailViewModel(api: api, robotManager: robotManager))
    }
    // ...
}
```

### Pattern 2: SSE via URLSession.bytes AsyncSequence (No External Dependencies)

**What:** `ValetudoAPI` adds a `streamState()` method returning `AsyncStream<RobotAttribute>`. Internally it uses `URLSession.shared.bytes(from:)` and iterates `.lines`, parsing SSE `data:` lines. `SSEConnectionManager` owns the running `Task` per robot and exposes state changes via `AsyncStream`.

**When to use:** When connecting to a robot. SSE replaces the 5-second polling loop for robots that support it. Polling is kept as fallback (robots offline or returning HTTP error on SSE endpoint).

**Trade-offs:** `URLSession.bytes` is available since iOS 15 — no version risk. Background reconnection requires task management. Must handle Valetudo's 5-client limit by sharing one connection per robot.

**Example:**
```swift
// Services/ValetudoAPI.swift — new method
func streamStateLines() async throws -> URLSession.AsyncBytes {
    var request = baseRequest(path: "/api/v2/robot/state/attributes/sse")
    // headers already set by baseRequest
    let (bytes, response) = try await URLSession.shared.bytes(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
    }
    return bytes
}

// Services/SSEConnectionManager.swift
actor SSEConnectionManager {
    private var tasks: [UUID: Task<Void, Never>] = [:]

    func connect(robot: RobotConfig, api: ValetudoAPI, onUpdate: @escaping (RobotAttribute) -> Void) {
        tasks[robot.id]?.cancel()
        tasks[robot.id] = Task {
            do {
                let stream = try await api.streamStateLines()
                for try await line in stream.lines {
                    if line.hasPrefix("data:") {
                        let json = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        if let data = json.data(using: .utf8),
                           let attr = try? JSONDecoder().decode(RobotAttribute.self, from: data) {
                            onUpdate(attr)
                        }
                    }
                }
            } catch { /* reconnect handled by RobotManager */ }
        }
    }

    func disconnect(robotId: UUID) {
        tasks[robotId]?.cancel()
        tasks.removeValue(forKey: robotId)
    }
}
```

### Pattern 3: Keychain Migration with Transparent Fallback

**What:** `KeychainStore` provides a typed interface over `SecItem*` APIs. On first access for a credential, if the Keychain returns nil, it checks UserDefaults, migrates the value, then deletes from UserDefaults. This is transparent to callers.

**When to use:** Replacing `RobotConfig.password` storage. Only `username`/`password` fields move to Keychain — host, SSL flag, robot name remain in UserDefaults via `Codable` as before.

**Trade-offs:** `SecItem` APIs are verbose but well-understood. Migration runs once per robot on first access. Keychain persists across app deletion — must handle gracefully.

**Example:**
```swift
// Services/KeychainStore.swift
struct KeychainStore {
    static func password(for robotId: UUID) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: robotId.uuidString,
            kSecReturnData: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        // Migration path: check legacy UserDefaults
        if let legacy = UserDefaults.standard.string(forKey: "robot_password_\(robotId)") {
            _ = save(password: legacy, for: robotId)
            UserDefaults.standard.removeObject(forKey: "robot_password_\(robotId)")
            return legacy
        }
        return nil
    }

    @discardableResult
    static func save(password: String, for robotId: UUID) -> Bool {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: robotId.uuidString]
        SecItemDelete(query as CFDictionary)
        let add: [CFString: Any] = query.merging([kSecValueData: Data(password.utf8)]) { $1 }
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }
}
```

### Pattern 4: Centralized Error Presentation via ViewModifier

**What:** A `View` extension `.errorAlert(error:)` that takes a `Binding<Error?>`. Any ViewModel or View can set its `currentError` property and the modifier handles presentation. Errors conform to `LocalizedError` for user-friendly messages.

**When to use:** Replace all ad-hoc `do/catch + Alert` patterns spread across views. Install once per screen-level view.

**Trade-offs:** Requires consistent `LocalizedError` conformance on `APIError`. Simple to adopt incrementally.

**Example:**
```swift
// Helpers/ErrorRouter.swift
extension View {
    func errorAlert(error: Binding<Error?>) -> some View {
        alert(
            "Error",
            isPresented: Binding(get: { error.wrappedValue != nil }, set: { if !$0 { error.wrappedValue = nil } }),
            presenting: error.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) { error.wrappedValue = nil }
        } message: { err in
            Text((err as? LocalizedError)?.errorDescription ?? err.localizedDescription)
        }
    }
}
```

### Pattern 5: NWBrowser with IP-Scan Fallback

**What:** `NWBrowserService` is an `ObservableObject` that uses `NWBrowser` to discover `_valetudo._tcp` services on the local network. `AddRobotView` tries mDNS first (with timeout), then falls back to the existing `NetworkScanner` IP sweep. Both paths produce the same `DiscoveredRobot` struct.

**When to use:** Robot discovery in `AddRobotView`. The two paths are not mutually exclusive — run both concurrently and merge results.

**Trade-offs:** `NWBrowser` requires `NSLocalNetworkUsageDescription` and `NSBonjourServices` entries in Info.plist. mDNS discovery is instant when the service exists. If Valetudo does not advertise via Bonjour (not all firmware versions do), the IP scan is the safety net.

**Important:** `_valetudo._tcp` is the service type to browse — confirmed from Valetudo core concepts documentation.

**Example:**
```swift
// Services/NWBrowserService.swift
@MainActor
final class NWBrowserService: ObservableObject {
    @Published private(set) var discovered: [DiscoveredRobot] = []
    private var browser: NWBrowser?

    func startBrowsing() {
        let params = NWParameters()
        params.includePeerToPeer = false
        browser = NWBrowser(for: .bonjour(type: "_valetudo._tcp", domain: nil), using: params)
        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.discovered = results.compactMap { DiscoveredRobot(from: $0) }
            }
        }
        browser?.start(queue: .main)
    }

    func stopBrowsing() { browser?.cancel(); browser = nil }
}
```

### Pattern 6: Unit Test Structure via Dependency Injection

**What:** ViewModels receive their dependencies (`ValetudoAPI`, `RobotManager`, `KeychainStore`) as constructor parameters. Tests inject mocks conforming to protocols. `ValetudoAPI` gets a `ValetudoAPIProtocol` for testability.

**When to use:** All new ViewModels. Existing services stay concrete — protocol extraction only where tests require it.

**Trade-offs:** Adding protocols to existing services (`ValetudoAPI` is an actor) requires care — `actor` can conform to protocols. The test target is separate from the app target.

## Data Flow

### SSE State Update Flow (new)

```
Valetudo Robot
    ↓ SSE event (data: {"__class": "StatusStateAttribute", ...})
ValetudoAPI.streamStateLines()  [URLSession.bytes]
    ↓ async line iteration
SSEConnectionManager.task[robotId]
    ↓ parse + decode RobotAttribute
RobotManager.updateState(attribute:for:)  [@MainActor]
    ↓ @Published robotStates[robotId] mutated
Views / ViewModels  [SwiftUI re-render]
```

### Polling Fallback Flow (retained)

```
RobotManager.startRefreshing()
    ↓ Task { while !Task.isCancelled }
    ↓ SSEConnectionManager.isConnected(robotId) ?
      YES → skip poll, wait 5s
      NO  → ValetudoAPI.getAttributes() + getRobotInfo()
    ↓ RobotManager.updateState()
    ↓ Views re-render
```

### Credential Access Flow (new)

```
RobotIntents / Views / ValetudoAPI
    ↓ KeychainStore.password(for: robotId)
    ↓ [first access: check UserDefaults migration, migrate, delete from UD]
    ↓ returns String? from Keychain
ValetudoAPI.request() [Basic Auth header]
```

### Error Presentation Flow (new)

```
ViewModel.someAction() async throws
    ↓ catch error
    ↓ self.currentError = error
View .errorAlert(error: $viewModel.currentError)
    ↓ alert presented automatically
    ↓ user dismisses → currentError = nil
```

## Build Order and Dependencies

The six concerns have concrete dependencies. Build in this order to minimize integration risk:

### Phase A — Foundation (no dependencies on each other, can be parallel)

1. **KeychainStore** — Pure SecItem wrapper, no SwiftUI, immediately testable. Migrate `RobotConfig` credentials. Update `RobotIntents` to use Keychain.
2. **ErrorRouter** — ViewModifier only, no service dependencies. Add `LocalizedError` conformance to `APIError`.

### Phase B — Service Layer (depends on Phase A)

3. **SSEConnectionManager + ValetudoAPI.streamStateLines()** — New actor + new API method. `RobotManager` integration point: replace polling with SSE-with-polling-fallback. This is the most complex change.
4. **NWBrowserService** — Standalone, only depends on Network.framework and Info.plist entries. Wire into `AddRobotView` alongside existing `NetworkScanner`.

### Phase C — ViewModel Extraction (depends on Phase A+B, can be parallel per view)

5. **RobotDetailViewModel** — Extract from RobotDetailView. Uses ErrorRouter from Phase A.
6. **RobotSettingsViewModel** — Extract from RobotSettingsView. Uses ErrorRouter from Phase A.
7. **MapViewModel** — Extract from MapView. Map state is the most complex; do last within this phase.

### Phase D — Test Target (depends on all above)

8. **Test targets** — Add XCTest target. Write unit tests for ViewModels and KeychainStore using mock dependencies.

### Dependency Graph

```
KeychainStore  ──────────────────────────────────────┐
ErrorRouter    ───────────────────────────────────────┤
                                                       ↓
SSEConnectionManager ──→ RobotManager (modified)  ─→ ViewModels ─→ Tests
NWBrowserService     ──→ AddRobotView (modified)
```

## Integration Points

### New vs. Modified Components

| Component | Type | Integration Point | Depends On |
|-----------|------|------------------|------------|
| `KeychainStore` | New Service | `RobotManager`, `RobotIntents`, `ValetudoAPI` | SecItem (system) |
| `SSEConnectionManager` | New Service (actor) | `RobotManager.startRefreshing()` | `ValetudoAPI` |
| `NWBrowserService` | New Service | `AddRobotView`, alongside `NetworkScanner` | Network.framework |
| `ErrorRouter` | New Helper | All ViewModels via `View.errorAlert()` | SwiftUI |
| `MapViewModel` | New ViewModel | `MapView` (`@StateObject`) | `ValetudoAPI`, `RobotManager` |
| `RobotDetailViewModel` | New ViewModel | `RobotDetailView` (`@StateObject`) | `ValetudoAPI`, `RobotManager` |
| `RobotSettingsViewModel` | New ViewModel | `RobotSettingsView` (`@StateObject`) | `ValetudoAPI`, `RobotManager` |
| `ValetudoAPI` | Modified | Adds `streamStateLines()` | URLSession |
| `RobotManager` | Modified | Integrates `SSEConnectionManager`, removes credential ownership | `SSEConnectionManager` |
| `NetworkScanner` | Modified | Delegates to `NWBrowserService` as primary path | `NWBrowserService` |
| `RobotIntents` | Modified | Use `KeychainStore` instead of UserDefaults for passwords | `KeychainStore` |

### What Does NOT Change

- `ValetudoApp.swift` (app entry) — unchanged
- `ContentView.swift` — unchanged
- All Models — unchanged (`RobotConfig.password` field can stay for non-sensitive display but not stored in UserDefaults)
- `NotificationService` — unchanged (notification actions are a separate feature item)
- Views not in the massive-three (`AddRobotView`, `RobotListView`, `TimersView`, etc.) — mostly unchanged

### Valetudo SSE Endpoints (confirmed)

| Endpoint | Purpose | Limit |
|----------|---------|-------|
| `GET /api/v2/robot/state/sse` | Full state push | 5 clients |
| `GET /api/v2/robot/state/attributes/sse` | Attribute changes | 5 clients |
| `GET /api/v2/robot/state/map/sse` | Map data updates | 5 clients |

Recommendation: Use `/api/v2/robot/state/attributes/sse` as the primary SSE stream. This gives attribute-level granularity. Map SSE is useful in `MapView` when visible.

### Info.plist Additions Required

For `NWBrowserService` to function:
- `NSLocalNetworkUsageDescription` — user-facing string explaining local network use
- `NSBonjourServices` — array including `_valetudo._tcp`

Without these, `NWBrowser` silently fails to start.

## Anti-Patterns

### Anti-Pattern 1: ViewModel via @EnvironmentObject

**What people do:** Create a ViewModel and inject it as `@EnvironmentObject` to share it down the hierarchy.

**Why it's wrong:** ViewModels should be scoped to their view's lifetime (`@StateObject`). Sharing them recreates the same "god object" problem as the current `RobotManager`. `RobotManager` is the correct place for shared robot state — ViewModels wrap view-specific logic only.

**Do this instead:** ViewModels as `@StateObject` in their view. Shared state stays in `RobotManager` as `@EnvironmentObject`.

### Anti-Pattern 2: Calling ValetudoAPI Directly from Views

**What people do:** Obtain an API instance from `robotManager.getAPI(for:)` in the view and call it in a `Task { }` block.

**Why it's wrong:** This pattern already exists and is what causes 1500-line views. It couples view layout with async command logic, making both untestable.

**Do this instead:** All API calls go through the ViewModel. The view calls `viewModel.startCleaning()`. The ViewModel owns the `Task`, loading state, and error state.

### Anti-Pattern 3: SSE Without Polling Fallback

**What people do:** Replace 5-second polling entirely with SSE.

**Why it's wrong:** Valetudo's SSE connection can drop. On embedded hardware, robots go offline. HTTP errors on the SSE endpoint signal the robot is unreachable. Without polling as fallback, the app shows stale state indefinitely.

**Do this instead:** SSE as primary, polling as heartbeat. If SSE task is not alive for a robot, the poll runs. RobotManager checks `SSEConnectionManager.isConnected(robotId)` before each poll cycle.

### Anti-Pattern 4: Migrating to @Observable for This Milestone

**What people do:** Since iOS 17 is the minimum, migrate all `ObservableObject` to `@Observable` macro.

**Why it's wrong:** `@Observable` uses a different property access tracking model. Migrating mid-refactor adds risk without functional gain for v1.2.0. The existing `@Published` + `ObservableObject` pattern works correctly on iOS 17.

**Do this instead:** New ViewModels use `ObservableObject`. Consider `@Observable` migration as a future standalone milestone after test coverage exists.

### Anti-Pattern 5: Single Keychain Item for All Robots

**What people do:** Store all robot passwords as a single JSON blob in one Keychain item.

**Why it's wrong:** Deleting or updating one robot's credential requires reading and rewriting the entire blob. Keychain items are individually addressable — use `kSecAttrAccount: robotId.uuidString` as the key.

**Do this instead:** One Keychain item per robot, keyed by UUID. Use `kSecAttrService: "valetudio.robot.password"` to namespace all items.

## Sources

- [URLSession.AsyncBytes — Apple Developer Documentation](https://developer.apple.com/documentation/foundation/urlsession/asyncbytes) — HIGH confidence
- [Valetudo SSE Issue #666: "Active Map SSE connection should also periodically poll the status"](https://github.com/Hypfer/Valetudo/issues/666) — MEDIUM confidence (confirms SSE endpoint existence and polling fallback need)
- [Valetudo DeepWiki — SSE endpoints confirmed](https://deepwiki.com/Hypfer/Valetudo) — MEDIUM confidence
- [NWBrowser find all mDNS Services — Apple Developer Forums](https://developer.apple.com/forums/thread/118388) — HIGH confidence
- [Avoiding massive SwiftUI views — Swift by Sundell](https://www.swiftbysundell.com/articles/avoiding-massive-swiftui-views/) — HIGH confidence
- [MVVM architectural coding pattern — SwiftLee](https://www.avanderlee.com/swiftui/mvvm-architectural-coding-pattern-to-structure-views/) — HIGH confidence
- [Error alert presenting in SwiftUI — SwiftLee](https://www.avanderlee.com/swiftui/swiftui-alert-presenting/) — HIGH confidence
- [Writing testable code when using SwiftUI — Swift by Sundell](https://www.swiftbysundell.com/articles/writing-testable-code-when-using-swiftui/) — HIGH confidence
- [Keychain Services API Tutorial for Passwords — Kodeco](https://www.kodeco.com/9240-keychain-services-api-tutorial-for-passwords-in-swift) — HIGH confidence

---
*Architecture research for: ValetudiOS v1.2.0 — SwiftUI iOS App Refactoring*
*Researched: 2026-03-27*
