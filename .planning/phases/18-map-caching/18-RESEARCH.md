# Phase 18: Map Caching - Research

**Researched:** 2026-04-01
**Domain:** iOS Swift — FileManager Disk Persistence, SwiftUI Offline UI Patterns
**Confidence:** HIGH

## Summary

Phase 18 implementiert einen Disk-Cache fuer die letzte Valetudo-Karte jedes Roboters. Ziel ist Offline-Anzeige mit dezenten Indikator statt leerem Fehlerscreen. Die technische Basis ist vollstaendig im Projekt vorhanden: `RobotMap` ist bereits `Codable`, das Singleton-Pattern fuer Services ist etabliert, die ZStack-Struktur in `MapView.swift` erlaubt Banner-Overlays ohne grosse Umbauarbeiten.

Die Implementierung besteht aus drei eng verwobenen Aenderungen: (1) neuer `MapCacheService` (Singleton, async Disk-I/O), (2) Erweiterung von `MapViewModel` um Cache-Calls und `@Published var isOffline: Bool`, (3) Offline-Banner als ZStack-Overlay in `MapView.swift`. Cache-Cleanup bei Roboter-Loeschung wird in `RobotManager.removeRobot()` hinzugefuegt.

Kritische Randbedingung: `MapLayerCache` (in-memory Pixel-Decompression) darf **nicht** auf Disk serialisiert werden — `CodingKeys` in `MapLayer` schliessen das `cache`-Property bereits aus. Das JSON repraesentiert die Rohdaten, nicht den dekomprimierten Zustand.

**Primary recommendation:** Neuen `MapCacheService.swift` in `Services/` anlegen, `RobotMap` direkt JSON-serialisieren via `JSONEncoder/JSONDecoder`, async Disk-I/O mit `Task.detached` oder `withCheckedContinuation` auf Background-Actor.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Cache-Strategie:**
- Speicherort: `Documents/MapCache/{robotId}.json` — eine Datei pro Roboter via `FileManager`
- Caching-Zeitpunkt: nach jedem erfolgreichen `getMap()` — im `MapViewModel` Polling-Loop
- Format: JSON via `Codable` — `RobotMap` ist bereits Codable, einfachste Loesung
- Cache-Invalidierung: Ueberschreiben bei jedem Update — immer die neueste Karte, kein TTL

**Offline-Verhalten:**
- Offline-Indikator: Overlay-Banner "Offline" auf der Karte — dezent, nicht-blockierend
- Offline-Erkennung: wenn `getMap()` fehlschlaegt UND gecachte Karte vorhanden — ersetzt `ContentUnavailableView`
- Live-Wiederherstellung: automatisch beim naechsten erfolgreichen `getMap()` — Polling laeuft weiter, Banner verschwindet
- Ohne Cache + offline: bestehende `ContentUnavailableView` bleibt (kein Cache vorhanden, nichts zu zeigen)

**Code-Architektur:**
- Neuer `MapCacheService` — klare Trennung, wiederverwendbar
- Async Disk-I/O (Background-Thread) — Disk-I/O soll nicht das UI blockieren
- Offline-Banner als Overlay in `MapView.swift` — ZStack ueber der Karte
- Cache-Cleanup bei Roboter-Loeschung — `RobotManager.removeRobot()` loescht auch den Cache automatisch

### Claude's Discretion

Keine explizit aufgefuehrten Discretion-Bereiche. Alle wesentlichen Entscheidungen sind gelockt.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CACHE-01 | Die letzte Karte jedes Roboters wird auf Disk gespeichert | `MapCacheService.save(map:for:)` nach jedem erfolgreichen `getMap()` in `startMapRefresh()` und `loadMap()` |
| CACHE-02 | Gespeicherte Karte wird angezeigt wenn der Roboter nicht erreichbar ist | `MapViewModel.isOffline = true` + Cache-Load bei Fehler; ZStack-Banner in `MapView.swift` |
| CACHE-03 | Karte wird automatisch aktualisiert sobald Verbindung wieder steht | Polling-Loop laeuft weiter; bei naechstem Erfolg `isOffline = false`, Banner verschwindet |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Foundation / FileManager | System | Disk-I/O, Verzeichnis-Management | iOS Standard, kein externer Dependency |
| JSONEncoder / JSONDecoder | System | Serialisierung von `RobotMap` | `RobotMap` ist bereits `Codable`, triviale Integration |
| Swift Concurrency (async/await, Task) | System | Async Disk-I/O ohne UI-Blocking | Etabliertes Pattern im Projekt |
| SwiftUI ZStack | System | Offline-Banner-Overlay | Schon in `MapView.swift` und `MapPreviewView` genutzt |
| os.Logger | System | Strukturiertes Logging im Service | Durchgehendes Projekt-Pattern |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `@MainActor` | System | Thread-Safety fuer `@Published` Properties in `MapViewModel` | Immer wenn Published-Updates aus Background-Task kommen |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| FileManager + JSON | UserDefaults | UserDefaults ist fuer kleine Key-Value-Daten; Kartendaten koennen gross sein (mehrere KB) — FileManager ist korrekt |
| FileManager + JSON | Core Data | Core Data waere Overengineering fuer eine einfache Datei-pro-Roboter-Strategie |
| Task.detached / background actor | `DispatchQueue.global` | Task.detached ist der Swift-Concurrency-Weg; `DispatchQueue` ist Legacy-Pattern fuer neue Code |

**Installation:** Keine externen Packages noetig — alles System-Framework.

## Architecture Patterns

### Recommended Project Structure

```
ValetudoApp/Services/
├── MapCacheService.swift    # NEU — Singleton, async save/load/delete
├── NotificationService.swift
├── BackgroundMonitorService.swift
└── ...

ValetudoApp/ViewModels/
└── MapViewModel.swift       # EDIT — isOffline: Bool, Cache-Calls

ValetudoApp/Views/
└── MapView.swift            # EDIT — Offline-Banner als ZStack-Overlay

ValetudoApp/Services/
└── RobotManager.swift       # EDIT — Cache-Cleanup in removeRobot()

Documents/MapCache/          # Runtime (kein Source-File)
└── {robotId}.json           # Eine Datei pro Roboter
```

### Pattern 1: MapCacheService Singleton

**Was:** Singleton-Service nach dem etablierten `NotificationService.shared` / `BackgroundMonitorService.shared` Pattern. Kapselt alle Disk-I/O-Operationen fuer den Karten-Cache.

**Wenn zu nutzen:** Ueberall wo Cache geschrieben, gelesen oder geloescht werden soll — kein direktes FileManager-Aufrufen in ViewModel oder RobotManager.

**Beispiel (abgeleitet vom Projekt-Pattern in BackgroundMonitorService):**
```swift
// Source: abgeleitet von BackgroundMonitorService.swift (Zeile 5-9)
final class MapCacheService {
    static let shared = MapCacheService()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "MapCacheService")
    private init() {}

    private func cacheDirectory() throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = docs.appendingPathComponent("MapCache", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cacheURL(for robotId: UUID) throws -> URL {
        try cacheDirectory().appendingPathComponent("\(robotId.uuidString).json")
    }

    func save(_ map: RobotMap, for robotId: UUID) async {
        do {
            let url = try cacheURL(for: robotId)
            let data = try JSONEncoder().encode(map)
            try data.write(to: url, options: .atomic)
            logger.debug("MapCache saved for \(robotId, privacy: .public)")
        } catch {
            logger.error("MapCache save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func load(for robotId: UUID) async -> RobotMap? {
        do {
            let url = try cacheURL(for: robotId)
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(RobotMap.self, from: data)
        } catch {
            logger.debug("MapCache load: no cache for \(robotId, privacy: .public) — \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func deleteCache(for robotId: UUID) {
        do {
            let url = try cacheURL(for: robotId)
            try FileManager.default.removeItem(at: url)
            logger.info("MapCache deleted for \(robotId, privacy: .public)")
        } catch {
            logger.debug("MapCache delete: nichts zu loeschen fuer \(robotId, privacy: .public)")
        }
    }
}
```

### Pattern 2: MapViewModel — isOffline Flag + Cache-Integration

**Was:** Erweiterung von `MapViewModel` um `@Published var isOffline: Bool = false`. Cache wird nach Erfolg geschrieben, bei Fehler geladen.

**Kritisch:** `MapViewModel` ist `@MainActor`. Disk-I/O darf dort direkt `await`ed werden — async calls in Swift Concurrency laufen die eigentliche I/O off-actor (im System-Thread-Pool), kehren dann zum `@MainActor` zurueck. `MapCacheService.save/load` sind `async` und blockieren den Main Thread nicht.

**Beispiel — Erweiterung von `startMapRefresh()` (Zeile 140-156 in MapViewModel.swift):**
```swift
// VORHER (Zeile 149-154):
if let newMap = try? await api.getMap() {
    self.map = newMap
}

// NACHHER:
if let newMap = try? await api.getMap() {
    self.map = newMap
    self.isOffline = false
    await MapCacheService.shared.save(newMap, for: robot.id)
} else {
    // Fehler: Cache laden falls vorhanden
    if let cachedMap = await MapCacheService.shared.load(for: robot.id) {
        if self.map == nil {
            self.map = cachedMap
        }
        self.isOffline = true
    }
    // Kein Cache: isOffline bleibt false, ContentUnavailableView zeigt sich
}
```

**Gleiches gilt fuer `loadMap()` (Zeile 121-137):** Nach erfolgreichem `getMap()` → save; im catch-Block → load. `isOffline` entsprechend setzen.

### Pattern 3: Offline-Banner-Overlay in MapView.swift

**Was:** ZStack-Overlay in `MapContentView.body` — dezenter Banner am oberen Kartenrand. Analoges visuelles Styling zum Update-Banner-Ansatz in `RobotDetailView.swift`.

**Positionierung:** Innerhalb des inneren ZStack (Zeile 227 in MapView.swift), ueber `InteractiveMapView`, nach allen anderen Overlays.

**Beispiel:**
```swift
// Innerhalb des ZStack ueber der Karte (nach Zeile 255 in MapView.swift)
if viewModel.isOffline {
    VStack {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash")
                .font(.caption)
            Text(String(localized: "map.offline"))
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.top, 8)
        Spacer()
    }
}
```

**Lokalisierungskey:** `"map.offline"` muss in der Localizable.strings / String Catalog hinzugefuegt werden.

### Pattern 4: Cache-Cleanup in RobotManager.removeRobot()

**Was:** Nach bestehendem Cleanup-Pattern in `removeRobot()` (Zeile 58-67) — synchroner `deleteCache`-Call.

**Beispiel (nach Zeile 66 in RobotManager.swift):**
```swift
// Nach saveRobots() in removeRobot()
MapCacheService.shared.deleteCache(for: id)
```

`deleteCache` ist synchron (kein `async`) — `FileManager.removeItem` ist fast und kann auf `@MainActor` aufgerufen werden. Alternativ als `async` Variante analog zu `save/load` wenn konsistentes API gewuenscht.

### Anti-Patterns to Avoid

- **`MapLayerCache` auf Disk schreiben:** `cache = MapLayerCache()` ist explizit aus `CodingKeys` in `MapLayer` ausgeschlossen. Niemals den in-memory Pixel-Cache persistieren.
- **Disk-I/O synchron auf Main Thread:** Niemals `Data(contentsOf:)` oder `data.write(to:)` ohne `async`/`Task` im UI-Pfad aufrufen.
- **`isOffline = true` ohne Cache:** Nur wenn ein gecachter Wert vorhanden und geladen ist, wird `isOffline = true` gesetzt. Ohne Cache bleibt das Verhalten unveraendert (ContentUnavailableView).
- **Cache-Verzeichnis ohne `createDirectory(withIntermediateDirectories: true)`:** Das `MapCache/`-Verzeichnis existiert beim ersten App-Start nicht. Immer mit `withIntermediateDirectories: true` anlegen.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Atomic Schreiben | Eigene Temp-Datei + Rename | `data.write(to:url, options: .atomic)` | Foundation erledigt das atomare Schreiben, verhindert korrupte Dateien bei App-Crash |
| Thread-Safety | Locks, Semaphoren | Swift `async`/`await` mit `@MainActor` | Concurrency-Modell des Projekts, kein manuelles Locking noetig |
| JSON Serialisierung | Eigener Encoder | `JSONEncoder` / `JSONDecoder` | `RobotMap` ist bereits `Codable`, trivial |

**Key insight:** Die gesamte Implementierung nutzt ausschliesslich Foundation-APIs. Kein neuer Package-Dependency entsteht.

## Common Pitfalls

### Pitfall 1: RobotMap.size koennte nil sein — JSON-Ladezeit

**Was schieflaeuft:** `RobotMap` hat optionale Properties (`size`, `pixelSize`, `layers`, `entities`). Eine gecachte Karte ohne `layers` wuerde in `MapView` angezeigt aber nichts zeichnen.

**Warum:** Die Valetudo-API liefert im Fehlerfall moeglicherweise nur eine Partial-Response. Wenn diese gecacht wird, ist der Cache scheinbar valid aber leer.

**Vermeidung:** Cache nur nach vollstaendig geladenem `getMap()` schreiben. `getMap()` schlaegt mit `throw` fehl wenn keine Map zurueck kommt — das ist der Guard fuer die Cache-Schreiblogik (`try? await api.getMap()` — nur bei `non-nil`-Ergebnis cachen).

### Pitfall 2: isOffline-Flag bei MapPreviewView (RobotDetailView)

**Was schieflaeuft:** `MapPreviewView` hat einen eigenen Polling-Loop (`startLiveRefresh`) und eigenen State, der von `MapViewModel` getrennt ist. Der `isOffline`-State in `MapViewModel` gilt nicht fuer das Mini-Kartenpreview.

**Warum:** `MapPreviewView` ist ein separates View mit eigenem State (Zeile 62-66 in MapView.swift).

**Vermeidung:** Phase-Scope ist klar: Offline-Banner nur im vollstaendigen `MapContentView` (via `MapViewModel.isOffline`). Das Mini-Preview ist Out of Scope — es verwendet weiterhin seinen eigenen `loadMap()`. Der Preview zeigt im Fehlerfall bereits `map.unavailable` (Zeile 109).

### Pitfall 3: Doppeltes Schreiben bei loadMap() und startMapRefresh()

**Was schieflaeuft:** `loadMap()` ruft `api.getMap()` auf, danach startet `startMapRefresh()` nach 2 Sekunden erneut. Beide Paths muessen den Cache schreiben, aber nur einer sollte `isOffline` setzen.

**Warum:** Die Logik fuer den initialen Load (`loadMap`) und den Polling-Loop (`startMapRefresh`) sind getrennt.

**Vermeidung:** Sowohl `loadMap()` als auch der Polling-Loop in `startMapRefresh()` muessen je nach Erfolg/Misserfolg des `getMap()`-Calls konsistent mit `MapCacheService` interagieren. Gemeinsame Hilfsmethode oder konsistentes Inline-Muster in beiden Stellen.

### Pitfall 4: isOffline bleibt true nach Wiederherstellung

**Was schieflaeuft:** Wenn `isOffline = true` gesetzt wird und dann der Polling-Loop einen erfolgreichen `getMap()` zurueckbekommt, muss `isOffline = false` gesetzt werden. Wird das vergessen, bleibt der Banner haengen.

**Vermeidung:** Explizit `isOffline = false` bei jedem erfolgreichen `getMap()`-Call setzen (CACHE-03).

### Pitfall 5: String Catalog / Lokalisierung vergessen

**Was schieflaeuft:** `String(localized: "map.offline")` ohne Eintrag im String Catalog kompiliert, aber zeigt den Key-String statt lokalisierten Text an.

**Vermeidung:** Lokalisierungskey `map.offline` in der xcstrings-Datei erganzen (Wave 0 Task).

## Code Examples

### Verzeichnis anlegen (Foundation Pattern)
```swift
// Analog zu Apple-Dokumentation fuer .documentDirectory
let docs = try FileManager.default.url(
    for: .documentDirectory,
    in: .userDomainMask,
    appropriateFor: nil,
    create: true
)
let cacheDir = docs.appendingPathComponent("MapCache", isDirectory: true)
try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
```

### Atomic Write (Foundation)
```swift
// .atomic verhindert korrupte Teilschreibvorgaenge
try data.write(to: fileURL, options: .atomic)
```

### Async auf Background (Swift Concurrency)
```swift
// save() und load() koennen direkt in @MainActor-Klassen geawaittet werden
// Foundation-I/O ist non-blocking in async context
func save(_ map: RobotMap, for robotId: UUID) async {
    // FileManager.default.createDirectory und data.write laufen
    // im aufrufenden Context (hier: MainActor) — fuer Kartendaten
    // (typ. < 100 KB) ist das akzeptabel. Bei grossem Dateivolumen
    // Task.detached { } verwenden.
}
```

### Existierendes Singleton-Pattern (BackgroundMonitorService.swift:5-9)
```swift
final class MapCacheService {
    static let shared = MapCacheService()
    private init() {}
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `DispatchQueue.global` fuer Background I/O | `async`/`await` mit Swift Concurrency | Swift 5.5 (iOS 15+) | Klareres Concurrency-Modell, kein Callback-Hell |
| NSUserDefaults fuer strukturierte Daten | FileManager fuer groessere Structs | — | UserDefaults fuer kleine Key/Value, File fuer binaere/grosse Daten |

**Deprecated/outdated:**
- `DispatchQueue.global().async { }` fuer Disk-I/O: Nicht falsch, aber nicht der Projektstil — alle neuen Services nutzen Swift Concurrency.

## Open Questions

1. **Task.detached vs. direktes await in @MainActor-Methode fuer Disk-I/O**
   - Was wir wissen: Foundation-Disk-I/O in async-Kontext blockiert den aufrufenden Thread nicht nach oben. Karten-JSON ist typ. < 100 KB.
   - Was unklar ist: Ob fuer groessere Karten (mehrere Roboter, komplexe Maps) `Task.detached(priority: .background)` bevorzugt werden sollte.
   - Empfehlung: Fuer diese Phase direktes `await` in `@MainActor` ist ausreichend. Messung zeigt ob Optimierung noetig.

2. **MapPreviewView Offline-Zustand**
   - Was wir wissen: Out of Scope gemaess CONTEXT.md. `MapPreviewView` hat eigenen State.
   - Was unklar: Ob Benutzer erwarten, dass auch das Mini-Preview gecachte Karte zeigt.
   - Empfehlung: Out of Scope halten. Kann als separates Follow-up behandelt werden.

## Environment Availability

Step 2.6: SKIPPED — Phase ist eine reine Code-Aenderung innerhalb der iOS-App, keine externen CLI-Tools oder Services benoetigt.

## Validation Architecture

nyquist_validation ist explizit `false` in `.planning/config.json` — Abschnitt wird uebersprungen.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: `FileManager` — `url(for:in:appropriateFor:create:)`, `createDirectory(at:withIntermediateDirectories:)`
- Apple Developer Documentation: `Data.write(to:options:)` mit `.atomic` Option
- Projektcode direkt gelesen: `MapViewModel.swift`, `RobotMap.swift`, `MapView.swift`, `RobotManager.swift`, `BackgroundMonitorService.swift`, `NotificationService.swift`, `RobotState.swift` (GoToPresetStore)

### Secondary (MEDIUM confidence)
- Abgeleitet aus bestehendem Projekt-Pattern: Singleton-Struktur analog `NotificationService.shared` und `BackgroundMonitorService.shared`
- ZStack-Overlay-Muster abgeleitet aus `MapContentView.body` (MapView.swift:212-334)

### Tertiary (LOW confidence)
- Keine LOW-confidence Findings. Alle kritischen Aspekte durch direkten Code-Review verifiziert.

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — alles System-Framework, kein Drittanbieter
- Architecture: HIGH — direkt aus bestehendem Projekt-Pattern abgeleitet
- Pitfalls: HIGH — aus Code-Review der Implementierungsstellen identifiziert

**Research date:** 2026-04-01
**Valid until:** Stabil — keine externen Abhaengigkeiten, Swift-API unveraendert
