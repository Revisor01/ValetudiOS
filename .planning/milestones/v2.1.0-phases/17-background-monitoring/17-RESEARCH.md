# Phase 17: Background Monitoring - Research

**Researched:** 2026-04-01
**Domain:** iOS BackgroundTasks Framework (BGAppRefreshTask), UserNotifications, Swift Concurrency
**Confidence:** HIGH

## Summary

Phase 17 implementiert einen `BackgroundMonitorService`, der via `BGAppRefreshTask` periodisch den Valetudo-Roboter-Status prüft und bei Zustandswechseln (Reinigung abgeschlossen, Fehler, Stecken) lokale Notifications auslöst — auch wenn die App geschlossen ist. Die gesamte Infrastruktur (NotificationService, ValetudoAPI.getAttributes(), AppDelegate, RobotConfig-Persistenz) ist bereits vorhanden. Die Implementierung besteht im Kern aus drei Bausteinen: (1) Info.plist-Eintrag für den Task-Identifier, (2) BGTaskScheduler-Registrierung in AppDelegate, (3) neuer BackgroundMonitorService mit State-Persistenz via UserDefaults und Notification-Dispatch.

Der kritische Pitfall bei BGAppRefreshTask ist die zwingend erforderliche Doppelregistrierung: der Identifier muss sowohl im Info.plist (Key `BGTaskSchedulerPermittedIdentifiers`) als auch per `BGTaskScheduler.shared.register()` in `didFinishLaunchingWithOptions` eingetragen sein — fehlt einer der beiden, crasht die App oder der Task wird nie ausgeführt. Ebenso kritisch: `task.setTaskCompleted(success:)` MUSS in jedem Codepfad (inkl. Fehlerfall und Expiration Handler) aufgerufen werden, sonst sperrt iOS zukünftige Ausführungen.

**Primary recommendation:** BackgroundMonitorService als eigenständige Klasse implementieren, der ValetudoAPI direkt nutzt (keine Abhängigkeit zu RobotManager) und den Zustand pro Roboter-ID in UserDefaults serialisiert. BGTask-Registrierung und -Scheduling in AppDelegate.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- BGAppRefreshTask (nicht BGProcessingTask) — kurze Prüfung (~30s), kein schwerer Processing nötig
- System-managed Intervall (ca. 15-30 Minuten, iOS entscheidet) — kein fester Intervall konfigurierbar
- Nur getAttributes() im Hintergrund — ein einzelner leichtgewichtiger API-Call pro Roboter
- Ein BGTask für alle konfigurierten Roboter — iteriert über robotConfigs
- Notification-Typen sind bereits einzeln steuerbar (5 Optionen in NotificationService) — bestehende Logik beibehalten
- "Reinigung abgeschlossen" wird über Status-Vergleich erkannt: vorheriger State in UserDefaults gespeichert, neuer State verglichen (analog zu RobotManager.checkForStateChanges())
- Kein separater Toggle für Hintergrundüberwachung — immer aktiv sobald Notifications erlaubt
- Standard-Sound + Badge-Zähler — iOS-Defaults nutzen
- Letzter bekannter Status in UserDefaults gespeichert — ein Snapshot pro Roboter (einfach, ausreichend)
- BGTask-Registrierung in AppDelegate.didFinishLaunchingWithOptions — Standard-Approach
- Neuer BackgroundMonitorService — klare Trennung von RobotManager (Foreground-only)
- NotificationService.requestAuthorization() existiert bereits — direkt nutzen

### Claude's Discretion
(nicht explizit aus CONTEXT.md, implizit): Konkrete UserDefaults-Key-Benennung, internes Async-Pattern im BGTask-Handler, Rescheduling-Strategie.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BG-01 | BGAppRefreshTask prüft periodisch den Roboter-Status im Hintergrund | BGTaskScheduler.register() + submit() — vollständig dokumentiert, straightforward |
| BG-02 | Lokale Notification bei Reinigungsende auch wenn die App geschlossen ist | checkStateChanges()-Logik aus RobotManager portieren + UserDefaults-Snapshot |
| BG-03 | Lokale Notification bei Fehlern (Roboter steckt fest, Staubbehälter voll) auch im Hintergrund | identisch zu BG-02, gleiche State-Vergleichslogik für error/stuck |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| BackgroundTasks (Apple) | iOS 13+ | BGAppRefreshTask Registration & Scheduling | Offizielle Apple-API, keine Alternative |
| UserNotifications (Apple) | iOS 10+ | Lokale Notifications auslösen | Bereits in NotificationService integriert |
| Foundation.UserDefaults | iOS 2+ | Status-Persistenz zwischen BGTask-Läufen | Einfachste persistente KV-Storage für kleine Datenmengen |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| os.Logger | iOS 14+ | Strukturiertes Logging im BGTask-Handler | Konsistent mit allen anderen Services im Projekt |

**Installation:** Keine externen Pakete. Alle Frameworks sind Teil des iOS SDK.

**Import-Statement für BackgroundTasks:**
```swift
import BackgroundTasks
```

## Architecture Patterns

### Recommended Project Structure
```
ValetudoApp/Services/
├── BackgroundMonitorService.swift   # Neu: BGTask-Handler, State-Persistenz, Notification-Dispatch
├── NotificationService.swift        # Bestehend: unverändert
├── RobotManager.swift               # Bestehend: unverändert (Foreground-only bleibt)
└── ValetudoAPI.swift                # Bestehend: getAttributes() direkt nutzen
ValetudoApp/ValetudoApp.swift        # AppDelegate: BGTask-Registrierung + Scheduling hinzufügen
ValetudoApp/Info.plist               # BGTaskSchedulerPermittedIdentifiers hinzufügen
```

### Pattern 1: BGTask-Registrierung in AppDelegate
**Was:** BGTaskScheduler.shared.register() MUSS in didFinishLaunchingWithOptions aufgerufen werden — nicht später.
**Wann:** Immer, da iOS die Handler-Registrierung beim App-Start erwartet.

```swift
// Source: Apple BackgroundTasks Documentation + uynguyen.github.io
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static let backgroundRefreshTaskIdentifier = "de.simonluthe.ValetudoApp.backgroundRefresh"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // CRITICAL: Must register before app finishes launching
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundRefreshTaskIdentifier,
            using: nil
        ) { task in
            BackgroundMonitorService.shared.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }

        return true
    }
}
```

### Pattern 2: BGTask-Scheduling (Reschedule-Pattern)
**Was:** Task wird beim App-Hintergrundwechsel initial eingeplant. Nach jeder Ausführung wird er SOFORT neu eingeplant (vor der eigentlichen Arbeit), damit der nächste Zyklus garantiert registriert ist — auch wenn der aktuelle Task vorzeitig abbricht.
**Wann:** In sceneDidEnterBackground / applicationDidEnterBackground und am Anfang jedes Task-Handlers.

```swift
// Source: codepushgo.com/blog/ios-background-task + uynguyen.github.io
func scheduleBackgroundRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: AppDelegate.backgroundRefreshTaskIdentifier)
    // earliestBeginDate = Mindestwartezeit, nicht garantiertes Timing
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    do {
        try BGTaskScheduler.shared.submit(request)
    } catch {
        logger.error("Could not schedule background refresh: \(error.localizedDescription, privacy: .public)")
    }
}
```

### Pattern 3: BGTask-Handler mit Expiration und Swift Concurrency
**Was:** Der Handler muss (a) sofort reschedulen, (b) ein Expiration-Handler registrieren, (c) task.setTaskCompleted(success:) in ALLEN Pfaden aufrufen.
**Wann:** Immer im BGTask-Handler.

```swift
// Source: codepushgo.com/blog/ios-background-task
func handleBackgroundRefresh(task: BGAppRefreshTask) {
    // 1. Sofort reschedulen (garantiert nächsten Zyklus)
    scheduleBackgroundRefresh()

    // 2. Swift Task für async Arbeit
    let workTask = Task {
        await checkAllRobots()
    }

    // 3. Expiration Handler — iOS kann den Task jederzeit abbrechen
    task.expirationHandler = {
        workTask.cancel()
        task.setTaskCompleted(success: false)
    }

    // 4. Nach Abschluss der Arbeit completionHandler aufrufen
    Task {
        await workTask.value
        task.setTaskCompleted(success: true)
    }
}
```

### Pattern 4: Status-Persistenz in UserDefaults
**Was:** Letzter Status pro Roboter-ID als codiertes Struct in UserDefaults. Gleiche Logik wie RobotManager.checkStateChanges(), aber mit persistiertem Previous-State.

```swift
// Schlüssel-Schema: "bg_last_status_<UUID-String>"
private func userDefaultsKey(for robotId: UUID) -> String {
    "bg_last_status_\(robotId.uuidString)"
}

struct PersistedRobotStatus: Codable {
    let statusValue: String?    // z.B. "cleaning", "docked", "idle", "error"
    let statusFlag: String?     // z.B. "stuck"
    let timestamp: Date
}

func loadPersistedStatus(for robotId: UUID) -> PersistedRobotStatus? {
    guard let data = UserDefaults.standard.data(forKey: userDefaultsKey(for: robotId)),
          let decoded = try? JSONDecoder().decode(PersistedRobotStatus.self, from: data)
    else { return nil }
    return decoded
}

func saveStatus(_ status: PersistedRobotStatus, for robotId: UUID) {
    if let data = try? JSONEncoder().encode(status) {
        UserDefaults.standard.set(data, forKey: userDefaultsKey(for: robotId))
    }
}
```

### Pattern 5: ValetudoAPI im Hintergrund instanziieren
**Was:** BackgroundMonitorService kann nicht auf RobotManager (MainActor) zugreifen. Er liest robotConfigs direkt aus UserDefaults und instantiiert ValetudoAPI selbst.
**Wann:** Im BGTask-Handler — RobotManager ist ein @MainActor ObservableObject und nicht aus Background-Contexts verfügbar.

```swift
// RobotConfig aus UserDefaults laden (gleicher Key wie RobotManager: "valetudo_robots")
private func loadRobotConfigs() -> [RobotConfig] {
    guard let data = UserDefaults.standard.data(forKey: "valetudo_robots"),
          let configs = try? JSONDecoder().decode([RobotConfig].self, from: data)
    else { return [] }
    return configs
}
```

### Anti-Patterns to Avoid
- **BGTask-Handler registrieren nach didFinishLaunchingWithOptions:** Crash mit "No launch handler registered for task". Registrierung MUSS in didFinishLaunchingWithOptions erfolgen.
- **task.setTaskCompleted() vergessen:** iOS sperrt zukünftige Ausführungen dauerhaft. Jeder Codepfad (inkl. catch-Blöcke) muss completion aufrufen.
- **BGTask ohne Expiration Handler:** Wenn iOS den Task abbricht und kein expiration handler gesetzt ist, wird der Task-Slot blockiert.
- **Zugriff auf RobotManager aus dem BGTask-Handler:** RobotManager ist @MainActor — direkter Zugriff aus dem BGTask-Thread ist thread-unsafe. BackgroundMonitorService liest Configs direkt aus UserDefaults.
- **BGProcessingTask statt BGAppRefreshTask:** BGProcessingTask erwartet Long-Running-Work und setzt Gerät am Ladekabel voraus. Für leichtgewichtigen Status-Check ist BGAppRefreshTask korrekt.
- **Identifier nicht in Info.plist eintragen:** Runtime-Crash beim ersten BGTask-submit().

## Don't Hand-Roll

| Problem | Nicht bauen | Stattdessen nutzen | Warum |
|---------|-------------|-------------------|-------|
| Hintergrundausführungs-Scheduling | Custom Timer / URLSession Hintergrundtask | BGAppRefreshTask | iOS enforced, kein Custom-Workaround möglich |
| Notification-Versand | Eigene Notification-Logik | NotificationService.shared (bereits vollständig) | Alle 5 Notification-Typen + Actions + Prefs bereits implementiert |
| API-Calls | Eigener HTTP-Stack | ValetudoAPI.getAttributes() (bereits vollständig) | Auth, SSL, Timeout bereits konfiguriert |
| Status-State-Vergleich | Eigene Vergleichslogik | Analog zu RobotManager.checkStateChanges() portieren | Bewährte Logik, identische Bedingungen |
| RobotConfig-Laden | Eigene Persistenz | UserDefaults.standard.data(forKey: "valetudo_robots") | RobotManager nutzt bereits diesen Key |

## Common Pitfalls

### Pitfall 1: Fehlende BGTaskSchedulerPermittedIdentifiers in Info.plist
**Was schiefläuft:** App crasht beim ersten submit() mit "Task identifier not found in plist".
**Warum:** Apple validiert den Identifier gegen die plist-Allowlist zur Laufzeit.
**Vermeidung:** Info.plist MUSS `BGTaskSchedulerPermittedIdentifiers` Array mit dem exakten Task-Identifier enthalten, bevor die App submitted wird.
**Warnsignal:** Launch-Crash mit "Failed to submit task" oder "not permitted".

### Pitfall 2: task.setTaskCompleted() wird nicht in allen Pfaden aufgerufen
**Was schiefläuft:** iOS sperrt zukünftige BGTask-Ausführungen. Der Task läuft nie wieder.
**Warum:** iOS interpretiert fehlende completion als Fehler und reduziert BGTask-Priorität dauerhaft.
**Vermeidung:** Expiration Handler registrieren, der task.setTaskCompleted(success: false) aufruft. try/catch-Blöcke ebenfalls absichern.
**Warnsignal:** BGTask wird nach dem ersten Lauf nie wieder ausgeführt.

### Pitfall 3: Registrierung nicht in didFinishLaunchingWithOptions
**Was schiefläuft:** Crash mit "No launch handler registered for task with identifier".
**Warum:** iOS startet die App bei BGTask-Ausführung direkt in didFinishLaunchingWithOptions. Der Handler muss zu diesem Zeitpunkt bereits registriert sein.
**Vermeidung:** BGTaskScheduler.shared.register() als erstes in didFinishLaunchingWithOptions aufrufen.
**Warnsignal:** Crash im BGTask-Kontext, der im Foreground nicht reproduzierbar ist.

### Pitfall 4: Kein Reschedule im Handler
**Was schiefläuft:** BGTask läuft genau einmal, dann nie wieder.
**Warum:** BGTask wird nicht automatisch wiederholt. Der Handler muss den nächsten Request explizit einreichen.
**Vermeidung:** Als erste Aktion im Handler scheduleBackgroundRefresh() aufrufen (vor der eigentlichen Arbeit).
**Warnsignal:** Notifications kommen nur beim ersten Hintergrundwechsel nach App-Install.

### Pitfall 5: NotificationService ist @MainActor — Thread-Safety im BGTask-Handler
**Was schiefläuft:** Compiler-Fehler oder Laufzeit-Warnings wegen @MainActor-Isolation.
**Warum:** NotificationService ist mit `@MainActor class` deklariert. BGTask-Handler läuft auf beliebigem Thread.
**Vermeidung:** Notification-Calls via `Task { @MainActor in ... }` wrappen oder BackgroundMonitorService mit `nonisolated`-Methoden für den BGTask-Kontext.
**Warnsignal:** Xcode-Warning "Call to main actor-isolated ... in a synchronous nonisolated context".

### Pitfall 6: RobotConfig.password ist nil (Keychain-basiert)
**Was schiefläuft:** API-Calls ohne Authentication schlagen mit 401 fehl, obwohl der User ein Passwort konfiguriert hat.
**Warum:** RobotConfig speichert kein Klartext-Passwort (privacy: Keychain). ValetudoAPI liest intern aus KeychainStore.
**Vermeidung:** ValetudoAPI direkt mit RobotConfig instanziieren — KeychainStore-Zugriff erfolgt intern in ValetudoAPI.request(). RobotConfig.password muss NICHT gesetzt sein.
**Warnsignal:** HTTP 401 in BGTask-Logs, obwohl Foreground-Calls funktionieren.

### Pitfall 7: UIBackgroundModes vs. BGTaskSchedulerPermittedIdentifiers
**Was schiefläuft:** Verwirrung über welcher plist-Key welchen Zweck hat.
**Warum:** `UIBackgroundModes` mit `fetch` ist die ALTE Background-Fetch-API (iOS < 13). BGAppRefreshTask verwendet NUR `BGTaskSchedulerPermittedIdentifiers` — UIBackgroundModes fetch ist für BGAppRefreshTask NICHT erforderlich und kann weggelassen werden.
**Vermeidung:** Nur `BGTaskSchedulerPermittedIdentifiers` eintragen. KEIN `UIBackgroundModes` mit `fetch` nötig.

## Code Examples

### Info.plist Eintrag
```xml
<!-- Source: Apple BackgroundTasks Documentation -->
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>de.simonluthe.ValetudoApp.backgroundRefresh</string>
</array>
```

### Komplettes AppDelegate-Snippet nach Phase 17
```swift
// Source: Apple BackgroundTasks + uynguyen.github.io pattern
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static let backgroundRefreshTaskIdentifier = "de.simonluthe.ValetudoApp.backgroundRefresh"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundRefreshTaskIdentifier,
            using: nil
        ) { task in
            BackgroundMonitorService.shared.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        BackgroundMonitorService.shared.scheduleBackgroundRefresh()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        Task { @MainActor in
            await NotificationService.shared.handleNotificationResponse(actionIdentifier: actionIdentifier)
        }
        completionHandler()
    }
}
```

### BackgroundMonitorService Skeleton
```swift
// Source: codepushgo.com + uynguyen.github.io Patterns
import BackgroundTasks
import Foundation
import os

final class BackgroundMonitorService {
    static let shared = BackgroundMonitorService()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "BackgroundMonitor")
    private let robotConfigsKey = "valetudo_robots"

    private init() {}

    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(
            identifier: AppDelegate.backgroundRefreshTaskIdentifier
        )
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Background refresh scheduled")
        } catch {
            logger.error("Failed to schedule: \(error.localizedDescription, privacy: .public)")
        }
    }

    func handleBackgroundRefresh(task: BGAppRefreshTask) {
        // 1. Sofort reschedulen
        scheduleBackgroundRefresh()

        // 2. Async Arbeit
        let workTask = Task {
            await checkAllRobots()
        }

        // 3. Expiration Handler
        task.expirationHandler = {
            workTask.cancel()
            task.setTaskCompleted(success: false)
        }

        // 4. Completion
        Task {
            _ = await workTask.result
            task.setTaskCompleted(success: true)
        }
    }

    private func checkAllRobots() async {
        let configs = loadRobotConfigs()
        for config in configs {
            guard !Task.isCancelled else { break }
            await checkRobot(config: config)
        }
    }

    private func checkRobot(config: RobotConfig) async {
        let api = ValetudoAPI(config: config)
        do {
            let attributes = try await api.getAttributes()
            let newStatus = PersistedRobotStatus(attributes: attributes)
            let previous = loadPersistedStatus(for: config.id)
            checkStateChanges(robotName: config.name, previous: previous, current: newStatus)
            saveStatus(newStatus, for: config.id)
        } catch {
            logger.warning("Background check failed for \(config.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func checkStateChanges(robotName: String, previous: PersistedRobotStatus?, current: PersistedRobotStatus) {
        guard let prevStatus = previous?.statusValue else { return }
        let currentStatus = current.statusValue ?? ""

        if prevStatus == "cleaning" && (currentStatus == "docked" || currentStatus == "idle") {
            Task { @MainActor in
                NotificationService.shared.notifyCleaningComplete(robotName: robotName, area: nil)
            }
        }
        if current.statusFlag == "stuck" && previous?.statusFlag != "stuck" {
            Task { @MainActor in
                NotificationService.shared.notifyRobotStuck(robotName: robotName)
            }
        }
        if currentStatus == "error" && prevStatus != "error" {
            let errorMsg = current.statusFlag ?? "Error"
            Task { @MainActor in
                NotificationService.shared.notifyRobotError(robotName: robotName, error: errorMsg)
            }
        }
    }

    // MARK: - Persistence
    private struct PersistedRobotStatus: Codable {
        let statusValue: String?
        let statusFlag: String?
        let timestamp: Date

        init(attributes: [RobotAttribute]) {
            statusValue = attributes.first { $0.__class == "StatusStateAttribute" }?.value
            statusFlag = attributes.first { $0.__class == "StatusStateAttribute" }?.flag
            timestamp = Date()
        }
    }

    private func userDefaultsKey(for robotId: UUID) -> String {
        "bg_last_status_\(robotId.uuidString)"
    }

    private func loadRobotConfigs() -> [RobotConfig] {
        guard let data = UserDefaults.standard.data(forKey: robotConfigsKey),
              let configs = try? JSONDecoder().decode([RobotConfig].self, from: data)
        else { return [] }
        return configs
    }

    private func loadPersistedStatus(for robotId: UUID) -> PersistedRobotStatus? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey(for: robotId)),
              let decoded = try? JSONDecoder().decode(PersistedRobotStatus.self, from: data)
        else { return nil }
        return decoded
    }

    private func saveStatus(_ status: PersistedRobotStatus, for robotId: UUID) {
        if let data = try? JSONEncoder().encode(status) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey(for: robotId))
        }
    }
}
```

### Xcode BGTask-Debugging (LLDB-Trick)
```
// Source: codepushgo.com — BGTask testen ohne 15 Min. warten
// 1. App auf Gerät starten und in Hintergrund schieben
// 2. In Xcode: Debugger pausieren (Pause-Button)
// 3. In LLDB Console eingeben:
e -l swift -- BGTaskScheduler.shared.submit(BGAppRefreshTaskRequest(identifier: "de.simonluthe.ValetudoApp.backgroundRefresh"))
// 4. Debugger fortsetzen → Handler feuert sofort
```

## State of the Art

| Alte Methode | Aktuelle Methode | Geändert | Impact |
|--------------|-----------------|----------|--------|
| UIBackgroundModes "fetch" + application(_:performFetchWithCompletionHandler:) | BGAppRefreshTask (BackgroundTasks Framework) | iOS 13 (2019) | Neues Framework, alte Methode deprecated aber noch funktional |
| BGProcessingTask für alle Hintergrundaufgaben | BGAppRefreshTask (kurz) + BGProcessingTask (lang) | iOS 13 | Klare Trennung nach Arbeitsdauer |

**Deprecated/veraltet:**
- `application(_:performFetchWithCompletionHandler:)`: Funktioniert noch, aber die BackgroundTasks-API ist der empfohlene Weg seit iOS 13.
- `UIBackgroundModes` mit `fetch`-Wert ist für den alten API-Pfad — für BGAppRefreshTask wird dieser Key **nicht** benötigt.

## Open Questions

1. **Scheduling bei Onboarding-Abschluss**
   - Was wir wissen: scheduleBackgroundRefresh() wird in applicationDidEnterBackground aufgerufen
   - Was unklar ist: Wenn ein frischer Nutzer die App noch nie in den Hintergrund geschickt hat, ist kein Task geplant
   - Empfehlung: scheduleBackgroundRefresh() auch in didFinishLaunchingWithOptions aufrufen (idempotent, kein Problem wenn Task bereits existiert)

2. **ValetudoAPI ist ein `actor` — Instanziierung im BGTask-Kontext**
   - Was wir wissen: ValetudoAPI ist als `actor` deklariert, was Thread-Isolation garantiert
   - Was zu beachten: `await api.getAttributes()` ist nötig (nicht einfach synchron aufrufen)
   - Empfehlung: Bereits im Skeleton-Code mit `await` berücksichtigt — kein Problem

3. **App Group UserDefaults für BGTask-Isolation?**
   - Was wir wissen: Standard UserDefaults.standard funktioniert im BGTask-Kontext
   - Was unklar ist: Ob App Groups nötig wären (nein — App Groups sind nur für Widgets/Extensions nötig)
   - Empfehlung: UserDefaults.standard verwenden, keine App Group nötig

## Environment Availability

Step 2.6: SKIPPED (keine externen Dependencies — reine iOS SDK API-Nutzung, kein externes Tooling erforderlich)

## Validation Architecture

nyquist_validation ist in .planning/config.json explizit auf `false` gesetzt. Dieser Abschnitt wird ausgelassen.

## Sources

### Primary (HIGH confidence)
- Apple BackgroundTasks Framework Documentation (BGAppRefreshTask) — Registration requirements, API constraints, Info.plist keys
- ValetudoApp source code (NotificationService.swift, RobotManager.swift, ValetudoApp.swift, ValetudoAPI.swift) — Existing patterns, actor declarations, UserDefaults keys

### Secondary (MEDIUM confidence)
- uynguyen.github.io/2020/09/26 — BGAppRefreshTask best practices, critical completion handler requirement, reschedule-pattern
- codepushgo.com/blog/ios-background-task — Handler-Implementierung mit Expiration, LLDB-Debugging-Trick
- swiftwithmajid.com/2022/07/06 — SwiftUI-Perspektive auf BGAppRefreshTask, Swift Concurrency Integration

### Tertiary (LOW confidence)
- Keine

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — Apple-eigene Frameworks, keine Third-Party-Dependencies
- Architecture: HIGH — Patterns direkt aus bestehendem Projektcode abgeleitet + verifizierte Apple-Dokumentation
- Pitfalls: HIGH — Mehrfach durch unabhängige Quellen bestätigt (Apple Docs + Community-Artikel)

**Research date:** 2026-04-01
**Valid until:** 2027-04-01 (BackgroundTasks API ist stabil seit iOS 13, keine Breaking Changes erwartet)
