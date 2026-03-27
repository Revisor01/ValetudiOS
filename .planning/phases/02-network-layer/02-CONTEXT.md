# Phase 2: Network Layer - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning
**Source:** Auto-mode (recommended defaults selected)

<domain>
## Phase Boundary

Phase 2 ersetzt das 5-Sekunden-Polling durch Valetudo SSE-Streams, fügt mDNS/Bonjour-basierte Roboter-Erkennung hinzu und cached die Map-Pixel-Dekompression. Keine neuen UI-Screens, keine neuen API-Capabilities.

</domain>

<decisions>
## Implementation Decisions

### SSE Real-Time Updates (NET-01)
- **D-01:** Eine SSE-Verbindung pro Robot für `/api/v2/robot/state/attributes/sse` (immer aktiv wenn Robot verbunden). Map-SSE (`/api/v2/robot/state/map/sse`) nur wenn MapView geöffnet ist
- **D-02:** SSEConnectionManager als neuer Service (ObservableObject), managed Verbindungen pro Robot-ID. Nutzt `URLSession.bytes(for:).lines` für SSE-Parsing
- **D-03:** Bei SSE-Verbindungsfehler: automatischer Fallback auf 5s-Polling. Reconnect-Versuch alle 30 Sekunden. Übergang transparent für User
- **D-04:** Wenn SSE aktiv und funktioniert: Polling explizit deaktiviert (nie beides gleichzeitig — Pitfall aus Research)
- **D-05:** SSE-Events updaten `RobotManager.robotStates` direkt — bestehende View-Bindings funktionieren ohne Änderung
- **D-06:** ErrorRouter.show() bei SSE-Verbindungsfehlern nutzen (Error-Surfacing aus Phase 1 aktivieren)

### mDNS/Bonjour Discovery (NET-02)
- **D-07:** NWBrowser für `_valetudo._tcp` Service Discovery. NSBonjourServices und NSLocalNetworkUsageDescription bereits in Info.plist deklariert
- **D-08:** Parallel-Strategie: NWBrowser startet sofort, IP-Scan startet nach 3s Timeout wenn mDNS keine Ergebnisse liefert
- **D-09:** mDNS-Ergebnisse enthalten TXT-Records (model, version, friendlyName) — diese in der AddRobotView anzeigen
- **D-10:** IP-Auflösung des mDNS-Endpoints via temporäre NWConnection (NWBrowser liefert Endpoint, nicht IP)
- **D-11:** NSBonjourServices muss vor NWBrowser-Code in project.yml eingetragen werden (Pitfall: lautloser Fehlschlag ohne Info.plist-Eintrag)

### Map-Pixel-Caching (DEBT-03)
- **D-12:** MapLayer.decompressedPixels wird von computed property zu lazy stored property. Cache wird invalidiert wenn neue Map-Daten ankommen (neues MapLayer-Objekt)
- **D-13:** Da MapLayer ein Struct ist, muss der Cache als separate class-basierte Referenz implementiert werden (Structs können keine lazy var mit Mutation haben ohne mutating context)

### Claude's Discretion
- SSE-Parsing-Details (Event-Format, Retry-Logik)
- NWBrowser Lifecycle (wann starten/stoppen)
- Konkrete Cache-Implementierung (NSCache vs. eigene Klasse)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Services (zu modifizieren/erstellen)
- `ValetudoApp/ValetudoApp/Services/RobotManager.swift` — Polling-Loop ersetzen durch SSE, State-Updates
- `ValetudoApp/ValetudoApp/Services/NetworkScanner.swift` — mDNS-Discovery hinzufügen
- `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift` — SSE-Endpoint-Methoden hinzufügen

### Models (zu modifizieren)
- `ValetudoApp/ValetudoApp/Models/RobotMap.swift` — MapLayer.decompressedPixels Caching

### Views (zu modifizieren)
- `ValetudoApp/ValetudoApp/Views/AddRobotView.swift` — mDNS-Ergebnisse anzeigen
- `ValetudoApp/ValetudoApp/Views/MapView.swift` — Map-SSE starten/stoppen

### Research
- `.planning/research/ARCHITECTURE.md` — SSE via URLSession.bytes, NWBrowser-Pattern
- `.planning/research/PITFALLS.md` — SSE+Polling Race Condition, NWBrowser Info.plist, Map-Cache struct vs class
- `.planning/research/FEATURES.md` — Valetudo SSE-Endpoints, mDNS Service Type

### Prior Phase Context
- `.planning/phases/01-foundation/01-CONTEXT.md` — ErrorRouter, os.Logger Patterns

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ErrorRouter` (Phase 1) — für SSE-Verbindungsfehler nutzen
- `os.Logger` (Phase 1) — neue Kategorien für SSE und mDNS
- `ValetudoAPI` actor — SSE-Methoden hinzufügen
- `Network` Framework bereits importiert in NetworkScanner.swift

### Established Patterns
- ObservableObject + @EnvironmentObject für Services
- `@Published` Properties für reaktive UI-Updates
- Swift actor für Thread-Safe API-Zugriff

### Integration Points
- `RobotManager.startRefreshing()` — Polling-Loop durch SSE ersetzen
- `NetworkScanner` — NWBrowser parallel zu IP-Scan
- `MapView` — Map-SSE bei onAppear/onDisappear

</code_context>

<specifics>
## Specific Ideas

- Valetudo SSE hat 5-Client-Limit pro Endpoint — SSEConnectionManager muss geteilte Verbindung pro Robot erzwingen
- URLSession.bytes(for:).lines ist der offizielle Apple-Weg für SSE (seit iOS 15)
- NWBrowser TXT-Records enthalten friendlyName — kann für Robot-Anzeige bei Discovery genutzt werden

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-network-layer*
*Context gathered: 2026-03-27 via auto-mode*
