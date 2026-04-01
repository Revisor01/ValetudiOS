# Phase 12: State Machine Foundation — Research

**Researched:** 2026-04-01
**Domain:** Swift/SwiftUI State Machine, ObservableObject Service Pattern, iOS Concurrency
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**UpdatePhase Enum Design:** App-eigene States mit Mapping von Valetudo-API-States.
- `idle` — kein Update aktiv
- `checking` — prüft auf Updates
- `updateAvailable` — Update verfügbar, wartet auf User-Aktion
- `downloading` — Download läuft
- `readyToApply` — Download fertig, Apply möglich
- `applying` — Update wird angewendet (App-eigener State)
- `rebooting` — Roboter startet neu (App-eigener State)
- `error(String)` — Fehler mit lesbarer Nachricht

**UpdateService Architektur:** `@MainActor class UpdateService: ObservableObject` mit `@Published var phase: UpdatePhase`. Hält Referenz auf `ValetudoAPI`. Konsistent mit bestehendem ObservableObject-Pattern.

**Error-State Granularität:** `case error(String)` — ein einziger Error-Case. Keine Sub-Fehlertypen in Phase 12.

**Re-Entrancy-Guard:** State-Machine-basiert. Keine separate Bool-Property. `startDownload()` prüft `guard case .updateAvailable = phase`. `startApply()` prüft `guard case .readyToApply = phase`.

### Nicht in Scope
- UI-Änderungen (Phase 15)
- Fullscreen-Lock/Idle Timer (Phase 14)
- Entfernung doppelter Properties (Phase 13)

### Deferred Ideas
(keine)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| STATE-01 | Update-Zustand wird als enum-basierte State Machine modelliert (Idle, Checking, Downloading, ReadyToApply, Applying, Rebooting, Error) | UpdatePhase enum mit 8 Cases, assoziierter String-Wert bei `.error` |
| STATE-02 | startUpdate() hat einen Re-Entrancy-Guard — Doppelaufruf wird verhindert | Pattern-Matching-Guard auf `phase` statt separater Bool-Flag |
| STATE-03 | Valetudo ErrorState wird im Model abgebildet und zeigt Fehlermeldung an | Catch-Block setzt `phase = .error(message)`, kein stilles Reset |
| STATE-04 | Ein zentraler UpdateService ist die einzige Source of Truth für Update-Zustand | RobotDetailViewModel delegiert an UpdateService, ValetudoInfoView erhält UpdateService |
</phase_requirements>

---

## Summary

Phase 12 konsolidiert die aktuell über drei Stellen verteilte Update-Logik in einen zentralen `UpdateService`. Das Problem ist konkret: `RobotDetailViewModel` hat 6 separate `@Published`-Properties für Update-State, `ValetudoInfoView` hat eine eigene unabhängige Kopie des States, und es gibt keinen Re-Entrancy-Schutz. Ein zweiter Tap auf "Update starten" löst tatsächlich einen zweiten API-Call aus.

Die Lösung folgt dem in der Codebase bereits etablierten Pattern: `@MainActor class UpdateService: ObservableObject`. Dieses Pattern ist direkt in `RobotManager` und `NotificationService` sichtbar. `UpdateService` bekommt `@Published var phase: UpdatePhase` als Single Source of Truth. `RobotDetailViewModel` und `ValetudoInfoView` lesen denselben `phase`-Wert.

In Phase 13 werden die nun redundanten Properties aus `RobotDetailViewModel` entfernt. In Phase 12 bleiben sie als Proxy-Delegation erhalten, um Breaking Changes zu vermeiden.

**Primary recommendation:** `UpdateService` als `@MainActor ObservableObject` mit Enum-State. Re-Entrancy per Pattern-Matching-Guard. Proxy-Delegation in `RobotDetailViewModel` ohne Funktionsänderung.

---

## Standard Stack

### Core
| Komponente | Version | Zweck | Warum Standard |
|------------|---------|-------|----------------|
| `@MainActor class ... ObservableObject` | Swift Concurrency (iOS 15+) | Thread-sicherer Service mit @Published binding | Identisches Pattern in RobotManager, NotificationService |
| `enum UpdatePhase` mit `indirect case error(String)` | Swift 5.9 | Typsichere State Machine | Enums mit assoziierten Werten sind die Swift-idiomatische State-Machine |
| `guard case .updateAvailable = phase else { return }` | Swift Pattern Matching | Re-Entrancy-Schutz | Kein separater Bool nötig — der Enum-State IS der Guard |
| `@Published var phase: UpdatePhase` | Combine/SwiftUI | View-Binding | Konsistent mit allen bestehenden @Published Properties |

### Keine neuen Abhängigkeiten
Phase 12 benötigt keine neuen Frameworks oder Packages. Alles wird mit Swift Standard Library und SwiftUI/Combine gelöst.

---

## Architecture Patterns

### Recommended File Structure
```
ValetudoApp/ValetudoApp/Services/
├── UpdateService.swift      ← NEU: Neue Datei, zentraler Service
├── RobotManager.swift       ← UNVERÄNDERT in Phase 12
├── ValetudoAPI.swift        ← UNVERÄNDERT
└── ...

ValetudoApp/ValetudoApp/ViewModels/
└── RobotDetailViewModel.swift  ← ANGEPASST: Proxy-Delegation

ValetudoApp/ValetudoApp/Views/
└── RobotSettingsSections.swift  ← ANGEPASST: UpdateService injiziert
```

### Pattern 1: UpdatePhase Enum Design

**Was:** Swift enum mit assoziierten Werten für vollständigen Update-Lifecycle.

**Wenn:** Immer wenn mehr als 2 parallele Bool-Flags nötig sind, um einen Zustand zu beschreiben.

**Beispiel:**
```swift
// Quelle: Locked Decision aus CONTEXT.md
enum UpdatePhase: Equatable {
    case idle
    case checking
    case updateAvailable
    case downloading
    case readyToApply
    case applying
    case rebooting
    case error(String)

    // Equatable: error(String) braucht manuelle Implementierung
    static func == (lhs: UpdatePhase, rhs: UpdatePhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.checking, .checking),
             (.updateAvailable, .updateAvailable), (.downloading, .downloading),
             (.readyToApply, .readyToApply), (.applying, .applying),
             (.rebooting, .rebooting):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}
```

**Wichtig:** Wenn `Equatable` gebraucht wird (z.B. für View-Conditions), muss `==` manuell implementiert werden, da `error(String)` einen assoziierten Wert hat. Alternativ: `Equatable` weglassen und nur Pattern-Matching nutzen.

### Pattern 2: UpdateService — ObservableObject mit @MainActor

**Was:** Zentraler Service, konsistent mit bestehendem Codebase-Pattern.

**Wenn:** Immer wenn ein Service SwiftUI-Views bindet.

**Beispiel:**
```swift
// Analog zu RobotManager.swift:5-6
@MainActor
class UpdateService: ObservableObject {
    @Published private(set) var phase: UpdatePhase = .idle

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio",
        category: "UpdateService"
    )
    private let api: ValetudoAPI
    private var pollingTask: Task<Void, Never>?

    init(api: ValetudoAPI) {
        self.api = api
    }
}
```

**Hinweis:** `private(set)` macht `phase` read-only für Views — nur UpdateService kann ihn setzen. Konsistent mit SwiftUI-Datenfluss-Konvention.

### Pattern 3: Re-Entrancy-Guard per Pattern-Matching

**Was:** Swift Pattern-Matching-Guard verhindert ungültige State-Transitionen.

**Beispiel:**
```swift
// Locked Decision aus CONTEXT.md
func startDownload() async {
    guard case .updateAvailable = phase else {
        logger.warning("startDownload called in invalid state: \(String(describing: phase), privacy: .public)")
        return
    }
    phase = .downloading
    do {
        try await api.downloadUpdate()
        await pollUntilReadyToApply()
    } catch {
        phase = .error(error.localizedDescription)
    }
}

func startApply() async {
    guard case .readyToApply = phase else {
        logger.warning("startApply called in invalid state: \(String(describing: phase), privacy: .public)")
        return
    }
    phase = .applying
    do {
        try await api.applyUpdate()
        phase = .rebooting
    } catch {
        phase = .error(error.localizedDescription)
    }
}
```

### Pattern 4: Valetudo API State Mapping

**Was:** Mapping-Funktion konvertiert `UpdaterState.__class` → `UpdatePhase`.

**Warum separat:** Hält den Enum sauber von API-Details.

**Beispiel:**
```swift
// In UpdateService, private Hilfsmethode
private func mapUpdaterState(_ state: UpdaterState) -> UpdatePhase {
    switch state.stateType {
    case "ValetudoUpdaterIdleState":
        return .idle
    case "ValetudoUpdaterApprovalPendingState":
        return .updateAvailable
    case "ValetudoUpdaterDownloadingState":
        return .downloading
    case "ValetudoUpdaterApplyPendingState":
        return .readyToApply
    default:
        logger.warning("Unknown updater state: \(state.stateType, privacy: .public)")
        return .idle  // defensive fallback per CONTEXT.md
    }
}
```

### Pattern 5: Proxy-Delegation in RobotDetailViewModel (Phase 12 Scope)

**Was:** `RobotDetailViewModel` delegiert an `UpdateService`, behält aber bestehende Properties als Proxy-Wrapper. Echte Bereinigung erfolgt in Phase 13.

**Warum:** Vermeidet Breaking Changes an Views, die aktuell `viewModel.updaterState` etc. lesen.

**Beispiel:**
```swift
// RobotDetailViewModel: bestehende Properties als berechnete Proxies
var updaterState: UpdaterState? {
    // Wird in Phase 13 entfernt
    // Für Phase 12: nil oder abgeleitet aus updateService.phase
    nil
}

var updateInProgress: Bool {
    // Proxy auf updateService.phase
    switch updateService.phase {
    case .downloading, .applying, .rebooting: return true
    default: return false
    }
}
```

### Pattern 6: checkForUpdates() mit State-Transitions

**Was:** `checkForUpdates()` setzt `phase = .checking`, ruft API, mappt Ergebnis, setzt finalen State.

**Beispiel:**
```swift
func checkForUpdates() async {
    guard case .idle = phase else {
        logger.warning("checkForUpdates called while not idle")
        return
    }
    phase = .checking
    do {
        try await api.checkForUpdates()
        let state = try await api.getUpdaterState()
        phase = mapUpdaterState(state)
    } catch {
        phase = .error(error.localizedDescription)
    }
}
```

### Anti-Patterns to Avoid

- **Mehrere Bool-Flags parallel:** `isUpdating && !isDownloading` — Race Conditions, keine klaren Zustände. Stattdessen: Enum.
- **Guard mit separater Bool-Property:** `guard !isUpdating else { return }` — der Enum IS der Guard.
- **State direkt in View:** `@State private var updaterState: UpdaterState?` in `ValetudoInfoView` — kein geteilter State möglich. Stattdessen: UpdateService via `@EnvironmentObject` oder Init-Injection.
- **Stilles Fehler-Reset:** `updateInProgress = false` im catch ohne User-Feedback. Stattdessen: `phase = .error(...)`.
- **`@Published var phase` ohne `private(set)`:** Views könnten den State direkt setzen. Stattdessen: `@Published private(set) var phase`.

---

## Don't Hand-Roll

| Problem | Nicht selbst bauen | Stattdessen | Warum |
|---------|-------------------|-------------|-------|
| Thread-Safety für @Published | Eigenen Dispatch-Mechanismus | `@MainActor` auf der Klasse | @MainActor garantiert Main-Thread-Isolation automatisch |
| Observable State für SwiftUI | Notification-basiertes System | `ObservableObject` + `@Published` | Direktes SwiftUI-Binding, identisch mit RobotManager |
| Re-Entrancy-Schutz | `NSLock`, `DispatchSemaphore` | Swift Pattern-Matching Guard auf Enum | Kein zusätzlicher Locking-Overhead, by-design sicher |
| Async-Polling | Timer-basiertes Polling | `Task` + `Task.sleep` Loop (bereits in `startUpdate()` vorhanden) | Kooperatives Cancellation-Verhalten, kein Timer-Leak |

---

## Existing Code Analysis (Was tatsächlich existiert)

### RobotDetailViewModel — Aktueller Update-Zustand (Zeile 34-41)
```swift
@Published var currentVersion: String?
@Published var latestVersion: String?
@Published var updateUrl: String?
@Published var updaterState: UpdaterState?
@Published var isUpdating = false
@Published var showUpdateWarning = false
@Published var updateInProgress = false
```
**Problem:** 7 separate Properties für einen Zustand. `isUpdating` und `updateInProgress` sind semantisch unklar. Kein Re-Entrancy-Schutz.

### RobotDetailViewModel — startUpdate() (Zeile 450-490)
**Problem:** `updateInProgress = true` am Anfang — kein Guard. Zweiter simultaner Aufruf würde `updateInProgress` erneut auf `true` setzen und einen zweiten Download-Loop starten. Download-Polling-Loop hardcoded auf 60 Iterationen × 5 Sekunden = 5 Minuten Timeout. Im catch-Fall wird `updateInProgress = false` zurückgesetzt, aber kein Error-State gesetzt.

### ValetudoInfoView — Eigene Update-Logik (Zeile 773-973)
**Problem:** `@State private var updaterState: UpdaterState?` — völlig unabhängige Kopie. Wird in `loadInfo()` durch API-Call befüllt, unabhängig von `RobotDetailViewModel`. Kein gemeinsamer State mit dem ViewModel.

### RobotManager.checkUpdateForRobot() (Zeile 189-197)
**Scope:** Prüft nur `isUpdateAvailable` für die Roboter-Liste (Badge). Wird von Phase 12 nicht berührt. UpdateService koexistiert mit dieser separaten Prüfung.

---

## Common Pitfalls

### Pitfall 1: UpdateService Instanziierung und Lifetime
**Was schiefgeht:** UpdateService wird als `@StateObject` in einem View erstellt — wird zerstört wenn der View verschwindet. State geht verloren.
**Warum es passiert:** Naives "eine Instanz pro View" Pattern.
**Wie vermeiden:** UpdateService wird im `RobotDetailViewModel` gehalten (als Property). Das ViewModel verwaltet die Lifetime. Views binden an `viewModel.updateService.phase`.
**Warnsignal:** `@StateObject var updateService = UpdateService(...)` in einem View.

### Pitfall 2: `ValetudoInfoView` erhält keinen UpdateService
**Was schiefgeht:** `ValetudoInfoView` hat keinen Zugriff auf `UpdateService` — behält eigene `@State updaterState` Kopie. STATE-04 wäre nicht erfüllt.
**Warum es passiert:** `ValetudoInfoView` nimmt `RobotConfig` + `@EnvironmentObject var robotManager` als Parameter. Kein ViewModel-Zugriff.
**Wie vermeiden:** UpdateService als Parameter oder EnvironmentObject an `ValetudoInfoView` übergeben. Bestehende `loadInfo()` und `checkForUpdate()` Methoden löschen oder an UpdateService delegieren.
**Warnsignal:** `@State private var updaterState: UpdaterState?` bleibt in ValetudoInfoView nach Phase 12.

### Pitfall 3: Equatable-Konformanz bei `error(String)`
**Was schiefgeht:** `UpdatePhase: Equatable` synthesiert kein `==` für `case error(String)` wenn String nicht Equatable ist (ist er, aber) — größeres Problem: `error("msg1") != error("msg2")` kann Views in unerwartete Re-Render-Schleifen bringen wenn phase-Vergleiche für onChange/animation genutzt werden.
**Wie vermeiden:** Entweder `Equatable` nicht konformieren und nur Pattern-Matching nutzen, oder explizite `==` Implementierung. In Phase 12 reicht Pattern-Matching.

### Pitfall 4: `checkForUpdates` ohne Guard — doppelter Aufruf bei View-Erscheinen
**Was schiefgeht:** `ValetudoInfoView` ruft `loadInfo()` in `.task {}` auf. `RobotDetailViewModel` ruft `checkForUpdate()` beim Erscheinen auf. Beide setzen parallel `phase = .checking`.
**Wie vermeiden:** Guard: `guard case .idle = phase else { return }` am Anfang von `checkForUpdates()`. Nur einer der beiden kann durch.

### Pitfall 5: Polling-Task ohne Cancellation
**Was schiefgeht:** Download-Polling-Task läuft weiter wenn View verschwindet oder UpdateService deinitialisiert wird.
**Wie vermeiden:** `pollingTask?.cancel()` in `deinit` oder expliziter `stopPolling()` Methode. `Task.isCancelled` in der Polling-Loop prüfen (bereits im bestehenden `startStatsPolling()` Pattern vorhanden).

### Pitfall 6: Valetudo API Error vs. leerer State
**Was schiefgeht:** `getUpdaterState()` kann einen `ValetudoUpdaterIdleState` zurückgeben, obwohl das Update fehlgeschlagen ist (Valetudo resettet State nach Fehler). Kein expliziter Error-State in der API.
**Konsequenz:** State fällt nach Fehler auf `.idle` zurück statt `.error(...)`. Benutzer sieht keinen Fehlerhinweis.
**Wie vermeiden:** Wenn während `downloading` ein `getUpdaterState()` plötzlich `.idle` zurückgibt (statt `.readyToApply`), muss das als Fehler interpretiert werden. Polling-Loop muss diesen Fall erkennen und `phase = .error("Download interrupted")` setzen.

---

## Code Examples

### Vollständiges UpdateService Skeleton
```swift
// UpdateService.swift — neue Datei in Services/
import Foundation
import SwiftUI
import os

@MainActor
class UpdateService: ObservableObject {
    @Published private(set) var phase: UpdatePhase = .idle

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio",
        category: "UpdateService"
    )
    private let api: ValetudoAPI
    private var pollingTask: Task<Void, Never>?

    init(api: ValetudoAPI) {
        self.api = api
    }

    deinit {
        pollingTask?.cancel()
    }

    // STATE-01 + STATE-02: State-Machine-basierter Guard
    func checkForUpdates() async {
        guard case .idle = phase else { return }
        phase = .checking
        do {
            try await api.checkForUpdates()
            let state = try await api.getUpdaterState()
            phase = mapUpdaterState(state)
        } catch {
            // STATE-03: Expliziter Error-State statt stilles Reset
            phase = .error(error.localizedDescription)
        }
    }

    func startDownload() async {
        guard case .updateAvailable = phase else {
            logger.warning("startDownload: invalid state \(String(describing: self.phase), privacy: .public)")
            return
        }
        phase = .downloading
        do {
            try await api.downloadUpdate()
            await pollUntilReadyToApply()
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func startApply() async {
        guard case .readyToApply = phase else {
            logger.warning("startApply: invalid state \(String(describing: self.phase), privacy: .public)")
            return
        }
        phase = .applying
        do {
            try await api.applyUpdate()
            phase = .rebooting
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func reset() {
        pollingTask?.cancel()
        phase = .idle
    }

    // MARK: - Private

    private func pollUntilReadyToApply() async {
        pollingTask = Task {
            for _ in 0..<60 {  // max 5 Minuten
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                guard let state = try? await api.getUpdaterState() else { continue }
                let mapped = mapUpdaterState(state)
                phase = mapped
                if case .readyToApply = mapped { return }
                // Pitfall 6: Wenn State unerwartet idle wird → Fehler
                if case .idle = mapped {
                    phase = .error("Download wurde unterbrochen")
                    return
                }
            }
            phase = .error("Download-Timeout")
        }
        await pollingTask?.value
    }

    private func mapUpdaterState(_ state: UpdaterState) -> UpdatePhase {
        switch state.stateType {
        case "ValetudoUpdaterIdleState":         return .idle
        case "ValetudoUpdaterApprovalPendingState": return .updateAvailable
        case "ValetudoUpdaterDownloadingState":  return .downloading
        case "ValetudoUpdaterApplyPendingState": return .readyToApply
        default:
            logger.warning("Unknown updater state: \(state.stateType, privacy: .public)")
            return .idle
        }
    }
}
```

### UpdatePhase Enum
```swift
// In Models/ oder in UpdateService.swift
enum UpdatePhase {
    case idle
    case checking
    case updateAvailable
    case downloading
    case readyToApply
    case applying
    case rebooting
    case error(String)
}
```

### RobotDetailViewModel — Proxy-Delegation (Phase 12 Scope)
```swift
// In RobotDetailViewModel.swift
// NEUES Property:
private(set) var updateService: UpdateService?

// Initialisierung (nachdem api gesetzt wird):
func setupUpdateService() {
    guard let api = api else { return }
    updateService = UpdateService(api: api)
}

// BESTEHENDE Properties als Proxy für Phase-13-Kompatibilität:
var updateInProgress: Bool {
    guard let svc = updateService else { return false }
    switch svc.phase {
    case .downloading, .applying, .rebooting, .checking: return true
    default: return false
    }
}

// Delegation:
func startUpdate() async {
    guard let svc = updateService else { return }
    if case .updateAvailable = svc.phase {
        await svc.startDownload()
    } else if case .readyToApply = svc.phase {
        await svc.startApply()
    }
}

func checkForUpdate() async {
    await updateService?.checkForUpdates()
}
```

---

## State of the Art

| Alter Ansatz | Aktueller Ansatz | Geändert | Impact |
|-------------|-----------------|----------|--------|
| Multiple Bool-Flags für State | Enum-basierte State Machine | Swift 5.0+ / iOS 13+ | Kein "unmöglicher State" mehr möglich |
| `ObservableObject` + `DispatchQueue.main.async` | `@MainActor class` | Swift 5.5 / iOS 15 | Implizite Thread-Sicherheit |
| `@Published var` mit manuellen Guards | Pattern-Matching Guard auf Enum-State | Swift 5.0 | Kein separater Locking-Code nötig |

**Deprecated/outdated im aktuellen Code:**
- `updateInProgress: Bool`: Semantisch unklar (läuft gerade etwas? Fehler?) — wird in Phase 13 entfernt
- `isUpdating: Bool`: Redundant mit `updateInProgress` — wird in Phase 13 entfernt
- `showUpdateWarning: Bool`: Unklar was "Warning" bedeutet — wird in Phase 13 entfernt

---

## Open Questions

1. **Wo wird UpdateService instanziiert?**
   - Was wir wissen: `RobotDetailViewModel` wird per `init(robot:robotManager:)` erstellt. `api` wird nach Init gesetzt.
   - Was unklar ist: Wird `api` immer gesetzt bevor `checkForUpdate()` aufgerufen wird? Prüfen in `RobotDetailViewModel.init()`.
   - Empfehlung: UpdateService in `RobotDetailViewModel.init()` oder in `setAPI()` instanziieren, sobald api verfügbar.

2. **Wie erhält ValetudoInfoView Zugriff auf UpdateService?**
   - Was wir wissen: ValetudoInfoView nimmt `robot: RobotConfig` und `@EnvironmentObject var robotManager: RobotManager`. Kein ViewModel.
   - Was unklar ist: Soll UpdateService via `@EnvironmentObject` injiziert werden, oder als Init-Parameter?
   - Empfehlung: Als Init-Parameter (`let updateService: UpdateService`). EnvironmentObject für singletons (RobotManager), nicht für per-Roboter Services.

3. **Polling-Frequenz bei `getUpdaterState()`**
   - Was wir wissen: Bestehende Polling-Loop in `startUpdate()` ist 60 × 5s = 5 Minuten.
   - Was unklar ist: Ist 5 Sekunden ausreichend fein für UI-Feedback, oder zu frequent für Roboter-API?
   - Empfehlung: 5 Sekunden beibehalten (identisch zum bestehenden Code). In Phase 15 (UI-01 Download-Progress) ggf. auf 2s reduzieren.

---

## Environment Availability

Step 2.6: SKIPPED — Phase 12 ist eine reine Code-Refaktorierung. Keine externen Tools, Datenbanken oder CLIs erforderlich. Alle benötigten Frameworks (Foundation, SwiftUI, os) sind Teil des iOS SDK.

---

## Validation Architecture

`workflow.nyquist_validation` ist nicht in `.planning/config.json` gesetzt — wird als enabled behandelt.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Kein Test-Target in Phase 12 ersichtlich (kein pytest.ini/jest.config gefunden) |
| Config file | Prüfung: Kein separates Test-Target in Glob-Ergebnis sichtbar |
| Quick run command | Xcode: `xcodebuild test -scheme ValetudoApp -destination 'platform=iOS Simulator,name=iPhone 16'` |
| Full suite command | Identisch |

### Phase Requirements → Test Map
| Req ID | Verhalten | Test-Typ | Automatisierter Befehl | Datei vorhanden? |
|--------|-----------|----------|------------------------|-----------------|
| STATE-01 | UpdatePhase hat alle 8 Cases, Valetudo-States werden korrekt gemappt | Unit | `xcodebuild test -only-testing:ValetudoAppTests/UpdateServiceTests` | Wave 0 |
| STATE-02 | Zweiter `startDownload()`-Aufruf während `.downloading` hat keine Wirkung | Unit | identisch | Wave 0 |
| STATE-03 | API-Fehler setzt `phase = .error(...)` statt `.idle` | Unit | identisch | Wave 0 |
| STATE-04 | `RobotDetailViewModel` und `ValetudoInfoView` lesen denselben `phase`-Wert | Integration | Manuelle Verifikation + Code Review | Manuell |

### Wave 0 Gaps
- [ ] `ValetudoAppTests/UpdateServiceTests.swift` — covers STATE-01, STATE-02, STATE-03
- [ ] Mock `ValetudoAPI` für Tests (wenn kein Mock-Protokoll existiert)

*(STATE-04 ist ein Architektur-Constraint der per Code Review verifiziert wird, nicht durch automatisierten Test)*

---

## Sources

### Primary (HIGH confidence)
- Direkter Code-Audit: `RobotDetailViewModel.swift:34-41, 265-283, 448-490` — bestehende Update-Logik
- Direkter Code-Audit: `RobotSettingsSections.swift:773-973` — ValetudoInfoView
- Direkter Code-Audit: `RobotManager.swift:1-19` — ObservableObject-Pattern
- Direkter Code-Audit: `NotificationService.swift:6-11` — @MainActor class Pattern
- Direkter Code-Audit: `RobotState.swift:709-748` — UpdaterState, stateType, isUpdateAvailable etc.
- Direkter Code-Audit: `ValetudoAPI.swift:598-615` — 4 Update-Endpunkte
- CONTEXT.md — alle Locked Decisions

### Secondary (MEDIUM confidence)
- Swift Evolution / Swift Concurrency Docs: `@MainActor` class isoliert alle Methoden auf Main Thread
- SwiftUI ObservableObject binding: `@Published private(set)` ist etabliertes Pattern für read-only externe Sicht

---

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — direkt aus vorhandenem Code abgeleitet, kein neues Framework
- Architecture: HIGH — identisches Pattern in 3 bestehenden Services (RobotManager, NotificationService, SSEConnectionManager)
- Pitfalls: HIGH — direkt aus bestehenden Code-Problemen (startUpdate ohne Guard, ValetudoInfoView mit eigenem State) identifiziert
- Test-Infrastruktur: MEDIUM — kein Test-Target im Glob-Ergebnis gefunden, Wave 0 muss Existenz prüfen

**Research date:** 2026-04-01
**Valid until:** 2026-05-01 (stabile Swift/SwiftUI APIs, keine Ablaufrisiken)
