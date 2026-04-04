# Phase 23: Error Handling & Robustness Patterns - Research

**Researched:** 2026-04-04
**Domain:** Swift/SwiftUI Error Handling, iOS 17+ @Observable MVVM, StoreKit 2
**Confidence:** HIGH (vollständige Codebase-Analyse)

## Summary

Phase 23 beseitigt fünf konkrete Tech-Debt-Punkte: stilles Verschlucken von Fehlern in Benutzeraktionen, eine DebugConfig die fälschlich API-Fehler maskiert, ein fragiles `isInitialLoad`-Pattern in RobotSettingsViewModel, fehlendes Capabilities-Caching mit TTL, und fehlende Runtime-Validierung der StoreKit Product IDs.

Die zentrale Infrastruktur ist bereits vorhanden: `ErrorRouter` ist im Environment eingehängt und `withErrorAlert()` wird auf den Root-Views angewendet. Das Problem ist, dass ViewModels und Views den `ErrorRouter` nicht kennen — sie loggen Fehler nur intern oder ignorieren sie komplett. Die Lösung erfordert, dass ViewModels den `ErrorRouter` als Dependency bekommen oder Views die Fehler-Weiterleitung übernehmen.

Das `isInitialLoad`-Pattern ist eine bekannte SwiftUI-Falle: Toggle-`onChange`-Handler werden beim Populieren der Werte aus der API ausgelöst, bevor der User jemals die UI berührt hat. Das Two-Phase-Pattern (load → apply → enable onChange) ist die kanonische Lösung. Der bestehende Code hat dieses Pattern bereits ansatzweise implementiert — es muss nur robuster gemacht werden.

**Primary recommendation:** ErrorRouter als Parameter in ViewModels injizieren (nicht als @Environment — ViewModels sind keine Views). Capabilities werden pro Robot gecacht mit TTL von 24h und Force-Refresh nach pollUntilReboot().

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEBT-03 | Kein `try?` in benutzer-initiierten Aktionen — Fehler werden dem Benutzer angezeigt | try? Inventory vollständig; ErrorRouter-Pattern dokumentiert |
| DEBT-04 | DebugConfig maskiert keine API-Fehler mehr — nur Mock-UI-Daten | DebugConfig analysiert; Fehler werden nur geloggt wenn Capability-Check fehlschlägt |
| DEBT-05 | `isInitialLoad`-Pattern durch Two-Phase-Pattern ersetzt | Alle 9 isInitialLoad-Vorkommen kartiert; Two-Phase-Pattern definiert |
| DEBT-06 | Capabilities nach OTA automatisch neu geladen (TTL oder Force-Refresh) | UpdateService pollUntilReboot() analysiert; kein Cache-Invalidation-Hook vorhanden |
| DEBT-07 | StoreKit Product IDs konfigurierbar mit Runtime-Validierung | Constants.swift analysiert; keine Validierung beim App-Start vorhanden |
</phase_requirements>

---

## DEBT-03: try? in benutzer-initiierten Aktionen

### Vollständiges Inventory aller `try?` in der Codebase

#### Benutzer-initiierte Aktionen (MÜSSEN gefixt werden)

| Datei | Zeile | Kontext | Problem |
|-------|-------|---------|---------|
| `RobotDetailViewModel.swift` | 340 | `try? await api.locate()` | locate() ist eine direkte Benutzeraktion — Fehler werden verschluckt |
| `MapViewModel.swift` | 301 | `if let newMap = try? await api.getMap()` | Innerhalb von joinRooms() nach join — Map-Reload-Fehler verschluckt |
| `MapViewModel.swift` | 304 | `if let newSegments = try? await api.getSegments()` | Innerhalb von joinRooms() — Segment-Reload-Fehler verschluckt |
| `MapViewModel.swift` | 348 | `if let newMap = try? await api.getMap()` | Innerhalb von splitRoom() — Map-Reload-Fehler verschluckt |
| `MapViewModel.swift` | 351 | `if let newSegments = try? await api.getSegments()` | Innerhalb von splitRoom() — Segment-Reload-Fehler verschluckt |
| `RobotSettingsViewModel.swift` | 497 | `if let state = try? await api.getVoicePackState()` | In setVoicePack() Error-Recovery — try? macht Recovery unsichtbar |
| `RobotSettingsViewModel.swift` | 510 | `(try? await api.getMapSnapshots()) ?? mapSnapshots` | In restoreMapSnapshot() — Post-Restore-Reload-Fehler verschluckt |

#### System/Background-Operationen (AKZEPTABEL — kein User-Feedback nötig)

| Datei | Zeile | Kontext | Begründung |
|-------|-------|---------|------------|
| `NetworkScanner.swift` | 54 | `try? await Task.sleep(for: .seconds(3))` | Task.sleep Cancellation — kein echter Fehler |
| `NetworkScanner.swift` | 172 | `try? decoder.decode(RobotInfo.self, ...)` | Discovery-Scan — Nicht-Valetudo-Hosts sind erwartet |
| `RobotIntents.swift` | 31, 66, 117, 265 | `try? JSONDecoder().decode(...)` | Siri Intents — kein UI zum Anzeigen von Fehlern |
| `RobotIntents.swift` | 73 | `try? await api.getSegments()` | Siri Intent — falls leer, keine Optionen anzeigen |
| `BackgroundMonitorService.swift` | 120, 127, 133 | JSON-En/Decoding in BGTask | Background-only, kein UI |
| `UpdateService.swift` | 63 | `try? await api.getValetudoVersion()` | Version-Load in loadVersionInfo() — non-fatal |
| `UpdateService.swift` | 185, 189, 224, 228 | `try? await Task.sleep(...)` + polling | Reboot/Download-Polling — Sleep-Cancellation ok |
| `RobotManager.swift` | 147 | `try? await Task.sleep(for: .seconds(5))` | Polling-Loop — Sleep-Cancellation ok |
| `RobotManager.swift` | 285, 314 | JSON-En/Decoding von robot configs | Persistence — graceful degradation ok |
| `RobotState.swift` | 181, 183, 845, 851 | Model-Decoding | Flexible JSON-Parsing — ok |
| `SupportReminderView.swift` | 94 | `try? await Task.sleep(for: .seconds(2))` | Animation-Delay — ok |
| `RobotDetailSections.swift` | 260 | `robotProperties = try? await p` | Async let result — via Task.group ok |
| `MapViewModel.swift` | 168, 269 | `try? await Task.sleep(...)` | Polling/Delay — ok |
| `MapViewModel.swift` | 170 | `if let newMap = try? await api.getMap()` | Background-Polling im Scroll-Idle — ok |
| `Views/MapView.swift` | 148 | `restrictions = try? await restrictionsTask` | MapPreviewView Restriction-Load — tolerable |
| `Views/MapView.swift` | 159, 161 | Sleep + getMap() in Poll-Loop | Background-Polling in Preview — ok |

### ErrorRouter-Pattern für ViewModels

`ErrorRouter` ist `@Observable` und im SwiftUI-Environment als `@Environment(ErrorRouter.self)` verfügbar. Views können ihn lesen, aber **ViewModels sind keine Views** — sie bekommen kein `@Environment`.

**Lösung: ErrorRouter als init-Parameter in ViewModels injizieren**

```swift
// AKTUELL
@MainActor
@Observable
final class RobotDetailViewModel {
    init(robot: RobotConfig, robotManager: RobotManager) { ... }
}

// NEU
@MainActor
@Observable
final class RobotDetailViewModel {
    private let errorRouter: ErrorRouter
    init(robot: RobotConfig, robotManager: RobotManager, errorRouter: ErrorRouter) {
        self.errorRouter = errorRouter
    }

    func locate() async {
        guard let api = api else { return }
        do {
            try await api.locate()
        } catch {
            logger.error("locate failed: \(error, privacy: .public)")
            errorRouter.show(error)
        }
    }
}
```

**View-seitige Initialisierung:**

```swift
// RobotDetailView.swift
struct RobotDetailView: View {
    @Environment(ErrorRouter.self) var errorRouter
    // ...
    init(robot: RobotConfig, robotManager: RobotManager) {
        // errorRouter wird in onAppear oder via init(@Environment) gesetzt
    }
}
```

**Problem:** `@Observable` ViewModels werden in `State(initialValue:)` aus dem View-init heraus erstellt, bevor `@Environment` verfügbar ist. Optionen:

1. **Lazy init via `.task`**: ViewModel ohne errorRouter erstellen, dann in `.task { viewModel.errorRouter = errorRouter }` setzen. Erfordert `var errorRouter: ErrorRouter?` im ViewModel.
2. **Direkte Injection via init**: View übergibt ErrorRouter an ViewModel-init. View holt ihn via `@Environment` und gibt ihn weiter in `init(robot:robotManager:errorRouter:)`.

**Empfehlung: Option 2 — explizite Injection**. RobotDetailView bekommt `@Environment(ErrorRouter.self)` und erstellt das ViewModel in `.task` oder über einen separaten `setup`-Call. Alternativ: ViewModel als `@State` deklarieren, in `onAppear` konfigurieren.

Der einfachste Ansatz ohne architektonische Umbauarbeit: ViewModel bekommt `var errorRouter: ErrorRouter?` als Optional-Property. View setzt es in `.onAppear` oder `.task`. Das ist akzeptabel weil ErrorRouter immer im Environment vorhanden ist, bevor eine View erscheint.

---

## DEBT-04: DebugConfig maskiert API-Fehler

### Aktueller Zustand

`DebugConfig` hat nur ein einziges Property:

```swift
// Helpers/DebugConfig.swift
enum DebugConfig {
    static let showAllCapabilities = false  // hardcoded false in production
}
```

**DebugConfig maskiert KEINE API-Fehler direkt** — das ist ein Missverständnis. Was passiert stattdessen:

In `RobotSettingsViewModel.loadSettings()`:
```swift
do {
    volume = Double(try await api.getSpeakerVolume())
} catch {
    if !DebugConfig.showAllCapabilities { hasVolumeControl = false }
    // KEIN logger.error() hier — Fehler wird vollständig verschluckt!
}
```

Das Problem: Bei einem echten Netzwerkfehler (Timeout, HTTP 500) wird die Capability als "nicht vorhanden" behandelt. Es gibt **kein Logging** in diesen catch-Blöcken. Der Fehler verschwindet komplett.

Gleiches Pattern in `RobotDetailViewModel.loadCapabilities()`:
```swift
} catch {
    logger.error("Failed to load capabilities: \(error, privacy: .public)")
    // Capabilities bleiben auf DebugConfig.showAllCapabilities-Default
}
```

Dieser Block loggt zumindest — aber setzt keine Capability-Flags zurück.

### Wo DebugConfig legitim und wo problematisch ist

**Legitim (Mock-UI-Daten für Development):**
- Default-Werte von Capability-Flags: `var hasVolumeControl = DebugConfig.showAllCapabilities`
- Mock-Presets wenn API leer: `if DebugConfig.showAllCapabilities && fanSpeedPresets.isEmpty { fanSpeedPresets = ["low", ...] }`
- Anzeige von Sektionen die sonst leer wären

**Problematisch (verschluckt reale Fehler):**
- `catch { if !DebugConfig.showAllCapabilities { hasX = false } }` — kein Logging im catch
- `catch { hasMappingPass = DebugConfig.showAllCapabilities }` — kein Logging

### Fix

In allen catch-Blöcken die Capability-Flags setzen: **immer** loggen, Capability-Flag setzen unabhängig von DebugConfig:

```swift
// VORHER (problematisch)
do {
    volume = Double(try await api.getSpeakerVolume())
} catch {
    if !DebugConfig.showAllCapabilities { hasVolumeControl = false }
}

// NACHHER (korrekt)
do {
    volume = Double(try await api.getSpeakerVolume())
} catch {
    logger.error("getSpeakerVolume failed: \(error, privacy: .public)")
    if !DebugConfig.showAllCapabilities { hasVolumeControl = false }
}
```

Die Semantik von `DebugConfig.showAllCapabilities` bleibt erhalten (UI zeigt alle Capabilities auch wenn API nicht antwortet) — aber der Fehler wird nie mehr still verschluckt.

---

## DEBT-05: isInitialLoad-Pattern in RobotSettingsViewModel

### Alle Vorkommen

**ViewModel-seitig (RobotSettingsViewModel.swift):**
- Zeile 74: `var isInitialLoad = true` — Property
- Zeile 297: `isInitialLoad = false` — gesetzt am Ende von `loadSettings()`

**View-seitig (RobotSettingsView.swift):**
- Zeile 79, 93, 107, 121, 135: `guard !viewModel.isInitialLoad else { return }` in onChange-Handlern

**View-seitig (RobotSettingsSections.swift — StationSettingsView):**
- Zeile 779: `@State private var isInitialLoad = true` — lokales View-State
- Zeile 831, 854, 872, 890: `guard !isInitialLoad && ...` in onChange-Handlern
- Zeile 1006: `isInitialLoad = false` am Ende von `loadStation()`

### Das Problem

`isInitialLoad` ist ein Boolean der anzeigt: "Wir laden gerade Daten aus der API — ignoriere onChange-Events." Probleme:

1. **Race Condition**: Wenn `loadSettings()` async ist und Views sich während des Ladens aktualisieren, kann `isInitialLoad` bereits `false` sein bevor alle Werte gesetzt sind.
2. **Nicht komposit**: Jedes neue Picker/Toggle braucht `guard !isInitialLoad` — vergisst man es, feuert sofort ein API-Call beim Laden.
3. **Kein Re-Load-Schutz**: Wird `loadSettings()` ein zweites Mal gerufen (z.B. bei Tab-Wechsel), wird `isInitialLoad` nicht auf `true` zurückgesetzt — ein zweiter Aufruf könnte onChange-Handler auslösen.

### Two-Phase-Load-Pattern

Das Pattern trennt "Lade-Phase" und "Aktiv-Phase" sauber:

```swift
// PHASE 1: Alle Werte laden — onChange-Handler reagieren nicht (isLoaded == false)
// PHASE 2: isLoaded = true setzen — ab jetzt lösen User-Aktionen API-Calls aus

@MainActor
@Observable
final class RobotSettingsViewModel {
    // Laden-Zustand
    private(set) var settingsLoaded = false

    // Werte
    var carpetMode = false

    func loadSettings() async {
        settingsLoaded = false
        defer { settingsLoaded = true }

        // ... alle API-Calls ...
        do { carpetMode = try await api.getCarpetMode() } catch { ... }
        // ...
    }
}
```

**In der View:**

```swift
Toggle(isOn: $viewModel.carpetMode) { ... }
    .onChange(of: viewModel.carpetMode) { _, newValue in
        guard viewModel.settingsLoaded else { return }
        Task { await viewModel.setCarpetMode(newValue) }
    }
```

**Vorteil gegenüber isInitialLoad:** `settingsLoaded` wird am Anfang jedes `loadSettings()`-Aufrufs auf `false` zurückgesetzt, nicht nur beim ersten Laden. Das macht Re-Loads korrekt.

**Für StationSettingsView**: Da dieser View kein ViewModel hat (nutzt direkt API + @State), bleibt `isInitialLoad` als `@State` sinnvoll — es muss aber ebenfalls zu Beginn jedes `loadStation()`-Aufrufs auf `false` zurückgesetzt werden.

---

## DEBT-06: Capabilities-Caching mit TTL nach OTA

### Aktueller Ladefluss

Capabilities werden aktuell bei jeder Anzeige neu geladen:

**RobotDetailViewModel.loadData()** — ruft `loadCapabilities()` auf, die `api.getCapabilities()` aufruft. Jedes Mal wenn `loadData()` gerufen wird (beim ersten Öffnen, bei jedem refreshData()-Call).

**RobotSettingsViewModel.loadSettings()** — ruft ebenfalls `api.getCapabilities()` auf.

**StationSettingsView** — ruft `api.getCapabilities()` separat auf.

Kein Caching, kein TTL, keine Koordination zwischen ViewModels.

### OTA-Update-Flow

Nach einem OTA-Update durchläuft UpdateService folgendem Flow:
1. `startApply()` → Phase `.applying`
2. `pollUntilReboot()` — wartet bis Roboter nicht erreichbar ist, dann bis er wieder antwortet
3. Bei Erfolg: `setPhase(.idle)` — **kein Hook für "frischer Reboot, Capabilities könnten anders sein"**

`pollUntilReboot()` erkennt wann der Roboter wieder online ist (via `api.getValetudoVersion()`). Dieser Moment ist der natürliche Trigger für einen Capabilities-Force-Refresh.

### Empfohlene Architektur: TTL-Cache in RobotManager

Da `RobotManager` die zentrale Zustandsverwaltung ist und alle ViewModels darauf zugreifen, sollte der Capabilities-Cache dort leben:

```swift
// RobotManager.swift
@MainActor
@Observable
class RobotManager {
    // ...
    @ObservationIgnored private var capabilitiesCache: [UUID: [String]] = [:]
    @ObservationIgnored private var capabilitiesCacheTime: [UUID: Date] = [:]
    private let capabilitiesTTL: TimeInterval = 86400 // 24 Stunden

    func getCapabilities(for robotId: UUID) -> [String]? {
        guard let time = capabilitiesCacheTime[robotId],
              Date().timeIntervalSince(time) < capabilitiesTTL else { return nil }
        return capabilitiesCache[robotId]
    }

    func setCapabilities(_ capabilities: [String], for robotId: UUID) {
        capabilitiesCache[robotId] = capabilities
        capabilitiesCacheTime[robotId] = Date()
    }

    func invalidateCapabilities(for robotId: UUID) {
        capabilitiesCache.removeValue(forKey: robotId)
        capabilitiesCacheTime.removeValue(forKey: robotId)
    }
}
```

**Force-Refresh nach OTA:** UpdateService bekommt eine Callback-Closure oder der RobotManager beobachtet UpdateService-Phase-Änderungen. Wenn Phase von `.rebooting` auf `.idle` wechselt, `invalidateCapabilities(for: robotId)` aufrufen.

**Alternative (simpler):** Capabilities-TTL von 24h reicht für normalen Betrieb. Kein OTA-Hook nötig wenn TTL kurz genug ist. Aber: nach einem OTA kann eine neue Capability vorhanden sein, die erst nach 24h auftaucht — das wäre für den Nutzer verwirrend.

**Empfehlung:** TTL 24h + Force-Invalidate nach OTA-Reboot in `pollUntilReboot()` am Ende.

---

## DEBT-07: StoreKit Product IDs Runtime-Validierung

### Aktueller Zustand

```swift
// Constants.swift
enum Constants {
    static let supportSmallId = "de.godsapp.valetudoapp.support.small"
    static let supportMediumId = "de.godsapp.valetudoapp.support.medium"
    static let supportLargeId = "de.godsapp.valetudoapp.support.large"

    static let supportProductIds: Set<String> = [
        supportSmallId, supportMediumId, supportLargeId
    ]
}
```

```swift
// SupportManager.swift
func loadProducts() async {
    products = try await Product.products(for: Constants.supportProductIds)
        .sorted { $0.price < $1.price }
    // Kein Check ob products.count == Constants.supportProductIds.count
}
```

**Problem:** Wenn ein Product ID in App Store Connect falsch konfiguriert ist oder nicht existiert, gibt StoreKit eine leere oder unvollständige Liste zurück — ohne Fehler. Der User sieht dann weniger Kauf-Optionen, und niemand bemerkt es.

### Empfohlene Validierung

In `SupportManager.loadProducts()` nach dem Laden:

```swift
func loadProducts() async {
    isLoading = true
    defer { isLoading = false }

    do {
        let loaded = try await Product.products(for: Constants.supportProductIds)
            .sorted { $0.price < $1.price }
        products = loaded

        // Validierung: Jede konfigurierte ID muss geladen worden sein
        let loadedIds = Set(loaded.map { $0.id })
        let missingIds = Constants.supportProductIds.subtracting(loadedIds)
        if !missingIds.isEmpty {
            logger.error("StoreKit Product IDs nicht gefunden: \(missingIds.joined(separator: ", "), privacy: .public)")
        }
    } catch {
        logger.error("Failed to load products: \(error.localizedDescription, privacy: .public)")
    }
}
```

**Beim App-Start** (optional, zusätzlich): Validierung einmalig in `SupportManager.init()` oder beim ersten `loadProducts()`-Aufruf. Kein Alert nötig — nur Logging für Debugging.

---

## ErrorRouter — Existierende Infrastruktur

### Wie ErrorRouter aktuell funktioniert

```swift
// Helpers/ErrorRouter.swift
@MainActor @Observable final class ErrorRouter {
    var currentError: Error?
    var retryAction: (() async -> Void)?

    func show(_ error: Error, retry: (() async -> Void)? = nil) {
        currentError = error
        retryAction = retry
    }

    func dismiss() { currentError = nil; retryAction = nil }
}

extension View {
    func withErrorAlert(router: ErrorRouter) -> some View {
        self.alert(String(localized: "error.title"), isPresented: ...) { _ in
            if router.retryAction != nil {
                Button(String(localized: "error.retry")) {
                    Task { await router.retryAction?() }
                    router.dismiss()
                }
            }
            Button("OK", role: .cancel) { router.dismiss() }
        } message: { error in
            Text((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
```

### Wo withErrorAlert bereits verdrahtet ist

- `ValetudoApp.swift` Zeile 54: `ContentView().withErrorAlert(router: errorRouter)` (ContentView)
- `ValetudoApp.swift` Zeile 62: `OnboardingView().withErrorAlert(router: errorRouter)` (OnboardingView)

Der Alert wird also auf Root-Ebene angezeigt — kein `.withErrorAlert()` in einzelnen Views nötig.

### Wo ErrorRouter NICHT genutzt wird (trotz existierender Infrastruktur)

- `ContentView` liest `@Environment(ErrorRouter.self) var errorRouter` — aber nutzt es nicht aktiv
- Kein ViewModel hat ErrorRouter als Dependency
- `MapViewModel` hat `var errorMessage: String? = nil` — eigenes Error-Handling parallel zu ErrorRouter

### Zugang für ViewModels

**Problem:** ViewModels haben kein `@Environment`. Optionen:

1. **Explicit init-Parameter**: ViewModel bekommt `errorRouter: ErrorRouter` im init. View schlägt ihn aus `@Environment` nach und gibt ihn beim ViewModel-Init weiter.

2. **Optional Property + late binding**: 
```swift
@Observable final class RobotDetailViewModel {
    var errorRouter: ErrorRouter?
    // View setzt in .task { viewModel.errorRouter = errorRouter }
}
```

3. **Shared singleton** (nicht empfohlen): `ErrorRouter` als Singleton — widerspricht SwiftUI-Environment-Konzept.

**Empfehlung: Option 2 (Optional Property)**. Minimale Invasivität. ErrorRouter wird immer gesetzt bevor User-Aktionen ausgeführt werden können.

**Für MapViewModel**: Bereits `var errorMessage: String?` vorhanden. Diese Property kann beibehalten werden für die interne Map-Fehlerdarstellung (z.B. Banner im Map-Canvas). ErrorRouter zusätzlich für kritische Aktionsfehler.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | UI Framework | Projekt-Standard |
| @Observable (Observation) | iOS 17+ | ViewModel State | Bereits migriert (Phase 19) |
| StoreKit 2 | iOS 15+ | In-App Purchases | Bereits genutzt |
| os.Logger | iOS 14+ | Structured Logging | Bereits konsequent genutzt |

### No External Dependencies
Das Projekt hat bewusst null externe Dependencies — bleibt so.

---

## Architecture Patterns

### Pattern 1: Two-Phase-Load-Pattern

```swift
@MainActor @Observable final class RobotSettingsViewModel {
    // Renamed from isInitialLoad to settingsLoaded (positive semantics)
    private(set) var settingsLoaded = false

    func loadSettings() async {
        settingsLoaded = false   // Reset für Re-Loads
        defer { settingsLoaded = true }

        isLoading = true
        defer { isLoading = false }

        // ... alle API-Calls ...
    }
}

// View:
Toggle(isOn: $viewModel.carpetMode) { ... }
    .onChange(of: viewModel.carpetMode) { _, newValue in
        guard viewModel.settingsLoaded else { return }
        Task { await viewModel.setCarpetMode(newValue) }
    }
```

### Pattern 2: ErrorRouter-Injection in ViewModel

```swift
@MainActor @Observable final class RobotDetailViewModel {
    var errorRouter: ErrorRouter?

    func locate() async {
        guard let api = api else { return }
        do {
            try await api.locate()
        } catch {
            logger.error("locate failed: \(error, privacy: .public)")
            errorRouter?.show(error)
        }
    }
}

// Initialisierung in View:
struct RobotDetailView: View {
    @Environment(ErrorRouter.self) var errorRouter
    @State private var viewModel: RobotDetailViewModel

    var body: some View {
        // ...
        .task {
            viewModel.errorRouter = errorRouter
            await viewModel.loadData()
        }
    }
}
```

### Pattern 3: Capabilities-TTL-Cache

```swift
// RobotManager — zentraler Cache
@ObservationIgnored private var capabilitiesCache: [UUID: [String]] = [:]
@ObservationIgnored private var capabilitiesCacheDate: [UUID: Date] = [:]
let capabilitiesTTL: TimeInterval = 86400 // 24h

func cachedCapabilities(for robotId: UUID) -> [String]? {
    guard let date = capabilitiesCacheDate[robotId],
          Date().timeIntervalSince(date) < capabilitiesTTL else { return nil }
    return capabilitiesCache[robotId]
}

func cacheCapabilities(_ capabilities: [String], for robotId: UUID) {
    capabilitiesCache[robotId] = capabilities
    capabilitiesCacheDate[robotId] = Date()
}

func invalidateCapabilities(for robotId: UUID) {
    capabilitiesCache.removeValue(forKey: robotId)
    capabilitiesCacheDate.removeValue(forKey: robotId)
}
```

### Anti-Patterns to Avoid

- **try? in Benutzeraktionen**: Fehler werden nie angezeigt, Debugging ist unmöglich
- **Logging nur wenn DebugConfig.showAllCapabilities == false**: Logge IMMER, unabhängig von Debug-Flags
- **isInitialLoad ohne Reset bei Re-Load**: Zweiter loadSettings()-Aufruf hat korrupten Initialzustand

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Error-Alert-Infrastruktur | Custom Alert-Handler | `ErrorRouter` + `withErrorAlert()` — schon vorhanden | Bereits implementiert, Root-Level-Binding vorhanden |
| StoreKit-Fehlerbehandlung | Custom Error-Types | `StoreKit.Product.PurchaseError` + `localizedDescription` | StoreKit 2 liefert lokalisierte Fehlerbeschreibungen |
| Capability-Cache-Invalidation | Komplexes Observer-Pattern | Simple `invalidateCapabilities()` Call nach OTA-Reboot | Einfachste Lösung, OTA-Punkt ist klar definiert |

---

## Common Pitfalls

### Pitfall 1: ErrorRouter vor ViewModel-Actions setzen

**What goes wrong:** View erstellt ViewModel im init, aber `@Environment(ErrorRouter.self)` ist im init nicht verfügbar. Wenn dann sofort `loadData()` aufgerufen wird und ein Fehler auftritt, ist `errorRouter` noch nil.

**Why it happens:** SwiftUI-Environment ist erst verfügbar nachdem der View-Body evaluiert wurde, nicht im init.

**How to avoid:** `errorRouter` setzen in `.task { viewModel.errorRouter = errorRouter; await viewModel.loadData() }` — nicht in `.onAppear`.

**Warning signs:** `errorRouter?.show(error)` wird aufgerufen aber kein Alert erscheint.

### Pitfall 2: isInitialLoad Race Condition

**What goes wrong:** `loadSettings()` setzt Werte async. Wenn SwiftUI-Rendering zwischen zwei async-Schritten rendert, kann ein onChange-Handler feuern während `isInitialLoad == true` aber eine andere Variable bereits gesetzt wurde.

**Why it happens:** @Observable mit async Mutations — SwiftUI kann zwischen Mutations rendern.

**How to avoid:** Two-Phase-Pattern: `settingsLoaded = false` zu Beginn, erst am Ende der gesamten Lade-Sequenz auf `true` setzen.

### Pitfall 3: Capabilities-Cache invalidiert nicht auf RobotManager-Ebene

**What goes wrong:** RobotDetailViewModel und RobotSettingsViewModel laden Capabilities separat — beide haben ihren eigenen Stand. Nach OTA invalidiert nur einer davon seinen Cache.

**Why it happens:** Kein zentraler Cache.

**How to avoid:** Cache im RobotManager, alle ViewModels fragen dort nach. Nur eine Invalidierungs-Stelle.

### Pitfall 4: DebugConfig.showAllCapabilities maskiert Logging

**What goes wrong:** `catch { if !DebugConfig.showAllCapabilities { hasX = false } }` — wird für eine Capability kein Logging geschrieben, sieht ein echtes Netzwerkproblem aus wie "nicht unterstützt".

**Why it happens:** Pattern entstand um Debug-Modus zu ermöglichen — Logging wurde vergessen.

**How to avoid:** Immer loggen, dann Capability-Flag setzen. Das Debug-Flag steuert nur das Flag, nicht das Logging.

---

## Environment Availability

Step 2.6: SKIPPED — Phase ist ein reiner Code/Config-Change. Keine externen Tool-Dependencies. Xcode und Simulator sind für die Entwicklung vorausgesetzt.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (Xcode native) |
| Config file | `ValetudoApp/ValetudoAppTests/` |
| Quick run command | `xcodebuild test -scheme ValetudoApp -destination 'platform=iOS Simulator,name=iPhone 15'` |
| Full suite command | Same (alle Tests in einem Scheme) |

### Existing Test Files

- `ValetudoApp/ValetudoAppTests/MapViewModelTests.swift` — enthält Test für `errorMessage`
- `ValetudoApp/ValetudoAppTests/RobotDetailViewModelTests.swift` — enthält DebugConfig-Guard
- `ValetudoApp/ValetudoAppTests/RobotSettingsViewModelTests.swift` — enthält DebugConfig-Guard

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Notes |
|--------|----------|-----------|-------|
| DEBT-03 | locate() leitet Fehler an ErrorRouter weiter | unit | Mock API + Mock ErrorRouter; prüfe `errorRouter.currentError != nil` nach locate() mit throwing API |
| DEBT-03 | joinRooms() leitet Fehler an ErrorRouter weiter | unit | Nach throw: errorRouter.currentError != nil |
| DEBT-03 | splitRoom() leitet Fehler an ErrorRouter weiter | unit | Nach throw: errorRouter.currentError != nil |
| DEBT-04 | Alle catch-Blöcke in loadSettings() loggen immer | manual review | Kein automatischer Test für Logger-Output sinnvoll |
| DEBT-05 | settingsLoaded ist false während loadSettings() läuft | unit | Async test mit Task; prüfe settingsLoaded Zustand |
| DEBT-05 | settingsLoaded wird bei Re-Load zurückgesetzt | unit | loadSettings() zweimal aufrufen; während zweitem Aufruf settingsLoaded == false prüfen |
| DEBT-06 | Capabilities werden aus Cache zurückgegeben wenn TTL nicht abgelaufen | unit | RobotManager-Test; cacheCapabilities() dann cachedCapabilities() prüfen |
| DEBT-06 | Cache wird nach OTA-Reboot invalidiert | unit | invalidateCapabilities() aufrufen; danach cachedCapabilities() == nil |
| DEBT-07 | Fehlende Product IDs werden geloggt | manual review | StoreKit-Mocking ist komplex; manueller Test mit falschem Product-ID |

### Wave 0 Gaps

- [ ] `ValetudoApp/ValetudoAppTests/ErrorRouterInjectionTests.swift` — Tests für DEBT-03 (locate, joinRooms, splitRoom mit ErrorRouter)
- [ ] `ValetudoApp/ValetudoAppTests/TwoPhaseLoadTests.swift` — Tests für DEBT-05 (settingsLoaded Race-Free)
- [ ] `ValetudoApp/ValetudoAppTests/CapabilitiesCacheTests.swift` — Tests für DEBT-06 (TTL + Invalidierung)

---

## Open Questions

1. **ErrorRouter Injection in MapViewModel**
   - Was wir wissen: MapViewModel hat bereits `var errorMessage: String?` — eigene Fehlerdarstellung
   - Was unklar ist: Soll MapViewModel errorRouter ZUSÄTZLICH nutzen oder errorMessage ersetzen?
   - Empfehlung: errorMessage beibehalten für Map-spezifische Fehleranzeige im Canvas-Banner; ErrorRouter für kritische Aktionsfehler (cleanSelectedRooms, join, split)

2. **Capabilities-Cache: RobotManager vs. ValetudoAPI**
   - Was wir wissen: RobotManager hat alle robots; ValetudoAPI ist pro-Robot
   - Was unklar ist: Cache in API (einfacher, kein Cross-Robot-State) oder RobotManager (zentraler, einfacher zu invalidieren)?
   - Empfehlung: RobotManager — passt besser zur existierenden Architektur (robotStates, lastConsumableCheck sind bereits dort)

3. **StoreKit Product IDs konfigurierbar machen (DEBT-07)**
   - Was wir wissen: Derzeit hardcoded in Constants.swift
   - Was unklar ist: "Konfigurierbar" bedeutet vermutlich Remote-Config (z.B. plist in Bundle) — aber das ist aufwändiger
   - Empfehlung: Constants.swift bleibt Single-Source-of-Truth; "konfigurierbar" wird interpretiert als "klar benannte Konstanten" + Runtime-Validierung, nicht als Remote-Config

---

## Sources

### Primary (HIGH confidence)
- Direkte Code-Analyse: alle relevanten Swift-Dateien vollständig gelesen
- Swift Concurrency + @Observable: Teil des iOS 17 SDK (Trainingswissen bestätigt durch Codebase-Patterns)

### Secondary (MEDIUM confidence)
- SwiftUI onChange-Pattern für Initialization-Schutz: Etabliertes Community-Pattern, in Codebase sichtbar
- StoreKit 2 `Product.products(for:)` Rückgabe bei unbekannten IDs: Gibt leere Liste ohne Fehler (aus bestehenden Mustern im Code erschlossen)

## Metadata

**Confidence breakdown:**
- try? Inventory: HIGH — alle Dateien durchsucht, vollständige Liste
- DebugConfig-Analyse: HIGH — vollständiger DebugConfig.swift gelesen, alle Verwendungsstellen kartiert
- isInitialLoad-Pattern: HIGH — alle 9 Vorkommen gefunden
- Capabilities-Caching: HIGH — kein existierendes Caching bestätigt
- ErrorRouter-Infrastruktur: HIGH — vollständig analysiert

**Research date:** 2026-04-04
**Valid until:** 2026-05-04 (stabiler Code, keine externen Abhängigkeiten)
