# Phase 2: Network Layer - Research

**Researched:** 2026-03-27
**Domain:** iOS URLSession SSE streaming, Network.framework NWBrowser, Swift value-type caching
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Eine SSE-Verbindung pro Robot für `/api/v2/robot/state/attributes/sse` (immer aktiv wenn Robot verbunden). Map-SSE (`/api/v2/robot/state/map/sse`) nur wenn MapView geöffnet ist
- **D-02:** SSEConnectionManager als neuer Service (ObservableObject), managed Verbindungen pro Robot-ID. Nutzt `URLSession.bytes(for:).lines` für SSE-Parsing
- **D-03:** Bei SSE-Verbindungsfehler: automatischer Fallback auf 5s-Polling. Reconnect-Versuch alle 30 Sekunden. Übergang transparent für User
- **D-04:** Wenn SSE aktiv und funktioniert: Polling explizit deaktiviert (nie beides gleichzeitig — Pitfall aus Research)
- **D-05:** SSE-Events updaten `RobotManager.robotStates` direkt — bestehende View-Bindings funktionieren ohne Änderung
- **D-06:** ErrorRouter.show() bei SSE-Verbindungsfehlern nutzen (Error-Surfacing aus Phase 1 aktivieren)
- **D-07:** NWBrowser für `_valetudo._tcp` Service Discovery. NSBonjourServices und NSLocalNetworkUsageDescription bereits in Info.plist deklariert
- **D-08:** Parallel-Strategie: NWBrowser startet sofort, IP-Scan startet nach 3s Timeout wenn mDNS keine Ergebnisse liefert
- **D-09:** mDNS-Ergebnisse enthalten TXT-Records (model, version, friendlyName) — diese in der AddRobotView anzeigen
- **D-10:** IP-Auflösung des mDNS-Endpoints via temporäre NWConnection (NWBrowser liefert Endpoint, nicht IP)
- **D-11:** NSBonjourServices muss vor NWBrowser-Code in project.yml eingetragen werden (Pitfall: lautloser Fehlschlag ohne Info.plist-Eintrag)
- **D-12:** MapLayer.decompressedPixels wird von computed property zu lazy stored property. Cache wird invalidiert wenn neue Map-Daten ankommen (neues MapLayer-Objekt)
- **D-13:** Da MapLayer ein Struct ist, muss der Cache als separate class-basierte Referenz implementiert werden (Structs können keine lazy var mit Mutation haben ohne mutating context)

### Claude's Discretion

- SSE-Parsing-Details (Event-Format, Retry-Logik)
- NWBrowser Lifecycle (wann starten/stoppen)
- Konkrete Cache-Implementierung (NSCache vs. eigene Klasse)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NET-01 | App nutzt SSE-Streams für Echtzeit-State-Updates statt 5s-Polling | SSEConnectionManager actor with URLSession.bytes; polling loop in RobotManager.startRefreshing() is the exact replacement target |
| NET-02 | App findet Roboter via mDNS/Bonjour (mit IP-Scan-Fallback) | NWBrowser(_valetudo._tcp) already Info.plist-declared; NetworkScanner IP sweep retained as fallback |
| DEBT-03 | Map-Pixel-Dekompression wird gecacht statt bei jedem Render neu berechnet | MapLayer.decompressedPixels is a computed property recomputed on every Canvas render; class-wrapper cache pattern documented |
</phase_requirements>

---

## Summary

Phase 2 replaces three performance anti-patterns: the 5-second polling loop in `RobotManager`, the brute-force IP scanner in `NetworkScanner`, and the uncached pixel decompression in `MapLayer`. No new user-visible screens are created — the changes are service-layer and model-layer only, with integration hooks into two existing views (`AddRobotView` for mDNS results, `MapView` for map-SSE lifecycle).

The three work streams are largely independent and can proceed in parallel. SSE is the most complex because it requires a new service actor, a mutation of the existing polling loop, and a `URLSession` configured for long-lived streaming. mDNS is self-contained in a new `NWBrowserService` class with a clear integration point in `NetworkScanner`. Map caching requires refactoring a single computed property and introducing a reference-type cache wrapper.

All pre-conditions for this phase are met: Phase 1 delivered `ErrorRouter`, `os.Logger` categories, and `KeychainStore`. The `Network` framework is already imported in `NetworkScanner.swift`. Info.plist already declares `NSBonjourServices: _valetudo._tcp` and `NSLocalNetworkUsageDescription` (confirmed in `project.yml` lines 31-32).

**Primary recommendation:** Build in order: (1) SSEConnectionManager + ValetudoAPI SSE method + RobotManager integration, (2) NWBrowserService + NetworkScanner delegation, (3) MapLayer cache refactor. This order surfaces the riskiest change (SSE lifecycle) first while network and cache work can be validated independently.

---

## Standard Stack

### Core (no new dependencies — all built on Apple frameworks)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `URLSession.bytes(for:)` | iOS 15+ | SSE streaming via AsyncBytes | Official Apple API for long-lived HTTP streams; no 3rd-party EventSource library needed |
| `Network.framework` | iOS 13+ | NWBrowser for mDNS, NWConnection for IP resolution | Already imported in NetworkScanner.swift; canonical Apple API for local network discovery |
| `Foundation.Task` | Swift 5.5+ | SSE task lifecycle management | Standard Swift concurrency; `Task` stored as property enables explicit cancel |

### No New Packages

This phase adds zero Swift Package Manager dependencies. All capabilities are native Apple APIs.

**Version verification:** Not applicable — all frameworks are OS-provided. Minimum deployment target is iOS 17 (confirmed from project context), well above the iOS 15 minimum for `URLSession.bytes`.

---

## Architecture Patterns

### Recommended Project Structure Changes

```
ValetudoApp/ValetudoApp/Services/
├── ValetudoAPI.swift          # Modified: add streamStateLines() and streamMapLines()
├── RobotManager.swift         # Modified: replace startRefreshing() polling with SSE+fallback
├── SSEConnectionManager.swift # NEW: actor managing SSE streams per robot
├── NetworkScanner.swift       # Modified: start NWBrowserService in parallel with IP scan
└── NWBrowserService.swift     # NEW: NWBrowser wrapper, ObservableObject

ValetudoApp/ValetudoApp/Models/
└── RobotMap.swift             # Modified: MapLayer cache class + decompressedPixels refactor

ValetudoApp/ValetudoApp/Views/
├── AddRobotView.swift         # Modified: show mDNS results alongside IP-scan results
└── MapView.swift              # Modified: start/stop map-SSE in .task/.onDisappear
```

### Pattern 1: SSEConnectionManager as actor

**What:** A Swift `actor` that owns a `[UUID: Task<Void, Never>]` dictionary. Each robot gets one long-lived `Task` iterating `URLSession.bytes.lines`. The actor ensures no two tasks for the same robot ever run simultaneously (actor isolation serializes all mutations to `tasks`).

**When to use:** One attributes-SSE per connected robot. Started when `addRobot` or `loadRobots` runs. Cancelled when `removeRobot` runs.

**Key implementation detail:** `URLSession` for SSE needs `timeoutIntervalForRequest = .infinity` and `timeoutIntervalForResource = .infinity`. The standard `ValetudoAPI.session` uses 10s/30s timeouts and will terminate SSE connections. A dedicated SSE session is required.

```swift
// Services/SSEConnectionManager.swift
actor SSEConnectionManager {
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var isConnected: [UUID: Bool] = [:]

    func isSSEActive(for robotId: UUID) -> Bool {
        isConnected[robotId] ?? false
    }

    func connect(
        robotId: UUID,
        api: ValetudoAPI,
        onAttributesUpdate: @escaping @Sendable ([RobotAttribute]) -> Void,
        onConnectionChange: @escaping @Sendable (Bool) -> Void
    ) {
        tasks[robotId]?.cancel()
        tasks[robotId] = Task {
            await streamWithReconnect(
                robotId: robotId,
                api: api,
                onAttributesUpdate: onAttributesUpdate,
                onConnectionChange: onConnectionChange
            )
        }
    }

    private func streamWithReconnect(
        robotId: UUID,
        api: ValetudoAPI,
        onAttributesUpdate: @escaping @Sendable ([RobotAttribute]) -> Void,
        onConnectionChange: @escaping @Sendable (Bool) -> Void
    ) async {
        while !Task.isCancelled {
            do {
                let bytes = try await api.streamStateLines()
                isConnected[robotId] = true
                onConnectionChange(true)

                for try await line in bytes.lines {
                    guard !Task.isCancelled else { break }
                    if line.hasPrefix("data:") {
                        let json = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        if let data = json.data(using: .utf8),
                           let attrs = try? JSONDecoder().decode([RobotAttribute].self, from: data) {
                            onAttributesUpdate(attrs)
                        }
                    }
                }
            } catch is CancellationError {
                break  // Do NOT swallow CancellationError
            } catch {
                // SSE dropped — signal fallback, wait 30s, retry
                isConnected[robotId] = false
                onConnectionChange(false)
                try? await Task.sleep(for: .seconds(30))
            }
        }
        isConnected[robotId] = false
        onConnectionChange(false)
    }

    func disconnect(robotId: UUID) {
        tasks[robotId]?.cancel()
        tasks.removeValue(forKey: robotId)
        isConnected.removeValue(forKey: robotId)
    }
}
```

### Pattern 2: ValetudoAPI SSE method (dedicated session)

**What:** A new method `streamStateLines()` on `ValetudoAPI` that uses a dedicated `URLSession` with infinite timeouts. Cannot reuse the existing session — timeout values must be overridden.

**Key detail:** The existing `ValetudoAPI.session` has `timeoutIntervalForRequest = 10`. SSE connections must have `.infinity` for both request and resource timeouts or iOS will close the connection after 10 seconds.

```swift
// In ValetudoAPI actor — add sseSession as a stored property
private lazy var sseSession: URLSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = .infinity
    config.timeoutIntervalForResource = .infinity
    if config_useSSL_and_ignoreCertErrors {
        return URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)
    }
    return URLSession(configuration: config)
}()

func streamStateLines() async throws -> URLSession.AsyncBytes {
    guard let baseURL = config.baseURL,
          let url = URL(string: "/api/v2/robot/state/attributes/sse", relativeTo: baseURL) else {
        throw APIError.invalidURL
    }
    var request = URLRequest(url: url)
    if let username = config.username, !username.isEmpty,
       let password = KeychainStore.password(for: config.id) {
        let creds = Data("\(username):\(password)".utf8).base64EncodedString()
        request.setValue("Basic \(creds)", forHTTPHeaderField: "Authorization")
    }
    let (bytes, response) = try await sseSession.bytes(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
    }
    return bytes
}

func streamMapLines() async throws -> URLSession.AsyncBytes {
    // Same pattern but path: /api/v2/robot/state/map/sse
}
```

### Pattern 3: RobotManager polling/SSE integration

**What:** `RobotManager.startRefreshing()` is modified to check SSE status before polling. If `SSEConnectionManager.isSSEActive(for: id)` returns `true`, the poll cycle skips that robot. The `redundant checkConnection()` call (identified in CONCERNS.md) is also removed — attributes fetch failure signals offline status directly.

**Critical rule (D-04):** SSE active = polling disabled for that robot. Never both simultaneously.

```swift
// RobotManager.swift — modified startRefreshing
private let sseManager = SSEConnectionManager()

private func startRefreshing() {
    refreshTask = Task {
        while !Task.isCancelled {
            // Connect SSE for all robots not yet connected
            for robot in robots {
                guard let api = apis[robot.id] else { continue }
                let alreadyConnected = await sseManager.isSSEActive(for: robot.id)
                if !alreadyConnected {
                    await sseManager.connect(
                        robotId: robot.id,
                        api: api,
                        onAttributesUpdate: { [weak self] attrs in
                            Task { @MainActor in
                                self?.applyAttributeUpdate(attrs, for: robot.id)
                            }
                        },
                        onConnectionChange: { [weak self] connected in
                            Task { @MainActor in
                                self?.sseConnectionChanged(connected, for: robot.id)
                            }
                        }
                    )
                }
            }

            // Poll only robots without active SSE
            await withTaskGroup(of: Void.self) { group in
                for robot in robots {
                    let sseActive = await sseManager.isSSEActive(for: robot.id)
                    if !sseActive {
                        group.addTask { await self.refreshRobot(robot.id) }
                    }
                }
            }
            try? await Task.sleep(for: .seconds(5))
        }
    }
}

private func sseConnectionChanged(_ connected: Bool, for id: UUID) {
    // ErrorRouter integration (D-06): show reconnecting indicator when SSE drops
}
```

### Pattern 4: NWBrowserService as ObservableObject

**What:** A `@MainActor final class NWBrowserService: ObservableObject` that wraps `NWBrowser`. It publishes `discovered: [DiscoveredRobot]`. `NetworkScanner` creates one instance and starts it immediately, then starts the IP scan after 3 seconds if mDNS yields nothing (D-08).

**TXT Record access:** `NWBrowser` results use `.bonjourWithTXTRecord` descriptor to get metadata. The result endpoint is `NWEndpoint.service(name:type:domain:interface:)` — IP is NOT directly available. Use `NWConnection` to resolve.

**Valetudo mDNS confirmed format:** Service type `_valetudo._tcp`, TXT records contain `friendlyName`, `model`, `version`, `manufacturer`, `systemId`.

```swift
// Services/NWBrowserService.swift
@MainActor
final class NWBrowserService: ObservableObject {
    @Published private(set) var discovered: [DiscoveredRobot] = []
    @Published private(set) var isBrowsing = false
    private var browser: NWBrowser?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "mDNS")

    func startBrowsing() {
        let params = NWParameters()
        params.includePeerToPeer = false
        browser = NWBrowser(
            for: .bonjourWithTXTRecord(type: "_valetudo._tcp", domain: "local."),
            using: params
        )
        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.handleResults(results)
            }
        }
        browser?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.isBrowsing = (state == .ready)
            }
        }
        browser?.start(queue: .main)
        isBrowsing = true
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        isBrowsing = false
    }

    private func handleResults(_ results: Set<NWBrowser.Result>) {
        discovered = results.compactMap { result -> DiscoveredRobot? in
            guard case let .service(name, _, _, _) = result.endpoint else { return nil }
            var friendlyName: String?
            var model: String?
            if case let .bonjour(txtRecord) = result.metadata {
                friendlyName = txtRecord.dictionary["friendlyName"]
                model = txtRecord.dictionary["model"]
            }
            // IP resolution deferred to NWConnection step (D-10)
            return DiscoveredRobot(host: name, name: friendlyName, model: model, mdnsEndpoint: result.endpoint)
        }
    }
}
```

**IP resolution (D-10):** After user selects an mDNS result, open a `NWConnection` to the endpoint (not a raw IP) and use `connection.currentPath?.remoteEndpoint` or resolve via `NWConnection` to get the actual IP for `RobotConfig.host`. Alternatively, attempt a direct connection using the `.service` endpoint — `URLSession` can resolve Bonjour service names if the connection is on the same network.

### Pattern 5: MapLayer pixel cache via reference-type wrapper

**What:** Introduce `MapLayerCache` as a `final class`. `MapLayer` (struct) holds a `let cache = MapLayerCache()`. The cache is a reference type, so struct copies share the same cache instance. `decompressedPixels` becomes a method call on the cache.

**Why D-13 matters:** `lazy var` on a struct requires `mutating` access. SwiftUI passes model structs as `let` (immutable). A `lazy var decompressedPixels` on a struct will not compile in a `let`-bound context. The class wrapper sidesteps this entirely.

**Pitfall 8 confirmed:** The prior research warning is accurate — the cache must be at the `MapLayer` level but stored as a reference type so struct copies share it.

```swift
// Models/RobotMap.swift — add cache class

final class MapLayerCache {
    private var cachedPixels: [Int]?

    func decompressedPixels(from layer: MapLayer) -> [Int] {
        if let cached = cachedPixels { return cached }
        let result = layer.computeDecompressedPixels()
        cachedPixels = result
        return result
    }

    func invalidate() { cachedPixels = nil }
}

struct MapLayer: Codable {
    let `__class`: String?
    let type: String?
    let pixels: [Int]?
    let compressedPixels: [Int]?
    let metaData: LayerMetaData?
    let dimensions: LayerDimensions?

    // Cache is a reference type — shared across struct copies
    let cache = MapLayerCache()

    enum CodingKeys: String, CodingKey {
        case `__class`, type, pixels, compressedPixels, metaData, dimensions
        // Note: 'cache' is excluded from CodingKeys — not serialized
    }

    /// Cached access — O(1) after first call per MapLayer instance
    var decompressedPixels: [Int] {
        cache.decompressedPixels(from: self)
    }

    /// Internal computation — only called by cache on miss
    fileprivate func computeDecompressedPixels() -> [Int] {
        if let pixels = pixels, !pixels.isEmpty { return pixels }
        guard let compressed = compressedPixels, !compressed.isEmpty else { return [] }
        var result: [Int] = []
        var i = 0
        while i < compressed.count - 2 {
            let x = compressed[i], y = compressed[i+1], count = compressed[i+2]
            for offset in 0..<count { result.append(x + offset); result.append(y) }
            i += 3
        }
        return result
    }
}
```

**Cache invalidation:** When new map data arrives from SSE or polling, `RobotManager` stores a new `RobotMap` (with new `MapLayer` instances). New instances have fresh `MapLayerCache` objects — no explicit invalidation needed. The cache is naturally scoped to one map version.

### Anti-Patterns to Avoid

- **Reusing the default URLSession for SSE:** The 10-second `timeoutIntervalForRequest` will kill SSE connections. Must use a dedicated SSE session with `.infinity` timeouts.
- **Running polling and SSE simultaneously:** Produces duplicate state updates and notification flicker. D-04 is absolute: check `isSSEActive` before every poll cycle.
- **Storing SSE Task in a local variable:** The Task will be deallocated when its scope exits but the URLSession connection stays open. Always store in `[UUID: Task<Void, Never>]` on the actor.
- **Swallowing CancellationError in SSE loop:** The reconnect-on-error loop will loop forever if it catches CancellationError. Always re-throw or break on cancellation.
- **`lazy var` on MapLayer struct directly:** Will not compile when the struct is passed as a `let` binding in SwiftUI Canvas closures. Use the class-wrapper pattern.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SSE parsing | Custom HTTP streaming parser | `URLSession.bytes(for:).lines` | Apple-provided AsyncSequence handles chunking, backpressure, connection management |
| mDNS/Bonjour discovery | BSD sockets DNS-SD calls | `NWBrowser` (Network.framework) | Handles local network permissions, TXT record parsing, result deduplication |
| IP-to-hostname resolution for mDNS results | Manual DNS lookup | `NWConnection` to the `NWEndpoint` | NWBrowser already returns a connectable endpoint — use it directly |
| Thread-safe connection registry | DispatchQueue + dictionary | Swift `actor` | Actor isolation eliminates lock/unlock boilerplate and data races |

**Key insight:** Valetudo SSE is standard HTTP with `Content-Type: text/event-stream`. No custom EventSource library (like IKEventSource or similar) is needed. Apple's `URLSession.bytes` async sequence handles the TCP connection lifecycle correctly.

---

## Common Pitfalls

### Pitfall 1: SSE session timeout kills connections after 10 seconds

**What goes wrong:** The existing `ValetudoAPI` session has `timeoutIntervalForRequest = 10`. SSE connections are long-lived by design. After 10 seconds of no complete HTTP response, iOS terminates the connection. The SSE task sees an error and starts the 30s reconnect timer — effectively the app never has a stable SSE connection.

**Why it happens:** `timeoutIntervalForRequest` in URLSession applies to the time to receive the first response headers AND the time between data packets. For SSE, long periods between events (robot idle) look like a stalled connection.

**How to avoid:** Create a separate `sseSession` stored property on `ValetudoAPI` with `timeoutIntervalForRequest = .infinity` and `timeoutIntervalForResource = .infinity`. Use it only for SSE streaming methods.

**Warning signs:** SSE reconnects every 10-30 seconds in logs. `[API]` category shows repeated SSE connection/disconnect cycles.

---

### Pitfall 2: NWBrowser provides endpoint, not IP — can't use it directly as host

**What goes wrong:** `NWBrowser.Result.endpoint` is `NWEndpoint.service(name:type:domain:interface:)`. This cannot be used directly as `RobotConfig.host` (which expects an IP or hostname). Storing the Bonjour service name as host will cause `URLSession` requests to fail in some network configurations.

**Why it happens:** Bonjour services resolve to IPs via the system resolver, but `NWBrowser` intentionally does not expose IPs to preserve flexibility.

**How to avoid:** Use one of two approaches:
1. **Direct connection via endpoint:** Use `NWConnection(to: result.endpoint, using: .tcp)` and read `connection.currentPath?.remoteEndpoint` after the connection succeeds to extract the IP.
2. **hostname approach:** The service name (e.g., `valetudo-XXXXX.local`) can work as a hostname in `URLRequest` on the same network. Store `name + ".local"` as host.

The hostname approach is simpler and more reliable for home network use. Confirmed working in the Valetudo iOS context from community sources.

**Warning signs:** Robots found via mDNS fail to connect. `URL(string:)` returns nil when service name contains special characters.

---

### Pitfall 3: SSE Task leak when robot is removed without explicit cancel

**What goes wrong:** `RobotManager.removeRobot()` currently clears `apis`, `robotStates`, and `previousStates` — but has no SSEConnectionManager reference. After this phase, if `sseManager.disconnect(robotId:)` is not called in `removeRobot()`, the streaming task continues running in the background indefinitely.

**Why it happens:** The `actor` holds its `tasks` dictionary. `deinit` on the manager doesn't help if the actor outlives the robot in the dictionary.

**How to avoid:** Add `await sseManager.disconnect(robotId: id)` inside `removeRobot()`. Also call it in `RobotManager.deinit` by cancelling `refreshTask` (which cascades to all SSE tasks via the actor being released).

**Warning signs:** Instruments Network profiler shows open TCP connections after robot removal. `[API]` logger category fires for robot IDs not in the current robots list.

---

### Pitfall 4: Map-SSE in MapView must cancel on onDisappear, not just onDisappear of the inner view

**What goes wrong:** `MapView` contains `MapContentView`. The existing `startLiveRefresh()` is called in `.task` on `MapContentView` and cancelled in `MapContentView.onDisappear`. If map-SSE is added to `MapView` (the outer shell), but the cancel hook is on the inner view, the SSE task may outlive the visible map session.

**Why it happens:** SwiftUI view hierarchy onDisappear ordering is not guaranteed in all cases.

**How to avoid:** Tie map-SSE `Task` lifecycle to the same view that owns the `@State private var refreshTask`. In the current code, `MapContentView` (at line 478) owns `refreshTask`. Map-SSE Task should be a parallel stored property on the same view, cancelled in the same `onDisappear` block.

---

### Pitfall 5: NWBrowser stateUpdateHandler fires .ready even without Local Network permission

**What goes wrong:** `NWBrowser.stateUpdateHandler` fires `.ready` immediately after `start()`. This is NOT confirmation that discovery is working. Without Local Network permission granted, `browseResultsChangedHandler` never fires but no error is returned.

**Why it happens:** iOS 14+ Local Network permission prompt only appears when actual network traffic is initiated. `NWBrowser` being "ready" means the framework is initialized, not that the OS has permitted discovery.

**How to avoid:** Do not use `.ready` state as a success indicator. After a 3-second window with zero results, assume mDNS failed (permission denied or Valetudo not advertising) and trigger IP fallback scan. The `NSLocalNetworkUsageDescription` in Info.plist (already present) ensures the permission dialog will appear.

---

## Code Examples

Verified patterns from codebase analysis and official Apple APIs:

### Current polling loop (to be replaced)

```swift
// RobotManager.swift lines 75-82 — CURRENT (to be replaced)
private func startRefreshing() {
    refreshTask = Task {
        while !Task.isCancelled {
            await refreshAllRobots()
            try? await Task.sleep(for: .seconds(5))
        }
    }
}
```

The replacement modifies `startRefreshing()` to: (a) connect SSE for each robot, (b) poll only robots without active SSE, (c) remove the redundant `checkConnection()` call inside `refreshRobot()`.

### Current map polling in MapView (to be replaced with map-SSE)

```swift
// MapView.swift lines 1877-1889 — CURRENT (to be replaced with map-SSE)
private func startLiveRefresh() {
    refreshTask?.cancel()
    refreshTask = Task {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled, let api = api {
                if let newMap = try? await api.getMap() {
                    await MainActor.run { map = newMap }
                }
            }
        }
    }
}
```

This 2-second poll loop inside MapView gets replaced with map-SSE streaming.

### Current MapLayer.decompressedPixels (to be cached)

```swift
// RobotMap.swift lines 30-59 — CURRENT (computed property, no cache)
var decompressedPixels: [Int] {
    if let pixels = pixels, !pixels.isEmpty { return pixels }
    guard let compressed = compressedPixels, !compressed.isEmpty else { return [] }
    var result: [Int] = []
    var i = 0
    while i < compressed.count - 2 {
        // ...run-length expansion...
    }
    return result
}
```

Every `Canvas { context, size in ... }` render pass calls this per layer. With the cache wrapper, first call computes, all subsequent calls return the cached `[Int]` directly.

### SSE event format (Valetudo-specific)

Valetudo SSE streams use standard Server-Sent Events format:

```
data: [{"__class":"StatusStateAttribute","value":"cleaning","flag":"none"},{"__class":"BatteryStateAttribute","level":87,"flag":"discharging"}]

data: [{"__class":"StatusStateAttribute","value":"docked","flag":"none"}]
```

The `data:` prefix is on each line. The payload is a JSON array of attribute objects (same schema as `GET /api/v2/robot/state/attributes`). Empty lines separate events. The parser should accumulate multi-line `data:` values (though Valetudo typically sends single-line events).

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Third-party EventSource libraries | `URLSession.bytes(for:).lines` | iOS 15 (2021) | No external dependencies needed |
| `CFNetServiceBrowser` (Core Foundation) | `NWBrowser` (Network.framework) | iOS 13 (2019) | Swift-native async API with modern permissions model |
| Manual TXT record parsing | `NWBrowser.Result.metadata` with `.bonjour(TXTRecord)` | iOS 13 | Direct dictionary access to TXT record keys |

**Deprecated/outdated:**
- `CFNetServiceBrowser` / `NSNetServiceBrowser`: Deprecated iOS 15. Use `NWBrowser`.
- Third-party Swift EventSource (IKEventSource, etc.): No longer necessary given `URLSession.bytes`.

---

## Open Questions

1. **Valetudo SSE event format: array vs single attribute**
   - What we know: `GET /api/v2/robot/state/attributes` returns `[RobotAttribute]` (array). Architecture research shows `data:` payload as array.
   - What's unclear: Whether map-SSE (`/state/map/sse`) sends a full `RobotMap` JSON or a diff format.
   - Recommendation: On first connection to map-SSE, log the raw `data:` line before decoding. If full `RobotMap`, decode as `RobotMap`. The safe approach is to attempt `JSONDecoder().decode(RobotMap.self, from:)` and fall back to a full `GET /robot/state/map` if decoding fails.

2. **NWBrowser result hostname vs IP for RobotConfig.host**
   - What we know: Bonjour service names (`valetudo-XXXXXX.local`) work as hostnames in local network URL requests on iOS.
   - What's unclear: Whether some network configurations (captive portals, VLANs) break `.local` resolution. Users on split networks may add robots via IP scan and see duplicate results.
   - Recommendation: Store hostname (`.local` address) from mDNS as `host`. Present mDNS results first; if user selects one and connection fails, show manual IP entry pre-filled.

3. **5-client SSE limit — behavior when exceeded**
   - What we know: Valetudo enforces a 5-client limit per SSE endpoint. `SSEConnectionManager` ensures one connection per robot.
   - What's unclear: What HTTP status code Valetudo returns when the limit is exceeded (likely 429 or a connection close without error body).
   - Recommendation: Treat any non-200 response from the SSE endpoint as a connection failure, fall back to polling, retry after 30s (D-03).

---

## Environment Availability

Step 2.6: SKIPPED — This phase is entirely code/config changes within the app. No external tools, CLI utilities, databases, or services beyond the robot itself (which is user-provided at runtime) are required. The Network.framework and URLSession are OS-provided.

---

## Validation Architecture

`workflow.nyquist_validation` is not set to `false` in config.json (key absent), so this section is included.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (no test target exists yet — Wave 0 gap) |
| Config file | None — test target to be created in Phase 4 (DEBT-04) |
| Quick run command | `xcodebuild test -scheme ValetudoApp -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ValetudoAppTests/MapLayerTests` |
| Full suite command | `xcodebuild test -scheme ValetudoApp -destination 'platform=iOS Simulator,name=iPhone 16'` |

**Note:** No test target exists in the project (confirmed in CONCERNS.md). Phase 4 creates the XCTest target (DEBT-04). For Phase 2, the map cache logic (`computeDecompressedPixels`) is the only unit-testable pure function introduced. SSE and mDNS cannot be unit-tested without mocks, which Phase 4 establishes. Manual verification is the primary validation path for this phase.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| NET-01 | SSE replaces polling — no double-update | Manual/Instruments | Instruments Network profiler: one connection per robot | N/A — manual |
| NET-01 | Polling resumes on SSE failure | Manual | Disconnect robot mid-stream, verify 5s poll restarts | N/A — manual |
| NET-02 | mDNS finds robot before IP scan completes | Manual device test | Run on real device, observe NWBrowser fires within 3s | N/A — manual |
| DEBT-03 | decompressedPixels not in hot path after first call | Unit + Instruments | `MapLayerTests.testCacheHit` — call twice, verify result is identical object | ❌ Wave 0 gap |

### Wave 0 Gaps

Since no XCTest target exists yet, Phase 2 cannot add test files. The planner should note that map cache logic is the primary candidate for future testing when Phase 4 creates the test target.

For this phase, manual validation on device is the gating check:
- [ ] SSE active: Instruments > Network shows 1 open connection per robot, 0 polling requests during SSE
- [ ] Fallback: Kill robot's network, verify status updates resume via 5s poll within 35s
- [ ] mDNS: Real device scan finds robot via mDNS before 3s mark (check logs)
- [ ] Cache: Instruments > Time Profiler shows `computeDecompressedPixels` absent from hot path during 30s map observation

---

## Project Constraints (from CLAUDE.md)

CLAUDE.md contains global server/infrastructure notes not applicable to this iOS project. No directives conflict with this phase's implementation approach.

---

## Sources

### Primary (HIGH confidence)

- Apple Developer Documentation: `URLSession.AsyncBytes` — `https://developer.apple.com/documentation/foundation/urlsession/asyncbytes` — SSE streaming via `.lines`
- Apple Developer Documentation: `NWBrowser` — `https://developer.apple.com/documentation/network/nwbrowser` — mDNS/Bonjour discovery
- Valetudo source: `NetworkAdvertisementManager.js` — `_valetudo._tcp` service type, TXT record keys confirmed
- Valetudo source: `RobotRouter.js` — `/api/v2/robot/state/attributes/sse` and `/api/v2/robot/state/map/sse` endpoints confirmed
- Codebase: `ValetudoApp/ValetudoApp/Services/RobotManager.swift` — exact polling loop (lines 75-82) to replace
- Codebase: `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift` — existing session config (10s/30s timeouts) confirms SSE session must be separate
- Codebase: `ValetudoApp/ValetudoApp/Models/RobotMap.swift` — `decompressedPixels` computed property (lines 30-59) to cache
- Codebase: `ValetudoApp/ValetudoApp/Views/MapView.swift` — `startLiveRefresh()` (lines 1877-1889) to replace with map-SSE
- Codebase: `ValetudoApp/project.yml` — lines 31-32 confirm `NSBonjourServices: _valetudo._tcp` and `NSLocalNetworkUsageDescription` already declared

### Secondary (MEDIUM confidence)

- `.planning/research/ARCHITECTURE.md` — SSEConnectionManager actor pattern, NWBrowserService pattern
- `.planning/research/PITFALLS.md` — Pitfalls 3, 4, 8 directly apply to this phase
- `.planning/research/FEATURES.md` — Valetudo SSE endpoints, mDNS TXT record fields

### Tertiary (LOW confidence — from prior roadmap research, not re-verified this session)

- Valetudo community: 5-client SSE limit behavior when exceeded (HTTP status code on limit exceeded not confirmed)
- `.local` hostname resolution via URLSession on iOS (works in common home network configurations; edge cases in complex network topologies unverified)

---

## Metadata

**Confidence breakdown:**
- SSE implementation pattern: HIGH — code structure matches Apple's documented `URLSession.bytes` API exactly; session timeout issue verified against existing `ValetudoAPI` session configuration
- mDNS/NWBrowser pattern: HIGH — `NWBrowser` API documented; Info.plist keys confirmed already in `project.yml`
- Map cache pattern: HIGH — struct + class-wrapper approach is the only valid solution given Swift's `mutating` restriction on `lazy var`
- SSE event payload format (map-SSE specifically): MEDIUM — attributes-SSE format confirmed via Valetudo source; map-SSE payload format inferred from HTTP polling response structure

**Research date:** 2026-03-27
**Valid until:** 2026-04-27 (stable Apple APIs, Valetudo API is not under active change)
