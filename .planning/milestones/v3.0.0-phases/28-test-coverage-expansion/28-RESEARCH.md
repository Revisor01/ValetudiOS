# Phase 28: Test Coverage Expansion - Research

**Researched:** 2026-04-04
**Domain:** XCTest, Swift concurrency testing, iOS unit tests without external dependencies
**Confidence:** HIGH

## Summary

Phase 28 erweitert die bestehenden 57 Unit-Tests um vier kritische Bereiche: Koordinaten-Transforms in MapGeometry.swift, Hit-Test-Logik via `segmentPixelSets`, alle 8 `UpdatePhase`-Transitionen in UpdateService, SSE-Reconnection-Backoff-Timing und den MapCacheService Save/Load-Zyklus.

Alle Zielklassen sind reine Logik (Pure Functions, Pure State Machines) oder nutzen das Filesystem — kein UIKit-UI, kein Netzwerk-I/O ist für die Tests nötig. `ValetudoAPI` ist ein `actor` ohne Protocol-Abstraction, weshalb die UpdateService-Tests die Klasse nicht instanziieren sollten; stattdessen wird `mapUpdaterState` und `setPhase` über öffentliche Methoden indirekt getestet, oder `UpdateService` erhält eine testbare Protokoll-Abstraktion. Das bestehende Testmuster (direkte Instanziierung + `@testable import` + kein Mock-Framework) wird beibehalten.

**Primary recommendation:** Alle neuen Tests als reine Zustandsmaschinen-Tests schreiben. Wo `ValetudoAPI` benötigt wird, ein schlankes Mock-Protokoll einführen — ohne externe Bibliotheken.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| XCTest | iOS 17 SDK | Test framework | Systemeigene Lösung, kein externe Dep |
| Swift Concurrency (async/await) | Swift 5.9 | Async tests | `async throws` in XCTestCase-Methoden |
| Foundation (FileManager, JSONEncoder) | iOS 17 SDK | MapCache-Tests mit Filesystem | Kein Mock nötig — Test-Documents-Dir |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `@testable import ValetudoApp` | N/A | Zugriff auf interne Typen | Alle Testfiles |
| `XCTAssertEqual / XCTAssertNil` | XCTest | Standard-Assertions | Überall |
| `XCTestExpectation` | XCTest | Async-Warten auf Callbacks | SSE-Backoff-Tests falls nötig |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Echtes Filesystem für MapCache | In-Memory-Mock | Filesystem-Tests sind einfacher und prüfen echte Codepfade |
| `actor SSEConnectionManager` direkt testen | Pure-Backoff-Logik extrahieren | Direktes Testen des Actors erfordert komplexe async-Infrastruktur |

**Installation:** Keine — alles im bestehenden `ValetudoAppTests`-Target.

## Test-Infrastruktur

### Wo leben die Tests
- **Pfad:** `ValetudoApp/ValetudoAppTests/`
- **Target:** `ValetudoAppTests` (bundle.unit-test, BUNDLE_LOADER auf ValetudoApp.app)
- **Schema:** `ValetudoApp` — enthält `ValetudoAppTests` im `test`-Step (laut `project.yml`)
- **Simulator:** `iPhone 17` (iOS 26.4) — verfügbar auf diesem Mac

### Testbefehl
```bash
xcodebuild \
  -project ValetudoApp/ValetudoApp.xcodeproj \
  -scheme ValetudoApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test 2>&1 | grep -E "Test Suite|passed|failed|error"
```

### Bestehendes Muster (aus existierenden Tests)
```swift
// Source: ValetudoAppTests/MapViewModelTests.swift, RobotDetailViewModelTests.swift
import XCTest
@testable import ValetudoApp

final class SomeTests: XCTestCase {
    // Helper: direktes Instanziieren der Models
    private func makeLayer(json: String) throws -> MapLayer {
        try JSONDecoder().decode(MapLayer.self, from: json.data(using: .utf8)!)
    }

    // Async-Test: @MainActor-Annotierung, async-Methode
    @MainActor
    func testSomething() async throws { ... }
}
```

**Kein Mock-Framework, kein Swift Package.** Alles mit `@testable import` und nativen Typen.

## Architecture Patterns

### Empfohlene Testdatei-Struktur
```
ValetudoAppTests/
├── MapGeometryTests.swift        # TEST-01 Teil 1: Koordinaten-Transforms
├── HitTestLogicTests.swift       # TEST-01 Teil 2: segmentPixelSets-Lookup
├── UpdateServiceTests.swift      # TEST-02: 8 Phases + Error-Recovery
├── SSEBackoffTests.swift         # TEST-03: Backoff-Timing-Logik
└── MapCacheServiceTests.swift    # TEST-04: Save/Load/Corrupt
```

### Pattern 1: Pure-Function-Tests (MapGeometry)
**Was:** `calculateMapParams`, `screenToMapCoords`, `mapToScreenCoords` sind free functions — direkt aufrufbar.
**Wann:** Immer wenn Input → Output ohne Seiteneffekte.
```swift
// Source: MapGeometry.swift — calculateMapParams, screenToMapCoords, mapToScreenCoords
func testScreenToMapCoordsIdentityAtCenter() {
    let viewSize = CGSize(width: 400, height: 400)
    let center = CGPoint(x: 200, y: 200)
    let result = screenToMapCoords(center, scale: 1.0, offset: .zero, viewSize: viewSize)
    XCTAssertEqual(result.x, 200, accuracy: 0.001)
    XCTAssertEqual(result.y, 200, accuracy: 0.001)
}

func testRoundTrip_screenToMap_mapToScreen() {
    let viewSize = CGSize(width: 400, height: 400)
    let original = CGPoint(x: 150, y: 300)
    let mapCoords = screenToMapCoords(original, scale: 2.0, offset: CGSize(width: 10, height: -5), viewSize: viewSize)
    let back = mapToScreenCoords(mapCoords, scale: 2.0, offset: CGSize(width: 10, height: -5), viewSize: viewSize)
    XCTAssertEqual(back.x, original.x, accuracy: 0.001)
    XCTAssertEqual(back.y, original.y, accuracy: 0.001)
}
```

### Pattern 2: segmentPixelSets Hit-Test-Logik
**Was:** Der Key `pixelX &<< 16 | pixelY` ist die Kern-Logik. Er wird in `MapInteractiveView.swift` (Line 271) und `rebuildSegmentPixelSets` (MapViewModel, Line 291) verwendet.
**Kein MapViewModel nötig** — die Logik kann als pure Funktion isoliert getestet werden:
```swift
// Nachbau der Kern-Logik aus MapInteractiveView.swift:271 und MapViewModel.swift:291
func testPixelKeyEncodingAndLookup() {
    let pixelX = 42, pixelY = 17
    let key = pixelX &<< 16 | pixelY
    var set = Set<Int>()
    set.insert(key)

    XCTAssertTrue(set.contains(pixelX &<< 16 | pixelY))
    XCTAssertFalse(set.contains(43 &<< 16 | 17))  // anderer X
    XCTAssertFalse(set.contains(42 &<< 16 | 18))  // anderer Y
}
```

### Pattern 3: UpdateService-Phasentransitionen
**Was:** UpdateService ist `@MainActor @Observable`. `ValetudoAPI` ist ein `actor` ohne Protokoll.
**Problem:** `UpdateService.init(api: ValetudoAPI)` nimmt den konkreten Typ — kein direkter Mock ohne Protokoll.
**Lösung:** `mapUpdaterState` ist `private` — es muss indirekt über den `__class`-String getestet werden ODER eine Protokoll-Abstraktion eingeführt werden.

**Empfohlener Ansatz — Protokoll-Extraktion (minimal):**
```swift
// Neues Protokoll in UpdateService.swift oder separater Datei
protocol ValetudoAPIProtocol: AnyObject, Sendable {
    func checkForUpdates() async throws
    func getUpdaterState() async throws -> UpdaterState
    func downloadUpdate() async throws
    func applyUpdate() async throws
    func getValetudoVersion() async throws -> ValetudoVersion
}

// ValetudoAPI: ValetudoAPIProtocol (Conformance hinzufügen — rein additive Änderung)
// UpdateService.init(api: any ValetudoAPIProtocol)
```

Damit kann ein `MockValetudoAPI` in den Tests verwendet werden:
```swift
final class MockValetudoAPI: ValetudoAPIProtocol, @unchecked Sendable {
    var updaterStateToReturn: UpdaterState = .init(__class: "ValetudoUpdaterIdleState", ...)
    var shouldThrow = false
    // ...
}
```

**Alternativ (ohne Code-Änderung):** Nur `UpdatePhase.Equatable` und `mapUpdaterState`-äquivalente Logik über die öffentliche `checkForUpdates()`-Methode + Mock testen — aber das erfordert ein echtes Netzwerk. **Protokoll-Ansatz ist sauberer.**

### Pattern 4: SSE-Backoff — isolierte Logik
**Was:** Die Backoff-Werte stehen in `SSEConnectionManager.streamWithReconnect` (Lines 101–108):
```swift
// Source: SSEConnectionManager.swift:101-108
switch retryCount {
case 1:  delay = 1   // 1. Retry: 1s
case 2:  delay = 5   // 2. Retry: 5s
default: delay = 30  // ab 3. Retry: 30s (gecapped)
}
```
**Das ist keine testbare Funktion** — die Logik ist inline im `actor`. Optionen:
1. **Extraktion zu einer pure function** (empfohlen):
   ```swift
   // Neu in SSEConnectionManager.swift:
   static func backoffDelay(retryCount: Int) -> Double {
       switch retryCount {
       case 1:  return 1
       case 2:  return 5
       default: return 30
       }
   }
   ```
   Dann: `let delay = SSEConnectionManager.backoffDelay(retryCount: retryCount)`

2. **Inline ohne Extraktion:** TEST-03 als "Verifikation der Backoff-Konstanten" schreiben — die static func testen sobald sie extrahiert ist.

**Empfehlung:** Extraktion ist minimal-invasiv und macht TEST-03 trivial.

### Pattern 5: MapCacheService — Filesystem-Tests
**Was:** `MapCacheService.shared` schreibt in `.documentDirectory/MapCache/<uuid>.json`.
**In Tests:** Die Documents-Directory ist im Simulator verfügbar — echter Filesystem-Test.
**Teardown nötig:** Cache nach jedem Test löschen.
```swift
// Source: MapCacheService.swift
final class MapCacheServiceTests: XCTestCase {
    private let testId = UUID()

    override func tearDown() async throws {
        MapCacheService.shared.deleteCache(for: testId)
    }

    func testSaveAndLoad() async throws {
        let map = makeMinimalRobotMap()
        await MapCacheService.shared.save(map, for: testId)
        let loaded = await MapCacheService.shared.load(for: testId)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.pixelSize, map.pixelSize)
    }

    func testCorruptedCacheReturnsNil() async throws {
        // Corrupt-Test: direkt schlechtes JSON in den Cache schreiben
        let cacheDir = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ).appendingPathComponent("MapCache/\(testId.uuidString).json")
        try "not-valid-json{{{".write(to: cacheDir, atomically: true, encoding: .utf8)

        let result = await MapCacheService.shared.load(for: testId)
        XCTAssertNil(result, "Corrupt cache should return nil")
    }
}
```

**Problem mit `saveIfChanged`:** Der Hash-Vergleich ist instanzgebunden (`lastDataHash`). Da `shared` singleton ist, kann ein vorheriger Test-State stören. Entweder `save()` (ohne Hash) für Tests verwenden, oder `lastDataHash` für den testId nach jedem Test zurücksetzen.

### Anti-Patterns to Avoid
- **XCWaiter/sleep für Timing:** Nicht `Task.sleep` in Tests nutzen um Backoff zu simulieren — extrahiere die Logik als pure function.
- **`MapViewModel` für Hit-Test-Tests instanziieren:** Zu viele Abhängigkeiten. Die Pixel-Key-Logik ist unabhängig testbar.
- **`UIApplication.shared` in UpdateService-Tests:** `startApply` ruft `UIApplication.shared.beginBackgroundTask` auf — das schlägt in Unit-Tests fehl. Tests sollten nur `checkForUpdates`, `startDownload` und Phase-Mapping testen.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Mock-HTTP-Server | Custom URLSession-Mock | Protokoll-Abstraktion auf ValetudoAPI | Einfacher, kein Netzwerk |
| Async-Test-Utilities | Eigene XCTestExpectation-Wrapper | Native `async throws` in XCTestCase | iOS 15.4+ unterstützt nativ |
| JSON-Test-Fixtures als Dateien | .json-Ressourcendateien im Test-Bundle | Inline-JSON-Strings (wie in MapLayerTests) | Bestehende Praxis im Projekt |

**Key insight:** Das Projekt hat bewusst null externe Abhängigkeiten — kein Quick/Nimble, kein OHHTTPStubs. Diese Entscheidung beibehalten.

## Common Pitfalls

### Pitfall 1: `@MainActor` in async Tests
**Was schiefgeht:** `UpdateService` ist `@MainActor`. Tests die `await service.checkForUpdates()` aufrufen, müssen ebenfalls `@MainActor` sein.
**Ursache:** Swift strict concurrency prüft das seit Swift 5.9.
**Vermeidung:** `@MainActor func testXxx() async throws` annotieren.
**Warnsignal:** Compiler-Error "expression is 'async' but is not marked with 'await'"

### Pitfall 2: `ValetudoAPI` ist ein `actor` — kein Subclassing
**Was schiefgeht:** `class MockAPI: ValetudoAPI` kompiliert nicht — actors können nicht subgeclasst werden.
**Ursache:** Swift actors sind `final`.
**Vermeidung:** Protokoll-Abstraktion einführen (siehe Pattern 3).

### Pitfall 3: `MapCacheService.shared` — Singleton-Seiteneffekte zwischen Tests
**Was schiefgeht:** Wenn Test A schreibt und Test B liest, gibt es State-Leakage.
**Ursache:** `lastDataHash` ist pro-singleton, nicht pro-Test.
**Vermeidung:** Immer eindeutige UUIDs pro Test, `tearDown` mit `deleteCache`.

### Pitfall 4: `calculateMapParams` mit leeren Layern
**Was schiefgeht:** Gibt `nil` zurück wenn alle Layer leer sind — Tests dafür schreiben.
**Ursache:** Guard auf `minX < Int.max`.
**Vermeidung:** Explizit den nil-Fall testen.

### Pitfall 5: Pixel-Key-Kollisionen bei großen Koordinaten
**Was schiefgeht:** `x &<< 16 | y` kann kollidieren wenn x oder y > 65535.
**Ursache:** Bit-Shifting mit 16 Bits limitiert den Wertebereich.
**Vermeidung:** Testfall mit Koordinaten > 65535 schreiben um das Verhalten zu dokumentieren (auch wenn Roboter-Maps typischerweise < 65535 sind).

## Code Examples

### TEST-01: calculateMapParams mit bekannten Pixeln
```swift
// Source: MapGeometry.swift:21-56
func testCalculateMapParamsScaling() throws {
    // Layer mit einem Pixel bei (100, 200)
    let json = #"{"compressedPixels": [100, 200, 1]}"#
    let layer = try JSONDecoder().decode(MapLayer.self, from: json.data(using: .utf8)!)
    let size = CGSize(width: 400, height: 400)
    let params = calculateMapParams(layers: [layer], pixelSize: 5, size: size, padding: 20)
    XCTAssertNotNil(params)
    XCTAssertEqual(params!.minX, 100)
    XCTAssertEqual(params!.minY, 200)
    XCTAssertGreaterThan(params!.scale, 0)
}

func testCalculateMapParamsReturnsNilForEmptyLayers() {
    let params = calculateMapParams(layers: [], pixelSize: 5, size: CGSize(width: 400, height: 400))
    XCTAssertNil(params)
}
```

### TEST-01: screenToMapCoords / mapToScreenCoords Round-Trip
```swift
// Source: MapGeometry.swift:61-86
func testCoordinateRoundTrip() {
    let viewSize = CGSize(width: 400, height: 600)
    let scale: CGFloat = 2.5
    let offset = CGSize(width: 30, height: -20)
    let original = CGPoint(x: 123, y: 456)

    let mapCoords = screenToMapCoords(original, scale: scale, offset: offset, viewSize: viewSize)
    let roundTripped = mapToScreenCoords(mapCoords, scale: scale, offset: offset, viewSize: viewSize)

    XCTAssertEqual(roundTripped.x, original.x, accuracy: 0.001)
    XCTAssertEqual(roundTripped.y, original.y, accuracy: 0.001)
}
```

### TEST-02: UpdatePhase Mapping aus UpdaterState
```swift
// Source: UpdateService.swift:253-267 — mapUpdaterState ist private
// Strategie: Mock-API mit Protokoll, dann checkForUpdates() aufrufen

@MainActor
func testCheckForUpdatesTransitionsToUpdateAvailable() async throws {
    let mock = MockValetudoAPI()
    mock.updaterStateToReturn = UpdaterState(
        __class: "ValetudoUpdaterApprovalPendingState",
        busy: nil, currentVersion: nil, version: nil,
        releaseTimestamp: nil, downloadUrl: nil, downloadPath: nil, metaData: nil
    )
    let service = UpdateService(api: mock)
    await service.checkForUpdates()
    XCTAssertEqual(service.phase, .updateAvailable)
}

@MainActor
func testCheckForUpdatesErrorRecovery() async throws {
    let mock = MockValetudoAPI()
    mock.shouldThrow = true
    let service = UpdateService(api: mock)
    await service.checkForUpdates()
    if case .error = service.phase { /* pass */ } else {
        XCTFail("Expected error phase, got \(service.phase)")
    }
}
```

### TEST-03: SSE-Backoff als pure function
```swift
// Source: Nach Extraktion aus SSEConnectionManager.swift:101-108
func testBackoffDelay_firstRetry() {
    XCTAssertEqual(SSEConnectionManager.backoffDelay(retryCount: 1), 1.0)
}
func testBackoffDelay_secondRetry() {
    XCTAssertEqual(SSEConnectionManager.backoffDelay(retryCount: 2), 5.0)
}
func testBackoffDelay_thirdAndBeyond() {
    XCTAssertEqual(SSEConnectionManager.backoffDelay(retryCount: 3), 30.0)
    XCTAssertEqual(SSEConnectionManager.backoffDelay(retryCount: 100), 30.0)
}
```

### TEST-04: MapCacheService Save/Load/Corrupt
```swift
// Source: MapCacheService.swift:30-79
func makeMinimalRobotMap() -> RobotMap {
    RobotMap(size: nil, pixelSize: 5, layers: [], entities: [])
}
```

## UpdateService — Die 8 Phasen im Detail

| Phase | Enum Case | Ausgelöst durch | Vorgänger-Constraint |
|-------|-----------|-----------------|----------------------|
| idle | `.idle` | `reset()` / Reboot-Poll-Erfolg / Init | — |
| checking | `.checking` | `checkForUpdates()` | Muss `.idle` sein |
| updateAvailable | `.updateAvailable` | API liefert `ValetudoUpdaterApprovalPendingState` | via `mapUpdaterState` |
| downloading | `.downloading` | `startDownload()` | Muss `.updateAvailable` sein |
| readyToApply | `.readyToApply` | Poll liefert `ValetudoUpdaterApplyPendingState` | während `.downloading` |
| applying | `.applying` | `startApply()` | Muss `.readyToApply` sein |
| rebooting | `.rebooting` | `api.applyUpdate()` Erfolg | während `.applying` |
| error | `.error(String)` | Jeder `catch`-Block, Download-Timeout, Reboot-Timeout | aus `.checking`/`.downloading`/`.applying`/`.rebooting` |

**Transitionen die getestet werden müssen (TEST-02):**
1. `idle → checking → updateAvailable` (Normalfall)
2. `idle → checking → idle` (API liefert `ValetudoUpdaterIdleState` = kein Update)
3. `idle → checking → error` (API-Error)
4. `updateAvailable → downloading` (startDownload)
5. `downloading → readyToApply` (Poll-Erfolg)
6. `downloading → error` (API-Error in startDownload)
7. `downloading → error("Download wurde unterbrochen")` (Poll liefert idle)
8. `readyToApply → applying → rebooting` (startApply-Erfolg)

**Error-Recovery:** `reset()` → immer `.idle` egal aus welchem State.

## SSE-Backoff — Genaue Werte

Aus `SSEConnectionManager.swift` Lines 101–108:
- Retry 1: `delay = 1` (1 Sekunde)
- Retry 2: `delay = 5` (5 Sekunden)
- Retry >= 3: `delay = 30` (30 Sekunden, gecapped)

**Notiz:** Der Kommentar in der Datei sagt "1s → 5s → 30s" (Line 101) — das stimmt mit dem Code überein. Die ursprüngliche Aufgaben-Beschreibung nennt "2s/5s/30s" — das ist FALSCH. Der tatsächliche erste Delay ist 1s, nicht 2s. Tests müssen den Code-Wert (1s) testen, nicht den falschen Wert aus der Beschreibung.

## MapCacheService — Wichtige Details

- **Singleton:** `MapCacheService.shared` (kein Init in Tests direkt möglich)
- **Dateipfad:** `<Documents>/MapCache/<uuid>.json`
- **Format:** `JSONEncoder().encode(RobotMap.self)` → Standard Codable JSON
- **Hash-Check in `saveIfChanged`:** `data.hashValue` — verhindert unnötige Disk-Writes
- **Testbare Methoden:** `save(_:for:)`, `saveIfChanged(_:for:)`, `load(for:)`, `deleteCache(for:)`
- **Corrupted-Cache-Test:** Datei direkt mit ungültigem JSON überschreiben, dann `load` aufrufen — erwartet `nil`

## Environment Availability

Step 2.6: Nur Xcode + iOS Simulator benötigt.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build + Test | ✓ | Installiert (iOS 26.4 SDK) | — |
| iOS Simulator "iPhone 17" | xcodebuild -destination | ✓ | iOS 26.4 | iPhone 17 Pro (gleicher OS) |

**Keine fehlenden Dependencies.**

## Open Questions

1. **`mapUpdaterState` bleibt private oder wird zugänglich?**
   - Was wir wissen: Die Methode ist `private` in UpdateService
   - Was unklar ist: Ob das Protokoll-Pattern oder eine `internal`-Sichtbarkeit bevorzugt wird
   - Empfehlung: Protokoll-Extraktion für `ValetudoAPI` — ist die sauberste Lösung

2. **`startApply()` ruft `UIApplication.shared.beginBackgroundTask` auf — Unit-Test?**
   - Was wir wissen: Das schlägt in Tests fehl ohne laufende UIApplication
   - Was unklar ist: Ob `startApply` getestet werden soll oder nur der Phasen-Übergang
   - Empfehlung: `startApply`-Test überspringen (UIKit-Dependency), stattdessen den `applying → rebooting`-Übergang via `setPhase` testen — oder `beginBackgroundTask` via Dependency Injection mocken (out-of-scope für diese Phase)

3. **`saveIfChanged` Hash-Test — Singleton-State?**
   - Was wir wissen: `lastDataHash` ist pro-UUID gespeichert
   - Was unklar ist: Ob der Singleton-State zwischen Tests stört
   - Empfehlung: Zwei verschiedene UUIDs nutzen oder `save()` statt `saveIfChanged()` für den Basis-Test

## Sources

### Primary (HIGH confidence)
- Direkte Quellcode-Analyse: `MapGeometry.swift` — alle koordinatenbezogenen Funktionen
- Direkte Quellcode-Analyse: `UpdateService.swift` — alle 8 Phasen, alle Transitionen
- Direkte Quellcode-Analyse: `SSEConnectionManager.swift` — Backoff-Werte Lines 101–108
- Direkte Quellcode-Analyse: `MapCacheService.swift` — alle public API-Methoden
- Direkte Quellcode-Analyse: `MapInteractiveView.swift:271` — Hit-Test-Key-Formel
- Direkte Quellcode-Analyse: `MapViewModel.swift:291` — rebuildSegmentPixelSets
- Direkte Quellcode-Analyse: `project.yml` — Target-Konfiguration, Scheme

### Secondary (MEDIUM confidence)
- Bestehendes Testmuster aus `MapLayerTests.swift`, `MapViewModelTests.swift`, `KeychainStoreTests.swift`, `RobotDetailViewModelTests.swift`, `TimerTests.swift`

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — XCTest ist die einzige Option, keine Alternativen
- Architecture: HIGH — Quellcode direkt gelesen, kein Raten
- Pitfalls: HIGH — bekannte Swift Concurrency + actor + Singleton-Patterns
- SSE-Backoff-Werte: HIGH — direkt aus Source (1s/5s/30s, nicht 2s/5s/30s wie in der Phasenbeschreibung)

**Research date:** 2026-04-04
**Valid until:** 2026-05-04 (stabiles Projekt, kein aktiver Umbau dieser Klassen erwartet)
