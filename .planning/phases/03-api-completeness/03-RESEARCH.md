# Phase 3: API Completeness - Research

**Researched:** 2026-03-27
**Domain:** Valetudo REST API v2 Capabilities, SwiftUI, UNUserNotificationCenter, iOS URLSession binary streaming
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**API-Capabilities UI-Pattern**
- D-01: Map-Snapshot und Map-Reset Aktionen werden in RobotSettingsView platziert — dort sind bereits Karten-Einstellungen (PersistentMap, VirtualRestrictions)
- D-02: Reinigungsrouten werden als Picker in RobotDetailView angezeigt — analog zu bestehendem Fan-Speed/Water-Usage Picker mit Capability-Check
- D-03: Obstacle-Fotos werden in einer neuen ObstaclePhotoView angezeigt — accessible via Event-Liste, Lazy-Loading der Bilder
- D-04: Valetudo Events als neue EventsView Section in RobotDetailView — chronologische Liste mit Event-Typ-Icons (DustBinFull, MopReminder etc.)

**Notification-Actions**
- D-05: UNNotificationResponse-Handler wird in NotificationService implementiert — dort sind bereits die Actions registriert
- D-06: Handler greift über RobotManager auf ValetudoAPI zu — bestehender Pattern via apis Dictionary und selectedRobotId
- D-07: Wenn kein Roboter ausgewählt: Aktion auf ersten verfügbaren Roboter ausführen (User hat meist nur einen)

**Capability-Gating**
- D-08: UI-Elemente werden ausgeblendet wenn Capability fehlt — bestehendes Pattern mit capabilities Check
- D-09: Capabilities werden einmal beim Robot-Connect gecheckt (getCapabilities) — bereits in RobotManager implementiert, in RobotStatus.capabilities gecacht
- D-10: Graceful Degradation für Obstacle-Fotos: Events ohne Fotos zeigen nur Text, Foto-Button nur wenn ObstacleImagesCapability vorhanden

### Claude's Discretion

No specific areas marked as discretion — all implementation approaches are decided in D-01 through D-10.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| API-01 | Benutzer kann Map-Snapshots erstellen und wiederherstellen | MapSnapshotCapability: GET /robot/capabilities/MapSnapshotCapability (list), PUT with `{"action":"restore","id":"<id>"}` (restore). Snapshot creation is not exposed via API — only list+restore. |
| API-02 | Benutzer kann ausstehende Kartenänderungen akzeptieren/ablehnen | PendingMapChangeHandlingCapability: GET returns `{"enabled": bool}`, PUT with `{"action":"accept"}` or `{"action":"reject"}` |
| API-03 | Benutzer kann Reinigungsroute wählen (Standard, Bow-Tie, Spiral etc.) | CleanRouteControlCapability: GET returns `{"route":"normal"}`, PUT with `{"route":"normal"|"quick"|"intensive"|"deep"}`. Note: route names differ from phase description — no "bow-tie" or "spiral" in API; actual values are normal/quick/intensive/deep |
| API-04 | Benutzer kann Fotos erkannter Hindernisse ansehen | Obstacle entity in map data: `__class: "PointMapEntity"`, `type: "obstacle"`, `metaData.id` = image UUID. Fetch image: GET /robot/capabilities/ObstacleImagesCapability/img/{id} returns JPEG/PNG binary |
| UX-03 | Notification-Actions GO_HOME und LOCATE führen die jeweilige Aktion aus | NotificationService bereits hat setupCategories() mit GO_HOME/LOCATE actions. Fehlt: UNUserNotificationCenterDelegate + @UIApplicationDelegateAdaptor in ValetudoApp.swift |
| UX-04 | Benutzer kann Valetudo Events einsehen | GET /valetudo/events returns array of event objects mit `__class`, `id`, `timestamp`, `processed`. Event-Typen: DustBinFullValetudoEvent, ConsumableDepletedValetudoEvent, MopAttachmentReminderValetudoEvent, ErrorStateValetudoEvent, MissingResourceValetudoEvent, PendingMapChangeValetudoEvent |
</phase_requirements>

## Summary

Phase 3 fügt sechs zusammenhängende Valetudo-Capabilities in die bestehende App ein. Alle API-Endpunkte sind in der offiziellen OpenAPI-Dokumentation des Valetudo-Backends vollständig dokumentiert und folgen dem bereits etablierten `PUT /robot/capabilities/<CapabilityName>` Muster.

Die drei kritischsten Erkenntnisse: Erstens existiert kein API-Endpunkt zum *Erstellen* von Map-Snapshots — nur Auflistung und Wiederherstellung sind exposed (Snapshots werden automatisch von der Robot-Firmware erstellt). Zweitens hat CleanRouteControlCapability vier Routen (`normal`, `quick`, `intensive`, `deep`), nicht die im Phase-Ziel erwähnten "Bow-Tie" oder "Spiral" — diese sind robot-vendor-spezifisch und werden in der Core-Capability nicht unterschieden. Drittens erfordert die UNNotificationResponse-Behandlung einen AppDelegate-Adapter in der SwiftUI-App, da kein `AppDelegate` existiert.

**Primary recommendation:** Implementiere in der Reihenfolge: (1) ValetudoAPI-Methoden für alle 5 neuen Capabilities, (2) Model-Structs für Events und MapSnapshots, (3) NotificationService als UNUserNotificationCenterDelegate via AppDelegate, (4) UI-Sections in bestehenden Views, (5) neue EventsView + ObstaclePhotoView.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17.0+ (system) | UI-Schicht | Projektstandard, kein Wechsel |
| UserNotifications | iOS 17.0+ (system) | UNUserNotificationCenterDelegate | Bereits verwendet für Action-Registration |
| Foundation URLSession | iOS 17.0+ (system) | Binary image fetch (obstacle photos) | Bereits in ValetudoAPI actor verwendet |
| os.Logger | iOS 17.0+ (system) | Structured logging | Projektstandard seit Phase 1 |

### No New Dependencies

Das Projekt hat null externe Dependencies. Phase 3 führt keine neuen ein — alle Valetudo-Capabilities werden mit vorhandenen Apple-Frameworks implementiert.

## Architecture Patterns

### Recommended Project Structure — New Files
```
Services/
└── NotificationService.swift   # Erweiterung: +UNUserNotificationCenterDelegate

Models/
├── RobotState.swift            # Erweiterung: +ValetudoEvent, +MapSnapshot structs
└── (keine neuen Dateien)

Views/
├── RobotDetailView.swift       # Erweiterung: Events Section, CleanRoute Picker
├── RobotSettingsView.swift     # Erweiterung: Map Snapshot Section
└── ObstaclePhotoView.swift     # NEU: Obstacle-Foto Vollbild-Anzeige

ValetudoApp.swift               # Erweiterung: +AppDelegate mit @UIApplicationDelegateAdaptor
```

### Pattern 1: Neue ValetudoAPI-Methoden (etabliertes Muster)

**What:** Jede neue Capability bekommt MARK-Kommentar-Block und kurze async-throws-Methoden in ValetudoAPI.swift.

**Example:**
```swift
// Source: https://raw.githubusercontent.com/Hypfer/Valetudo/master/backend/lib/webserver/capabilityRouters/doc/MapSnapshotCapabilityRouter.openapi.json
// MARK: - Map Snapshot
func getMapSnapshots() async throws -> [MapSnapshot] {
    return try await request("/robot/capabilities/MapSnapshotCapability")
}

func restoreMapSnapshot(id: String) async throws {
    let body = ["action": "restore", "id": id]
    try await requestVoid("/robot/capabilities/MapSnapshotCapability", method: "PUT", body: body)
}

// MARK: - Pending Map Change
func getPendingMapChange() async throws -> PendingMapChangeState {
    return try await request("/robot/capabilities/PendingMapChangeHandlingCapability")
}

func handlePendingMapChange(action: String) async throws {
    let body = ["action": action] // "accept" or "reject"
    try await requestVoid("/robot/capabilities/PendingMapChangeHandlingCapability", method: "PUT", body: body)
}

// MARK: - Clean Route Control
func getCleanRoute() async throws -> CleanRouteState {
    return try await request("/robot/capabilities/CleanRouteControlCapability")
}

func setCleanRoute(route: String) async throws {
    let body = ["route": route]
    try await requestVoid("/robot/capabilities/CleanRouteControlCapability", method: "PUT", body: body)
}

// MARK: - Valetudo Events
func getEvents() async throws -> [ValetudoEvent] {
    return try await request("/valetudo/events")
}

// MARK: - Obstacle Image (binary fetch — returns Data)
func getObstacleImage(id: String) async throws -> Data {
    // Sonderfall: binary response, nicht JSON
    // Benötigt eigene request-Methode oder URLSession.data() direkt
}
```

### Pattern 2: Model-Structs für neue API-Antworten

**What:** Codable structs in RobotState.swift (oder neuer Datei falls sinnvoller) für die neuen Response-Typen.

**Example:**
```swift
// MapSnapshot
struct MapSnapshot: Codable, Identifiable {
    let id: String
    let timestamp: String?
}

// PendingMapChange
struct PendingMapChangeState: Codable {
    let enabled: Bool
}

// CleanRoute
struct CleanRouteState: Codable {
    let route: String
}

// ValetudoEvent — discriminated via __class
struct ValetudoEvent: Codable, Identifiable {
    let __class: String
    let id: String
    let timestamp: String
    let processed: Bool
    // Subtype-spezifische Felder optional:
    let type: String?      // für ConsumableDepletedValetudoEvent
    let subType: String?
    let message: String?   // für ErrorStateValetudoEvent

    enum CodingKeys: String, CodingKey {
        case __class = "__class"
        case id, timestamp, processed, type, subType, message
    }
}
```

### Pattern 3: UNUserNotificationCenterDelegate via AppDelegate

**What:** SwiftUI-Apps ohne UIApplicationDelegate müssen `@UIApplicationDelegateAdaptor` verwenden, um `UNUserNotificationCenterDelegate` zu implementieren.

**Why required:** `UNUserNotificationCenter.current().delegate` muss gesetzt werden **bevor** die App fertig gelauncht hat (in `application(_:didFinishLaunchingWithOptions:)`). Der `@main` struct in SwiftUI hat keinen geeigneten Hook für diesen Zeitpunkt.

**Example:**
```swift
// Source: Apple Developer Documentation — UNUserNotificationCenterDelegate in SwiftUI
// ValetudoApp.swift Erweiterung:

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Wird aufgerufen wenn User auf GO_HOME oder LOCATE Action tippt
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            await NotificationService.shared.handleNotificationResponse(response)
        }
        completionHandler()
    }
}

@main
struct ValetudoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // ... bestehender Code
}
```

**NotificationService Erweiterung:**
```swift
// Neuer Handler in NotificationService
func handleNotificationResponse(_ response: UNNotificationResponse) async {
    let actionIdentifier = response.actionIdentifier

    // Roboter ermitteln: selectedRobotId oder ersten verfügbaren (D-07)
    guard let api = resolveAPIForAction() else { return }

    do {
        switch actionIdentifier {
        case "GO_HOME":
            try await api.basicControl(action: .home)
        case "LOCATE":
            try await api.locate()
        default:
            break
        }
    } catch {
        logger.error("Notification action failed: \(error.localizedDescription, privacy: .public)")
    }
}

private func resolveAPIForAction() -> ValetudoAPI? {
    // RobotManager ist @MainActor singleton — in Phase 3 muss NotificationService
    // Zugriff auf RobotManager.shared bekommen oder der AppDelegate übergibt die Referenz
    // EMPFEHLUNG: RobotManager als Parameter in handleNotificationResponse übergeben
    // um Singleton-Antipattern zu vermeiden
}
```

### Pattern 4: Obstacle-Bild als binärer URLSession-Call

**What:** `GET /robot/capabilities/ObstacleImagesCapability/img/{id}` gibt JPEG/PNG binär zurück — kein JSON. ValetudoAPI.request<T: Decodable>() funktioniert nicht. Benötigt separate Methode.

**Example:**
```swift
func getObstacleImage(id: String) async throws -> Data {
    guard let url = URL(string: "\(baseURL)/robot/capabilities/ObstacleImagesCapability/img/\(id)") else {
        throw APIError.invalidURL
    }
    var request = URLRequest(url: url)
    // Basic Auth — gleicher Code wie in request()
    if let authHeader = basicAuthHeader {
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
    }
    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
    }
    return data
}
```

**In ObstaclePhotoView:** `AsyncImage`-Ersatz via `@State var imageData: Data?` + `task { imageData = try? await api.getObstacleImage(id: obstacle.metaData.id) }`.

### Pattern 5: Obstacle-Entitäten im Map-Model

**What:** Map-Entities vom Typ `"obstacle"` sind bereits als `MapEntity` im bestehenden `RobotMap.swift` decodierbar — der `type`-Field reicht zur Erkennung. Die Obstacle-ID für die Bildabfrage steckt in `metaData`.

**Erforderliche Erweiterung von EntityMetaData:**
```swift
struct EntityMetaData: Codable {
    let angle: Int?
    // NEU für Obstacle-Foto-Feature:
    let id: String?      // UUID für ObstacleImagesCapability/img/{id}
    let label: String?   // z.B. "Pedestal (89%)"
    let image: String?   // interner robot-Pfad (nicht direkt nutzbar)
}
```

**Filter in EventsView/MapView:**
```swift
let obstacles = map.entities?.filter { $0.type == "obstacle" } ?? []
```

### Anti-Patterns to Avoid

- **AppDelegate als Singleton für RobotManager:** Den `RobotManager` im AppDelegate als eigene Instanz erstellen — dann gibt es zwei Instanzen. Stattdessen: RobotManager via NotificationCenter oder durch Übergabe an `handleNotificationResponse` teilen.
- **Notification-Handler ohne completionHandler-Aufruf:** `completionHandler()` MUSS synchron aufgerufen werden (iOS-Requirement), die API-Aufgabe in `Task {}` auslagern.
- **`requestVoid` für PATCH/DELETE ohne Method-Parameter:** Bestehende `requestVoid`-Methode prüfen — wenn sie nur PUT unterstützt, Events-Interact (`PUT /valetudo/events/{id}/interact`) passt hinein.
- **Event-__class direkt als Display-Text:** Nie `event.__class` dem User zeigen — eigene Display-String-Map anlegen.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Obstacle image loading mit Caching | Custom ImageCache-Klasse | `AsyncImage(url:)` oder `URLCache` per Session | Rate-Limiter im Backend (3 req/s) — URLCache + ETag-Header reichen für einfaches Caching |
| Event-Typ-Discriminierung | eigenen JSON-Decoder mit switch | Codable struct mit `__class` als String + computed `displayName` | __class ist stabil und direkt decodierbar |
| Notification-Response-Routing | Notification-spezifischen RobotManager | Bestehenden `robotManager.getAPI(for:)` mit bekannter robotId | Pattern bereits für alle anderen Actions etabliert |
| Snapshot-ID-zu-Timestamp Mapping | eigene UUID/Timestamp-Klasse | Direktes Decodieren der `timestamp`-String-Property von MapSnapshot | API gibt timestamp direkt zurück |

**Key insight:** Valetudo's REST-API ist vollständig, konsistent und gut dokumentiert. Jede Capability folgt demselben PUT-Schema. Custom Abstractions sind unnötig.

## Common Pitfalls

### Pitfall 1: UNUserNotificationCenterDelegate wird ignoriert ohne AppDelegate
**What goes wrong:** `NotificationService.shared` konformt zu `UNUserNotificationCenterDelegate` aber der Handler wird nie aufgerufen.
**Why it happens:** In SwiftUI-Apps ohne `UIApplicationDelegate` muss `UNUserNotificationCenter.current().delegate = self` in `application(_:didFinishLaunchingWithOptions:)` gesetzt werden — es gibt keinen anderen geeigneten Lifecycle-Hook.
**How to avoid:** `@UIApplicationDelegateAdaptor(AppDelegate.self)` in `@main` struct hinzufügen, Delegate in `didFinishLaunchingWithOptions` setzen.
**Warning signs:** Notification-Actions reagieren nicht; kein Breakpoint in `didReceive response:` wird getroffen.

### Pitfall 2: RobotManager-Zugriff aus NotificationService
**What goes wrong:** `NotificationService.shared.handleNotificationResponse()` hat keinen Zugriff auf `RobotManager.apis` Dictionary — führt zu einem Singleton oder Global-State-Problem.
**Why it happens:** NotificationService und RobotManager sind unabhängige @MainActor-Singletons ohne Referenz aufeinander.
**How to avoid:** AppDelegate erhält beim Launch eine Referenz auf `robotManager` via Closure/Property oder `handleNotificationResponse` bekommt `robotManager` als Parameter.
**Warning signs:** `resolveAPIForAction()` gibt immer nil zurück.

### Pitfall 3: Map-Snapshot "erstellen" ist kein API-Endpunkt
**What goes wrong:** Im UI einen "Snapshot erstellen" Button implementieren der einen POST/PUT macht und 404 erhält.
**Why it happens:** Die Phase-Beschreibung sagt "Snapshot erstellen" aber das Valetudo-Backend exposed nur `GET` (list) und `PUT` (restore). Snapshots werden automatisch von der Robot-Firmware erstellt.
**How to avoid:** UI zeigt nur die Liste vorhandener Snapshots (mit Timestamps) und einen "Wiederherstellen" Button pro Eintrag. Kein "Erstellen"-Button.
**Warning signs:** Kein entsprechender Router im Backend-Code; OpenAPI spec definiert nur GET und PUT/restore.

### Pitfall 4: Event-Interaktion erfordert `interact`-Endpoint, nicht DELETE
**What goes wrong:** Events werden durch DELETE-Request "als gelesen markiert" — gibt 404.
**Why it happens:** Events werden via `PUT /valetudo/events/{id}/interact` interagiert (mit `{"interaction": "ok"}` o.ä.), nicht gelöscht.
**How to avoid:** `PUT /:id/interact` mit `interaction`-Body-Field verwenden.
**Warning signs:** Alle Interact-Requests geben 404 zurück.

### Pitfall 5: Obstacle-Bild-Request ohne Rate-Limit-Beachtung
**What goes wrong:** EventsView lädt alle Obstacle-Bilder gleichzeitig beim Öffnen → Rate-Limit (3 req/s) führt zu 429-Fehlern.
**Why it happens:** D-03 spezifiziert Lazy-Loading — wenn nicht implementiert laden alle Bilder auf einmal.
**How to avoid:** Lazy-Loading via `task(id: obstacle.id)` in List-Rows oder `AsyncImage`-äquivalent mit `onAppear`. Nur das aktuell sichtbare Bild laden.
**Warning signs:** Erste Bilder laden, Rest gibt 429-Fehler zurück.

### Pitfall 6: `completionHandler` in UNUserNotificationCenterDelegate vergessen
**What goes wrong:** iOS zeigt nach Tap auf Notification-Action kurz einen Spinner und hängt dann; die App wird möglicherweise terminiert.
**Why it happens:** `userNotificationCenter(_:didReceive:withCompletionHandler:)` MUSS `completionHandler()` aufrufen, auch wenn der async API-Call noch läuft.
**How to avoid:** `completionHandler()` sofort nach dem `Task { ... }` aufrufen — der Task läuft im Hintergrund weiter.

## Code Examples

### Events API Response Format (verified via GitHub source + community data)
```swift
// GET /valetudo/events Response:
// Dictionary [id: EventObject] oder Array — aus Community-Daten:
// {
//   "e8061d9a-a8d8-4438-8186-600eeee456f9": {
//     "__class": "DustBinFullValetudoEvent",
//     "metaData": {},
//     "id": "e8061d9a-a8d8-4438-8186-600eeee456f9",
//     "timestamp": "2024-02-14T19:35:20.283Z",
//     "processed": false
//   }
// }
// ACHTUNG: Response könnte Dictionary oder Array sein — im ValetudoEventRouter
// gibt getAll() zurück; dies muss am echten Roboter verifiziert werden.
// EMPFEHLUNG: Erstmal als [String: ValetudoEvent] decodieren, dann .values verwenden.
```

### Map Snapshot — API-Endpunkte (OpenAPI verifiziert)
```
GET  /robot/capabilities/MapSnapshotCapability
     Response: [{ "id": "string", "timestamp": "ISO8601-string" }]

PUT  /robot/capabilities/MapSnapshotCapability
     Body: { "action": "restore", "id": "snapshot-id-string" }
     Response: HTTP 200
```

### PendingMapChange (OpenAPI verifiziert)
```
GET  /robot/capabilities/PendingMapChangeHandlingCapability
     Response: { "enabled": true/false }

PUT  /robot/capabilities/PendingMapChangeHandlingCapability
     Body: { "action": "accept" | "reject" }
     Response: HTTP 200
```

### CleanRoute — Valide Werte (Capability-Source + OpenAPI verifiziert)
```
GET  /robot/capabilities/CleanRouteControlCapability
     Response: { "route": "normal" | "quick" | "intensive" | "deep" }

PUT  /robot/capabilities/CleanRouteControlCapability
     Body: { "route": "normal" | "quick" | "intensive" | "deep" }
```

**Display-Namen für UI:**
- `"normal"` → "Standard"
- `"quick"` → "Schnell"
- `"intensive"` → "Intensiv"
- `"deep"` → "Tiefenreinigung"

### Obstacle Entity in Map-Daten (community-verifiziert)
```json
{
  "__class": "PointMapEntity",
  "type": "obstacle",
  "points": [3325, 3560],
  "metaData": {
    "id": "33911310-ff43-529c-862b-4765035ecd34",
    "label": "Pedestal (89%)",
    "image": "/data/record/1.jpg"
  }
}
```
Bild-URL: `GET /robot/capabilities/ObstacleImagesCapability/img/33911310-ff43-529c-862b-4765035ecd34`

### Event-Typen und Display-Icons (aus Valetudo-Source verifiziert)
| `__class` | Display-Name (DE) | SF Symbol |
|-----------|-------------------|-----------|
| `DustBinFullValetudoEvent` | "Staubbehälter voll" | `trash.fill` |
| `ConsumableDepletedValetudoEvent` | "Verbrauchsmaterial aufgebraucht" | `wrench.fill` |
| `MopAttachmentReminderValetudoEvent` | "MopAttachment reinigen" | `drop.fill` |
| `ErrorStateValetudoEvent` | "Fehler" | `exclamationmark.triangle.fill` |
| `MissingResourceValetudoEvent` | "Ressource fehlt" | `questionmark.circle.fill` |
| `PendingMapChangeValetudoEvent` | "Kartenänderung ausstehend" | `map.fill` |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| App-Delegate in UIKit-Lifecycle | `@UIApplicationDelegateAdaptor` in SwiftUI | iOS 14 / SwiftUI 2.0 | Erlaubt UIApplicationDelegate-Protokolle in SwiftUI-Apps |
| UIImage(data:) für remote images | `AsyncImage(url:)` | iOS 15 | Für externe URLs geeignet; für Auth-gesicherte Endpunkte weiterhin URLSession nötig |
| print()-Logging | os.Logger (bereits migriert in Phase 1) | Phase 1 abgeschlossen | Alle neuen Methoden verwenden Logger |

**Deprecated/outdated:**
- `UIApplicationDelegate` ohne `@UIApplicationDelegateAdaptor`: funktioniert nicht in SwiftUI-@main Apps.

## Open Questions

1. **Events-Response-Struktur: Dictionary oder Array?**
   - What we know: `ValetudoEventRouter` returned `valetudoEventStore.getAll()` via `res.json()`. Community-Daten zeigen Dictionary-Format `{id: eventObj}`.
   - What's unclear: Ist getAll() ein Array oder ein Dictionary mit ID-Keys?
   - Recommendation: Am echten Roboter oder im Valetudo-Swagger verifizieren. Code defensiv schreiben: beide Formate probieren oder Swagger (`robot-ip/swagger/`) konsultieren. Wahrscheinlich Dictionary (da eventStore key-value).

2. **Event-Interact-Payload: Welcher `interaction`-Wert?**
   - What we know: `PUT /valetudo/events/{id}/interact` mit `req.body.interaction` wird aufgerufen.
   - What's unclear: Valide Werte für `interaction` sind nicht in den gescannten Quellen dokumentiert. Für DismissibleValetudoEvent vermutlich `"ok"`.
   - Recommendation: In der EventsView nur ein "Bestätigt"-Button anbieten; Wert `"ok"` verwenden. Bei 400-Fehler: Anzeige ohne Interact-Funktion degradieren.

3. **MapSnapshot-ID-Format**
   - What we know: `id` ist ein `string` laut OpenAPI-Spec.
   - What's unclear: Ist es eine UUID, ein Integer oder ein Timestamp-basierter String?
   - Recommendation: Als `String` modellieren (nicht UUID-Typ), der Roboter bestimmt das Format.

## Environment Availability

Step 2.6: SKIPPED (keine externen Tools oder CLI-Dependencies — reine Swift/iOS Code-Änderungen, Valetudo läuft auf dem Roboter des Users).

## Validation Architecture

`workflow.nyquist_validation` ist in `.planning/config.json` nicht gesetzt — daher als enabled behandelt. Das Projekt hat jedoch **keine bestehende Test-Infrastruktur** (DEBT-04 aus Phase 4).

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Keines vorhanden — Wave 0 Aufgabe |
| Config file | Kein `xctest`-Target in `project.yml` |
| Quick run command | `xcodebuild test -scheme ValetudoApp -destination 'platform=iOS Simulator,name=iPhone 16'` (nach Einrichtung) |
| Full suite command | wie Quick run |

### Phase Requirements → Test Map

Da kein Test-Framework existiert und DEBT-04 (XCTest-Target) in Phase 4 liegt, sind alle Tests in dieser Phase als "Wave 0 Gap — kein Infrastruktur vorhanden" markiert.

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| API-01 | MapSnapshot list+restore API-Methoden | unit | `xcodebuild test ... -only-testing:ValetudoAppTests/ValetudoAPITests/testMapSnapshot` | ❌ Wave 0 (Phase 4) |
| API-02 | PendingMapChange accept/reject | unit | wie oben | ❌ Wave 0 (Phase 4) |
| API-03 | CleanRoute GET+SET | unit | wie oben | ❌ Wave 0 (Phase 4) |
| API-04 | ObstacleImage binary fetch | unit | wie oben | ❌ Wave 0 (Phase 4) |
| UX-03 | Notification-Action GO_HOME ruft basicControl(.home) | manual | Gerät: Notification erhalten, GO_HOME tippen, Roboter fährt zur Basis | manuell |
| UX-04 | Events-Liste zeigt DustBinFull-Event | manual | Simulator: Mock-Event in UI sichtbar | manuell |

### Wave 0 Gaps
- Test-Infrastruktur fehlt vollständig — wird in Phase 4 (DEBT-04) adressiert.
- Für Phase 3: Verifikation erfolgt manuell via Simulator (Mock-Daten in DebugConfig) und am echten Roboter.
- Keine Wave-0-Aufgaben in Phase 3 für Tests nötig — DEBT-04 ist explizit für Phase 4 geplant.

## Project Constraints (from CLAUDE.md)

Kein `CLAUDE.md` im Projektverzeichnis vorhanden. Globale CLAUDE.md-Regeln für dieses Projekt nicht relevant (server-infrastruktur-spezifisch). Keine projekt-spezifischen Coding-Constraints vorhanden.

Implizite Constraints aus bestehender Codebase (CONVENTIONS.md):
- Alle neuen Strings via `String(localized:)` + `Localizable.xcstrings`
- `os.Logger` statt `print()` (Phase 1 migriert, neue Methoden müssen konform sein)
- `@MainActor` auf allen ObservableObject-Klassen mit @Published
- Kein externes Package hinzufügen
- PascalCase für Typen, camelCase für Properties/Methods
- MARK-Kommentare für neue Sections in bestehenden Dateien

## Sources

### Primary (HIGH confidence)
- https://raw.githubusercontent.com/Hypfer/Valetudo/master/backend/lib/webserver/capabilityRouters/doc/MapSnapshotCapabilityRouter.openapi.json — GET/PUT schema, Snapshot-Struktur
- https://raw.githubusercontent.com/Hypfer/Valetudo/master/backend/lib/webserver/capabilityRouters/doc/PendingMapChangeHandlingCapabilityRouter.openapi.json — GET response schema, accept/reject actions
- https://raw.githubusercontent.com/Hypfer/Valetudo/master/backend/lib/webserver/capabilityRouters/doc/CleanRouteControlCapabilityRouter.openapi.json — Route enum: normal/quick/intensive/deep
- https://raw.githubusercontent.com/Hypfer/Valetudo/master/backend/lib/webserver/capabilityRouters/doc/ObstacleImagesCapabilityRouter.openapi.json — img/{id} Endpunkt, binary response
- https://raw.githubusercontent.com/Hypfer/Valetudo/master/backend/lib/core/capabilities/CleanRouteControlCapability.js — ROUTE Konstanten verifiziert
- https://github.com/Hypfer/Valetudo/tree/master/backend/lib/valetudo_events/events — Event-Typen Liste: 6 Event-Klassen
- https://raw.githubusercontent.com/Hypfer/Valetudo/master/frontend/src/api/client.ts — TypeScript client API structure
- /Users/simonluthe/Documents/valetudo-app/ValetudoApp/ValetudoApp/Services/NotificationService.swift — Bestehende Action-Registrierung, UNNotificationCategory setup
- /Users/simonluthe/Documents/valetudo-app/ValetudoApp/ValetudoApp/Models/RobotMap.swift — MapEntity/EntityMetaData Struktur, Erweiterungsbedarf
- /Users/simonluthe/Documents/valetudo-app/.planning/codebase/CONCERNS.md — Notification-Handler-Gap dokumentiert (Zeile 105-110)

### Secondary (MEDIUM confidence)
- https://github.com/sca075/mqtt_vacuum_camera/discussions/296 — Obstacle Entity JSON-Struktur mit metaData.id und label (community-verifiziert)
- https://valetudo.cloud/pages/development/valetudo-core-concepts.html — ValetudoEvent Konzept (processed-Flag, Interaktion)
- https://valetudo.cloud/pages/usage/capabilities-overview.html — MapSnapshotCapability, PendingMapChangeHandlingCapability, ObstacleImagesCapability Beschreibungen

### Tertiary (LOW confidence)
- Community-Daten Event-Response-Format: `{"id": {...}}` Dictionary-Struktur — am echten Roboter zu verifizieren
- Event interact-Payload Wert `"ok"` — nicht direkt in Sources gefunden, aus Valetudo-Konzept abgeleitet

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — kein neuer Stack, nur bestehende Apple-Frameworks
- API-Endpunkte (MapSnapshot, PendingMapChange, CleanRoute, ObstacleImages): HIGH — OpenAPI-Specs direkt aus Valetudo-Repo
- API-Endpunkt Events-Response-Format: MEDIUM — Response-Struktur (Dictionary vs Array) aus Community-Daten, nicht aus OpenAPI
- Event interact-Payload: LOW — Wert `"ok"` abgeleitet, nicht dokumentiert gefunden
- Architecture/UNNotificationDelegate-Pattern: HIGH — Apple Developer Dokumentation, iOS 14+
- Pitfalls: HIGH — aus Codebase-Analyse (CONCERNS.md) und API-Docs abgeleitet

**Research date:** 2026-03-27
**Valid until:** 2026-09-27 (Valetudo API ist stabil, keine Breaking Changes erwartet; Apple-Framework-APIs iOS 17-spezifisch und stabil)
