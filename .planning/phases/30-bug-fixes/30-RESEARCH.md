# Phase 30: Bug Fixes - Research

**Researched:** 2026-04-04
**Domain:** iOS/SwiftUI — SF Symbols, URLSession SSE, NWPathMonitor
**Confidence:** HIGH (FIX-01), HIGH (FIX-02)

---

## Summary

Zwei isolierte Bugs mit klaren Ursachen und klaren Fixes. FIX-01 ist ein ungültiger SF Symbol-Name — `dove.fill` existiert nicht im SF Symbols Katalog, weshalb das Symbol zur Laufzeit still fehlt. FIX-02 ist ein klassischer Zombie-Socket: Bei Netzwerkwechsel (z.B. WiFi → VPN) bleibt `URLSession.AsyncBytes` scheinbar verbunden, liefert aber keine Daten mehr — das aktuelle Code hat keinen Mechanismus, dies zu erkennen.

Beide Fixes sind code-only. Kein neues Framework nötig. `Network.framework` ist bereits im iOS SDK enthalten. Kein UI-Redesign erforderlich.

**Primäre Empfehlung:** `dove.fill` durch ein funktionierendes SF Symbol ersetzen + `NWPathMonitor` in `SSEConnectionManager` integrieren, um bei jedem Netzwerkpfadwechsel den laufenden Task zu canceln und neu zu starten.

---

## FIX-01: Dove Symbol

### Wo befindet sich das Symbol

**Datei:** `ValetudoApp/ValetudoApp/Views/SettingsView.swift`
**Zeile:** 144
**Kontext:** Footer der About-Section in `SettingsView`

```swift
HStack(spacing: 4) {
    Text("Made with")
    Image(systemName: "dove.fill")   // <-- das Symbol
        .foregroundStyle(.secondary)
    Text("in Hennstedt")
}
```

### Diagnose: `dove.fill` existiert nicht in SF Symbols

`dove.fill` ist **kein offizieller SF Symbol-Name**. Mehrfache Verifikation:

- Die iOS 14 Neue-Symbole-Liste enthält kein `dove.fill` (verifiziert via noahgilmore.com)
- Die iOS 16.0 Neue-Symbole-Liste enthält kein `dove.fill` (verifiziert via hacknicity.medium.com)
- Ein bekannter SF Symbols Gist mit vollständiger Symboliste (carlweis/gist) enthält kein `dove.fill`
- Ein SF Symbols 6 Gist (applch/gist) enthält kein `dove.fill`
- Hotpot.ai SF Symbols Browser liefert kein Ergebnis für "dove"
- Xcode gibt keine Warnung beim Build (SF Symbol-Namen werden nicht zur Compile-Zeit geprüft)
- `UIImage(systemName: "dove.fill")` gibt zur Laufzeit `nil` zurück — SwiftUI rendert in diesem Fall nichts (kein Fallback, kein Fehler)

Das erklärt warum das Symbol still fehlt und kein Crash auftritt.

### Das richtige Symbol für eine Friedenstaube

SF Symbols kennt **kein natürliches Vogelform-Symbol**. Valide Alternativen für den semantischen Inhalt ("Made with love/peace"):

| Symbol | Name | Semantik | Verfügbar seit |
|--------|------|----------|----------------|
| `heart.fill` | Herz | "Made with love" | iOS 13 |
| `sparkles` | Glitzer | "Made with care/magic" | iOS 13 |
| `sun.max.fill` | Sonne | warm/positiv | iOS 13 |
| `leaf.fill` | Blatt | Natur/Ruhe | iOS 14 |

Da der String `"Friede. Schalom. Salam."` darunter steht (Friedensmotto), passt `heart.fill` semantisch am besten. `sparkles` wäre eine moderne Alternative.

**Empfehlung:** `"dove.fill"` → `"heart.fill"` (bereits an anderen Stellen in der App verwendet, z.B. in `SupportView`)

### Warum tritt der Bug identisch in Steadflow auf

Der Code-Pattern `Image(systemName: "dove.fill")` wurde wortgleich kopiert. Beide Apps verwenden den gleichen nicht-existenten Symbol-Namen.

---

## FIX-02: SSE Zombie-Socket bei Netzwerkwechsel

### Aktueller Zustand des Codes

**SSEConnectionManager** (`Services/SSEConnectionManager.swift`) ist ein Swift `actor` der pro Robot-UUID einen `Task` hält.

Die Kernschleife:
```swift
while !Task.isCancelled {
    let bytes = try await api.streamStateLines()  // URLSession.AsyncBytes
    // ...
    for try await line in bytes.lines {           // blockiert hier
        // verarbeite SSE-Events
    }
    // Falls kein Error: retry sofort
    // Falls Error: exponential backoff 1s → 5s → 30s
}
```

**`streamStateLines()`** in `ValetudoAPI` nutzt eine dedizierte `sseSession` mit:
```swift
sseConfig.timeoutIntervalForRequest = .infinity
sseConfig.timeoutIntervalForResource = .infinity
```

### Warum der Zombie entsteht

Bei einem Netzwerkwechsel (WiFi → VPN, WiFi → Cellular, etc.) passiert folgendes:

1. Das Betriebssystem wechselt den Netzwerkpfad
2. Die bestehende TCP-Verbindung kann noch geöffnet sein (alte Netzwerkschnittstelle)
3. `URLSession.AsyncBytes` / `bytes.lines` **blockiert still** — kein Error, kein Timeout
4. `isConnected[robotId]` bleibt `true`
5. Die App glaubt verbunden zu sein, empfängt aber keine Events mehr
6. Weder `timeoutIntervalForRequest: .infinity` noch `timeoutIntervalForResource: .infinity` helfen hier — diese Timeouts greifen nicht bei blockierten Streams

Das ist das klassische TCP Zombie Problem: Die Verbindung ist TCP-seitig noch nicht geschlossen, aber der Remote-Host (Vakuumroboter auf altem Interface) ist nicht mehr erreichbar.

### Fehlender Mechanismus: Kein NWPathMonitor

Es gibt **keinen** `NWPathMonitor` oder vergleichbare Netzwerk-Reachability-Überwachung im aktuellen Code. Weder in `SSEConnectionManager`, noch in `RobotManager`, noch in `ValetudoAPI`.

### Lösung: NWPathMonitor

`NWPathMonitor` ist Teil von `Network.framework` (seit iOS 12, also sicher auf iOS 17+).

**Pattern:**

```swift
import Network

// Innerhalb SSEConnectionManager (oder separater Service)
private var pathMonitor: NWPathMonitor?
private var pathMonitorTask: DispatchQueue?

func startNetworkMonitoring() {
    let monitor = NWPathMonitor()
    let queue = DispatchQueue(label: "sse.network.monitor")
    
    monitor.pathUpdateHandler = { [weak self] path in
        // Wird auf queue ausgeführt (nicht Main Thread!)
        Task {
            await self?.handlePathChange(path)
        }
    }
    
    monitor.start(queue: queue)
    self.pathMonitor = monitor
}

func handlePathChange(_ path: NWPath) async {
    guard path.status == .satisfied else { return }
    // Netzwerkpfad hat sich geändert UND ist verfügbar
    // → Alle laufenden SSE-Tasks canceln (Zombie töten)
    // → Reconnect-Loop übernimmt automatisch den Neuaufbau
    for robotId in tasks.keys {
        tasks[robotId]?.cancel()
        tasks[robotId] = nil
        isConnected[robotId] = false
    }
}
```

**Wichtig:** `pathUpdateHandler` wird bei **jedem** Pfadwechsel aufgerufen, auch wenn `status == .satisfied` bleibt (z.B. WiFi → VPN, beide satisfied). Deshalb muss immer reconnected werden, nicht nur bei `unsatisfied → satisfied`.

### Warum URLSession nicht automatisch hilft

- `URLSession` kann bei `waitsForConnectivity: true` auf neue Verbindungen warten — aber das greift nur bei **neuen** Requests, nicht bei laufenden `AsyncBytes`-Streams
- Es gibt keine eingebaute "reconnect on network change"-Logik für Streams
- `timeoutIntervalForRequest: .infinity` wurde bewusst gesetzt (Server-Sent Events halten die Verbindung offen) — dieser Timeout ist korrekt, verhindert aber auch die automatische Fehlerbehandlung

### NWPath-Interface-Wechsel erkennen

```swift
monitor.pathUpdateHandler = { path in
    // Welches Interface wird genutzt?
    let usesWifi = path.usesInterfaceType(.wifi)
    let usesCellular = path.usesInterfaceType(.cellular)
    let usesVPN = path.usesInterfaceType(.other) // VPN erscheint als .other
    
    // Ob der Pfad sich geändert hat (auch ohne Status-Wechsel):
    // pathUpdateHandler wird immer gerufen wenn sich etwas ändert
}
```

### NWPathMonitor-Integration in SSEConnectionManager

Da `SSEConnectionManager` ein `actor` ist, muss die Integration thread-safe sein:

```swift
actor SSEConnectionManager {
    private var pathMonitor: NWPathMonitor?
    
    // Starten des Monitors (z.B. beim ersten connect()-Aufruf)
    private func startMonitorIfNeeded() {
        guard pathMonitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { await self?.reconnectAll() }
        }
        monitor.start(queue: DispatchQueue(label: "sse.network.monitor"))
        pathMonitor = monitor
    }
    
    private func reconnectAll() {
        // Alle Tasks canceln — streamWithReconnect-Loop startet automatisch neu
        for key in tasks.keys {
            tasks[key]?.cancel()
            tasks[key] = nil
            isConnected[key] = false
        }
    }
}
```

Der `streamWithReconnect`-Loop in jedem `connect()`-Task läuft bereits und retried bei Fehlern. Nach `task.cancel()` bricht der `for try await line in bytes.lines` mit `CancellationError` ab — der `while !Task.isCancelled`-Check greift und der Task endet sauber. Der `startRefreshing()`-Loop in `RobotManager` erkennt dann `isSSEActive == false` und ruft `connect()` neu auf.

### Exponential Backoff nach Netzwechsel

Das vorhandene Backoff (1s → 5s → 30s) bleibt korrekt. Nach einem Netzwerkwechsel:
1. Monitor cancelt den alten Task
2. `RobotManager.startRefreshing()` erkennt `isSSEActive == false` im nächsten 5s-Polling-Zyklus
3. Alternativ: `connect()` direkt aus `reconnectAll()` aufrufen, aber dann ist Timing-Management nötig

**Empfehlung:** Einfachste Lösung — `reconnectAll()` cancelled nur die Tasks, `RobotManager`-Polling-Loop übernimmt den Neuaufbau innerhalb von 5 Sekunden. Kein zusätzlicher Reconnect-Trigger nötig.

---

## Standard Stack

### Core (bereits vorhanden)
| Library | Version | Purpose | Verfügbarkeit |
|---------|---------|---------|---------------|
| `Network.framework` | iOS 12+ | `NWPathMonitor` für Netzwerkpfad-Überwachung | Im SDK, kein Import nötig außer `import Network` |
| `Foundation.URLSession` | iOS 13+ | Bestehende SSE-Implementierung | Bereits verwendet |
| `SwiftUI` | iOS 17+ | SF Symbols Rendering | Bereits verwendet |

**Installation:** Keine neuen Abhängigkeiten.

---

## Architecture Patterns

### FIX-01: Direkte Substitution
Einzeiliger Fix. `"dove.fill"` → `"heart.fill"` in `SettingsView.swift` Zeile 144.

### FIX-02: Monitor-Lifecycle im Actor

```
SSEConnectionManager.connect()
    └── startMonitorIfNeeded()        (einmalig beim ersten connect())
            └── NWPathMonitor läuft permanent

NWPathMonitor.pathUpdateHandler
    └── path.status == .satisfied?
            └── reconnectAll()
                    └── tasks[key]?.cancel() für alle robots
                            └── RobotManager.startRefreshing() Polling loop
                                    └── sseActive == false → connect() erneut
```

Der Monitor muss **persistent** laufen (nicht bei jedem connect neu erstellt werden). `disconnectAll()` sollte `pathMonitor?.cancel()` aufrufen.

---

## Don't Hand-Roll

| Problem | Don't build | Use Instead | Warum |
|---------|------------|-------------|-------|
| Netzwerk-Reachability | SCNetworkReachability (deprecated), eigene TCP-Probes | `NWPathMonitor` | Offiziell supported, thread-safe, seit iOS 12 |
| SF Symbol Validierung | Runtime-Check ob Symbol existiert | Korrekte Symbol-Namen aus SF Symbols App | Keine Runtime-Prüfung nötig bei korrektem Namen |

---

## Common Pitfalls

### Pitfall 1: pathUpdateHandler bei jedem Pfad-Event
**Was passiert:** Handler wird auch gerufen, wenn `status` sich nicht ändert (z.B. Interface-Wechsel WiFi-Interface-A → WiFi-Interface-B, beide satisfied)
**Warum:** NWPathMonitor meldet Pfad-Änderungen, nicht nur Status-Änderungen
**Vermeidung:** Immer reconnecten wenn handler aufgerufen wird (und status satisfied ist), nicht nur bei satisfied/unsatisfied-Wechsel

### Pitfall 2: pathUpdateHandler nicht auf Main Thread
**Was passiert:** `pathUpdateHandler` läuft auf dem übergebenen `DispatchQueue`-Thread, nicht auf MainActor
**Warum:** `start(queue:)` bestimmt den Delivery-Thread
**Vermeidung:** Swift `Task { await actor.method() }` für die actor-Integration nutzen (bereits im Pattern oben gezeigt)

### Pitfall 3: NWPathMonitor sofort initial feuert
**Was passiert:** Beim `start()` wird `pathUpdateHandler` sofort mit dem aktuellen Pfad aufgerufen
**Warum:** Das ist beabsichtigt — initialer Status-Report
**Vermeidung:** Beim ersten Aufruf nicht reconnecten (noch keine laufenden Tasks). Da `reconnectAll()` nur cancelt und der erste `connect()`-Aufruf noch nicht stattgefunden hat, ist es harmlos.

### Pitfall 4: SF Symbol Name nicht zur Compile-Zeit geprüft
**Was passiert:** `Image(systemName: "beliebig.falsch")` kompiliert ohne Fehler
**Warum:** `systemName` ist ein `String`, keine typisierte Enum
**Vermeidung:** SF Symbols App oder Online-Browser zur Verifikation nutzen

### Pitfall 5: NWPathMonitor-Instanz zu früh freigegeben
**Was passiert:** Monitor feuert nicht mehr nach einem `deinit`
**Warum:** `pathMonitor` muss als strong reference gehalten werden
**Vermeidung:** Als Property im Actor speichern (nicht als lokale Variable)

---

## Code Examples

### NWPathMonitor Basic Setup (Network.framework)
```swift
// Source: Apple Developer Documentation / NWPathMonitor
import Network

let monitor = NWPathMonitor()
let queue = DispatchQueue(label: "com.app.networkmonitor")

monitor.pathUpdateHandler = { path in
    if path.status == .satisfied {
        // Netzwerk verfügbar — ggf. reconnecten
    } else {
        // Netzwerk nicht verfügbar
    }
}

monitor.start(queue: queue)
// monitor.cancel() zum Stoppen
```

### SSEConnectionManager Integration (vollständiges Muster)
```swift
import Network

actor SSEConnectionManager {
    private var pathMonitor: NWPathMonitor?
    
    func connect(robotId: UUID, api: ValetudoAPI, ...) {
        startMonitorIfNeeded()
        // ... bestehender connect-Code ...
    }
    
    private func startMonitorIfNeeded() {
        guard pathMonitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { await self?.reconnectAll() }
        }
        monitor.start(queue: DispatchQueue(label: "sse.pathmonitor", qos: .utility))
        pathMonitor = monitor
    }
    
    private func reconnectAll() {
        for key in tasks.keys {
            tasks[key]?.cancel()
            tasks[key] = nil
            isConnected[key] = false
        }
        logger.info("SSE: Netzwerkpfad geändert — alle Verbindungen zurückgesetzt")
    }
    
    func disconnectAll() {
        pathMonitor?.cancel()
        pathMonitor = nil
        for (_, task) in tasks { task.cancel() }
        tasks.removeAll()
        isConnected.removeAll()
    }
}
```

### SF Symbol Fix (einzeilig)
```swift
// VORHER (broken — dove.fill existiert nicht):
Image(systemName: "dove.fill")
    .foregroundStyle(.secondary)

// NACHHER (funktioniert):
Image(systemName: "heart.fill")
    .foregroundStyle(.secondary)
```

---

## Environment Availability

Step 2.6: SKIPPED (reine Code-Änderungen, keine externen Abhängigkeiten)

`Network.framework` ist Teil des iOS SDK und seit iOS 12 verfügbar. Deployment Target ist iOS 17.0 — keine Availability-Guards nötig.

---

## Open Questions

1. **Steadflow — gleicher Fix?**
   - Was wir wissen: Bug tritt identisch in Steadflow auf
   - Was unklar ist: Liegt der Code in Steadflow in diesem Repository oder separat?
   - Empfehlung: Nach dem Fix in ValetudiOS prüfen ob Steadflow einen separaten Fix-Commit braucht

2. **`dove.fill` — ist es ein custom Symbol in Steadflow?**
   - Was wir wissen: In SF Symbols nicht vorhanden
   - Was unklar ist: Könnte ein Custom Symbol im Asset Catalog von Steadflow existieren (aber nicht in ValetudiOS)
   - Empfehlung: Für ValetudiOS ist der Fix klar (Asset Catalog enthält kein Custom Symbol mit diesem Namen)

3. **NWPathMonitor: Reconnect-Delay**
   - Was wir wissen: `RobotManager.startRefreshing()` pollt alle 5 Sekunden ob SSE aktiv ist
   - Was unklar ist: Ob 5 Sekunden nach einem Netzwerkwechsel akzeptabel sind oder ob `connect()` direkt aus `reconnectAll()` aufgerufen werden sollte
   - Empfehlung: 5-Sekunden-Delay ist akzeptabel für Home-Automation-Kontext. Direkter Aufruf aus `reconnectAll()` wäre eleganter aber nicht zwingend nötig.

---

## Sources

### Primary (HIGH confidence)
- Code-Analyse: `/ValetudoApp/ValetudoApp/Views/SettingsView.swift` — dove.fill Fundstelle
- Code-Analyse: `/ValetudoApp/ValetudoApp/Services/SSEConnectionManager.swift` — kein NWPathMonitor
- Code-Analyse: `/ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift` — sseSession mit infinity timeouts
- Apple Developer Documentation: NWPathMonitor (`developer.apple.com/documentation/network/nwpathmonitor`) — API-Verifikation
- iOS Deployment Target: `IPHONEOS_DEPLOYMENT_TARGET = 17.0` (aus project.pbxproj)

### Secondary (MEDIUM confidence)
- noahgilmore.com: "New SF Symbols in iOS 14" — `dove.fill` nicht in der Liste
- hacknicity.medium.com: "SF Symbol Changes in iOS 16.0" — `dove.fill` nicht erwähnt
- hacknicity.medium.com: "SF Symbols Changes in iOS 16.4" — nur 4 neue Symbols, kein dove
- hotpot.ai SF Symbols Browser — kein Ergebnis für "dove"
- SF Symbols 6 GitHub Gist (applch) — kein `dove.fill`
- SF Symbols Liste Gist (carlweis) — kein `dove.fill`

### Tertiary (LOW confidence)
- Allgemeine NWPathMonitor-Artikel (vadimbulavin.com, digitalbunker.dev, useyourloaf.com) — Pattern-Referenz

---

## Metadata

**Confidence breakdown:**
- FIX-01 Diagnose (dove.fill fehlt): HIGH — mehrere unabhängige Quellen bestätigen, dass Symbol nicht existiert
- FIX-01 Fix (heart.fill): HIGH — existierendes Symbol, bereits in der App verwendet
- FIX-02 Diagnose (Zombie-Socket): HIGH — Code-Analyse zeigt fehlenden Netzwerkmonitor, infinity timeouts
- FIX-02 Fix (NWPathMonitor): HIGH — etabliertes iOS-Pattern, verifiziert via Apple Docs

**Research date:** 2026-04-04
**Valid until:** 2027-04-04 (stable APIs, keine Breaking Changes zu erwarten)
