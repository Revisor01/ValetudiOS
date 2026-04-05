# Phase 29: UX Robustness - Research

**Researched:** 2026-04-04
**Domain:** SwiftUI iOS 17+ — ErrorRouter-Verdrahtung, Confirmation Dialogs, Multi-Robot Polling
**Confidence:** HIGH (alle Befunde direkt aus Quellcode verifiziert)

---

## Summary

Phase 29 zielt auf drei unabhängige Robustheitslücken: lückenhafte Fehlerweitergabe an den `ErrorRouter`, fehlende Bestätigungsdialoge vor destruktiven Aktionen, und gleichzeitiges Polling aller Roboter unabhängig davon, welcher aktuell sichtbar ist.

Die Codebase-Analyse zeigt: `ErrorRouter` ist bereits in `RobotDetailView`, `RobotSettingsView` und `MapContentView` injiziert und in den jeweiligen ViewModels hinterlegt. Jedoch nutzen nur wenige Aktionen ihn tatsächlich — die Mehrheit der `catch`-Blöcke loggt lediglich und bleibt stumm. Bei destruktiven Aktionen existiert schon ein Muster (`confirmationDialog` in `ConsumablesView` für Reset, `.alert` in `RobotSettingsView` für Map-Reset und Mapping-Pass). Dieses Muster muss auf die fehlenden Fälle ausgeweitet werden. Das Polling-Problem ist strukturell: `RobotManager.startRefreshing()` pollt alle Roboter in einer Endlosschleife — es gibt keinerlei Konzept eines "aktiven Roboters".

**Primäre Empfehlung:** Für ROBUST-01 `errorRouter?.show(error)` in alle stummen `catch`-Blöcke der user-initiierten Aktionen einbauen. Für ROBUST-02 das bestehende `confirmationDialog`/`alert`-Muster auf Delete Timer, Restore Snapshot und Remove Robot erweitern. Für ROBUST-03 einen `activeRobotId`-Mechanismus in `RobotManager` einführen, der das SSE/Polling auf den aktiven Roboter beschränkt.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ROBUST-01 | ErrorRouter ist in RobotDetailView und MapContentView für alle benutzer-initiierten Aktionen verdrahtet | ErrorRouter ist injiziert, aber ~12 catch-Blöcke in RobotDetailViewModel und MapViewModel zeigen den Fehler nicht an |
| ROBUST-02 | Destructive Actions (Reset Consumable, Delete Timer, Restore Snapshot, Remove Robot) haben Confirmation-Dialogs | ConsumablesView hat bereits Dialog; TimersView, RobotSettingsView (Snapshot), SettingsView (Remove Robot) fehlen |
| ROBUST-03 | Multi-Robot-Polling ist optimiert — nur der aktive/sichtbare Roboter pollt die Map | RobotManager pollt alle Roboter gleichzeitig, kein activeRobotId-Konzept vorhanden |
</phase_requirements>

---

## ROBUST-01: ErrorRouter-Verdrahtung — Ist-Zustand

### Injektions-Infrastruktur (vorhanden)

`ErrorRouter` ist als `@Observable` Singleton in `ValetudoApp.swift` erstellt und via `.environment(errorRouter)` + `.withErrorAlert(router: errorRouter)` in den gesamten View-Baum eingehängt. Die View-Extension `withErrorAlert` zeigt ein `.alert` mit Retry-Option.

**Views die ErrorRouter aktiv empfangen:**
- `RobotDetailView` — `@Environment(ErrorRouter.self) var errorRouter`, weiterleitung in `.task` via `viewModel.errorRouter = errorRouter`
- `RobotSettingsView` — gleich, `viewModel.errorRouter = errorRouter` in `.task`
- `MapContentView` — gleich, `viewModel.errorRouter = errorRouter` in `.task`

### Aktionen die ErrorRouter bereits nutzen

| ViewModel | Funktion | Wird angezeigt |
|-----------|----------|----------------|
| `RobotDetailViewModel` | `locate()` | Ja — `errorRouter?.show(error)` |
| `MapViewModel` | `joinRooms()` — Map-Reload-Fehler | Ja — `errorRouter?.show(error)` |
| `MapViewModel` | `joinRooms()` — Segments-Reload-Fehler | Ja |
| `MapViewModel` | `splitRoom()` — Map-Reload-Fehler | Ja |
| `MapViewModel` | `splitRoom()` — Segments-Reload-Fehler | Ja |
| `RobotSettingsViewModel` | `setVoicePack()` | Ja |

### Aktionen die ErrorRouter NICHT nutzen (LÜCKEN)

**RobotDetailViewModel** — user-initiiert, Fehler wird nur geloggt:

| Funktion | Aktion | Aktuelles Verhalten |
|----------|--------|---------------------|
| `performAction(_:)` | Start / Stop / Pause / Home | `logger.error(...)` — kein errorRouter |
| `cleanSelectedRooms()` | Raumreinigung starten | `logger.error(...)` — kein errorRouter |
| `setFanSpeed(_:)` | Lüftergeschwindigkeit setzen | `logger.error(...)` — kein errorRouter |
| `setWaterUsage(_:)` | Wasserverbrauch setzen | `logger.error(...)` — kein errorRouter |
| `setOperationMode(_:)` | Betriebsmodus setzen | `logger.error(...)` — kein errorRouter |
| `triggerAutoEmpty()` | Dock leeren | `logger.error(...)` — kein errorRouter |
| `triggerMopDockClean()` | Mop-Dock reinigen | `logger.error(...)` — kein errorRouter |
| `triggerMopDockDry()` | Mop-Dock trocknen | `logger.error(...)` — kein errorRouter |
| `resetConsumable(_:)` | Verbrauchsmaterial zurücksetzen | `logger.error(...)` — kein errorRouter |
| `dismissEvent(_:)` | Ereignis verwerfen | `logger.error(...)` — kein errorRouter |
| `setCleanRoute(_:)` | Reinigungsroute setzen | `logger.error(...)` — kein errorRouter |

**MapViewModel** — user-initiiert, Fehler wird nur geloggt:

| Funktion | Aktion | Aktuelles Verhalten |
|----------|--------|---------------------|
| `cleanZones()` | Zonen reinigen | `logger.error(...)` — kein errorRouter |
| `goToPoint(x:y:)` | Zu Punkt fahren | `logger.error(...)` — kein errorRouter |
| `renameRoom(id:name:)` | Raum umbenennen | `logger.error(...)` — kein errorRouter |
| `saveRestrictions()` | Restriktionen speichern | `logger.error(...)` — kein errorRouter |
| `confirmEditMode(...)` — zone | Zonenreinigung bestätigen | `logger.error(...)` — kein errorRouter |
| `confirmEditMode(...)` — deleteRestriction | Restriktion löschen | `logger.error(...)` — kein errorRouter |

**Wichtige Ausnahme:** `loadData()`-Methoden (Background-Ladeoperationen) SOLLEN keinen errorRouter nutzen — stumme Fehler beim initialen Laden sind akzeptabel (Capabilities, Segments etc.). Nur user-initiierte Aktionen (Buttons, die etwas verändern) brauchen Fehlermeldungen.

---

## ROBUST-02: Destruktive Aktionen — Ist-Zustand

### Bereits vorhandene Bestätigungsdialoge

| Aktion | View | Dialog-Typ | Status |
|--------|------|------------|--------|
| Reset Consumable | `ConsumablesView` | `.confirmationDialog` | Vollständig implementiert |
| Start Mapping Pass | `RobotSettingsView` | `.alert` (role: .destructive button) | Vollständig implementiert |
| Map Reset | `RobotSettingsView` | `.alert` (role: .destructive button) | Vollständig implementiert |
| Firmware Update starten | `RobotDetailView` | `.alert` (role: .destructive button) | Vollständig implementiert |

### Fehlende Bestätigungsdialoge (LÜCKEN)

**Delete Timer — `TimersView`:**
- Aktuell: `.onDelete(perform: deleteTimers)` — Wisch-zum-Löschen ohne Bestätigung
- `deleteTimers(at:)` ruft direkt `api.deleteTimer(id:)` auf
- Kein `showDeleteConfirm`-State, kein Dialog

**Restore Snapshot — `RobotSettingsView`:**
- Aktuell: `Button { Task { await viewModel.restoreMapSnapshot(snapshot) } }` — sofortiger API-Call
- Kein Bestätigungsdialog trotz irreversibler Kartenänderung
- `isRestoringSnapshot` zeigt nur einen Ladeindikator, kein Modal

**Remove Robot — `SettingsView` (EditRobotView):**
- Aktuell: `Button(role: .destructive) { robotManager.removeRobot(robot.id); dismiss() }` — sofortige Ausführung
- Keine Bestätigung vor dem vollständigen Löschen inkl. Keychain-Daten

**Remove Robot — `RobotListView`:**
- Aktuell: `.onDelete(perform: deleteRobots)` — Wisch-zum-Löschen ohne Bestätigung
- Gleiche Auswirkung wie oben (ruft `robotManager.removeRobot(...)` direkt auf)

### Empfohlenes Pattern (aus bestehendem Code)

```swift
// confirmationDialog — für Wisch-Aktionen (TimersView-Muster):
.confirmationDialog(
    "timer.delete_title",
    isPresented: $showDeleteConfirm,
    titleVisibility: .visible
) {
    Button("timer.delete_confirm", role: .destructive) {
        if let timer = timerToDelete {
            Task { await deleteTimer(timer) }
        }
    }
    Button("settings.cancel", role: .cancel) {}
}

// .alert — für Button-ausgelöste Aktionen (RobotSettingsView-Muster):
.alert("snapshots.restore_warning_title", isPresented: $showRestoreConfirm) {
    Button("settings.cancel", role: .cancel) {}
    Button("snapshots.restore_confirm", role: .destructive) {
        Task { await viewModel.restoreMapSnapshot(snapshotToRestore!) }
    }
} message: {
    Text("snapshots.restore_warning_message")
}
```

**Wichtige Feinheit bei Timer-Delete:** `.onDelete` liefert `IndexSet` — der Dialog braucht einen `@State var timerToDelete: ValetudoTimer?` und einen zweistufigen Flow: zuerst den zu löschenden Timer merken, dann den Dialog zeigen, dann erst API-Call.

---

## ROBUST-03: Polling-Mechanismus — Ist-Zustand

### Wie RobotManager pollt

`RobotManager.startRefreshing()` (Zeilen 134–175) startet einen einzigen `refreshTask: Task` der für **alle** Roboter gleichzeitig:

1. SSE-Verbindungen für alle Roboter aufbaut (`sseManager.connect(...)`)
2. HTTP-Polling als Fallback für alle Roboter ohne aktive SSE startet

Der Loop läuft mit `while !Task.isCancelled` und einem `Task.sleep(for: .seconds(5))`-Intervall. Er wird einmalig im `init()` gestartet und nur in `deinit` gestoppt.

**Konsequenz bei 3 Robotern:** 3 parallele SSE-Verbindungen + 3 parallele HTTP-Polls alle 5 Sekunden, unabhängig davon ob der Nutzer gerade irgendeinen davon ansieht.

### Map-Polling in MapViewModel

`MapViewModel.startMapRefresh()` / `stopMapRefresh()` verwaltet den kartenspezifischen SSE-Stream und wird korrekt in `MapContentView` via `.task` / `.onDisappear` gesteuert. Dieser Teil ist bereits aktiv-roboter-bewusst.

### ContentView — Roboter-Auswahl-Flow

```swift
// ContentView.swift
@State private var selectedRobotId: UUID?

// In RobotListView: Tap setzt selectedRobotId = robot.id
// NavigationDestination zeigt RobotDetailView
// Wechsel zurück: navigateToRobot = nil → selectedRobotId = nil
```

Der `selectedRobotId`-State existiert bereits in `ContentView` und wird an `RobotListView` durchgereicht. `MapTabView` zeigt nur wenn `selectedRobot != nil`. Es gibt also bereits eine "aktive Roboter"-Semantik auf View-Ebene — nur `RobotManager` kennt sie nicht.

### Lösung für ROBUST-03

**Option A (empfohlen): activeRobotId in RobotManager**

```swift
// RobotManager
var activeRobotId: UUID? {
    didSet { restartRefreshing() }
}

private func startRefreshing() {
    // SSE für alle Roboter (State-Updates auch im Hintergrund nötig)
    // HTTP-Polling nur für activeRobotId (oder alle wenn nil)
}
```

**Option B: ContentView leitet selectedRobotId an RobotManager weiter**

```swift
// ContentView
.onChange(of: selectedRobotId) { _, newId in
    robotManager.activeRobotId = newId
}
```

**Wichtige Einschränkung:** SSE für Attribut-Updates (Status, Batterie) sollte für alle Roboter aktiv bleiben — nur das Map-Polling (HTTP-Fallback in `startRefreshing()`) ist kostspielig und sollte beschränkt werden. Der Map-SSE in `MapViewModel` ist bereits richtig gesteuert.

**Klarstellung des Scope:** ROBUST-03 betrifft primär das HTTP-Polling in `startRefreshing()`. Der SSE-Attribut-Stream ist leichtgewichtig und kann für alle Roboter aktiv bleiben.

---

## Architecture Patterns

### ErrorRouter-Injection (bestehendes Pattern)

```swift
// 1. View empfängt aus Environment
@Environment(ErrorRouter.self) var errorRouter

// 2. View übergibt an ViewModel in .task
.task {
    viewModel.errorRouter = errorRouter
    await viewModel.loadData()
}

// 3. ViewModel speichert als Optional
var errorRouter: ErrorRouter?

// 4. ViewModel nutzt in catch-Blöcken
} catch {
    logger.error("...")
    errorRouter?.show(error)
}
```

### Confirmation Dialog Pattern (bestehendes Pattern)

**Für wisch-auslösbare Aktionen:**
```swift
@State private var showDeleteConfirm = false
@State private var itemToDelete: Item?

// In onDelete-Handler:
private func deleteItems(at offsets: IndexSet) {
    itemToDelete = items[offsets.first!]
    showDeleteConfirm = true
    // NICHT direkt löschen
}

// Modifier:
.confirmationDialog("title", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
    Button("Löschen", role: .destructive) {
        if let item = itemToDelete {
            Task { await deleteItem(item) }
        }
    }
    Button("Abbrechen", role: .cancel) {}
}
```

**Für Button-ausgelöste Aktionen:**
```swift
@State private var showConfirm = false

Button { showConfirm = true } label: { ... }

.alert("Titel", isPresented: $showConfirm) {
    Button("Abbrechen", role: .cancel) {}
    Button("Bestätigen", role: .destructive) {
        Task { await viewModel.action() }
    }
} message: { Text("Beschreibung") }
```

---

## Common Pitfalls

### Pitfall 1: onDelete-Bestätigung — IndexSet vs. Item

**Was schief geht:** Bei `.onDelete` liefert SwiftUI einen `IndexSet`. Wird der Dialog async gezeigt, kann sich der Index bis zur Bestätigung geändert haben (z.B. durch Refresh).

**Lösung:** Den konkreten `Item` (nicht den Index) im State speichern, dann beim Bestätigen nach ID löschen — nicht nach Index.

### Pitfall 2: ErrorRouter für Hintergrundoperationen

**Was schief geht:** `errorRouter?.show(error)` in `loadData()`-Methoden zeigt Fehler die der Nutzer nicht angefordert hat (z.B. Capabilities-Fehler beim initialen Laden).

**Lösung:** ErrorRouter nur für user-initiierte Aktionen (Button-Taps, explizite Aktionen). Hintergrundladevorgänge: nur logger, kein ErrorRouter.

### Pitfall 3: ROBUST-03 — SSE zu aggressiv einschränken

**Was schief geht:** Wenn SSE-Verbindungen für alle Roboter außer dem aktiven getrennt werden, fehlen Status-Benachrichtigungen (Battery Low, Cleaning Done) für nicht-aktive Roboter.

**Lösung:** SSE-Attribut-Updates für alle Roboter aktiv lassen. Nur HTTP-Polling (der Fallback in `startRefreshing()`) auf den aktiven Roboter beschränken. Map-SSE in `MapViewModel` ist bereits korrekt gesteuert.

### Pitfall 4: Restore Snapshot — fehlende Lokalisierungskeys

**Was schief geht:** Neuer Bestätigungsdialog für Snapshot-Restore braucht neue String-Keys (`snapshots.restore_warning_title`, `snapshots.restore_warning_message`, `snapshots.restore_confirm`).

**Lösung:** Keys in allen `.xcstrings`-Dateien hinzufügen bevor der Dialog gebaut wird. Bestehende Keys: `snapshots.title`, `snapshots.empty`, `snapshots.restore`, `snapshots.footer`.

---

## Don't Hand-Roll

| Problem | Nicht bauen | Stattdessen |
|---------|-------------|-------------|
| Bestätigungsdialoge | Eigene modale Views | `.confirmationDialog` oder `.alert` mit `role: .destructive` — iOS HIG-konform |
| Fehleranzeige | Eigene Error-Overlay-Views | Bestehenden `ErrorRouter` + `withErrorAlert` nutzen |
| Polling-Pause | Eigene Timer-Klasse | `Task.cancel()` auf bestehende Tasks in `refreshTask` |

---

## Environment Availability

Step 2.6: SKIPPED (keine externen Dependencies — reine Codeänderungen in bestehendem Projekt)

---

## Validation Architecture

Nyquist-Validation: `.planning/config.json` nicht vorhanden, daher als aktiviert behandelt.

Keine spezifische Test-Infrastruktur im Projekt vorhanden (kein `XCTestCase`, kein `Tests/`-Verzeichnis gefunden). Phase 29 enthält keine ViewModel-Logik die Unit-Tests erfordert — es sind View-State-Änderungen (Dialog-State, error routing). Manuelle Verifikation ist ausreichend.

### Phase Requirements → Test Map

| Req ID | Verhalten | Test-Typ | Verifikation |
|--------|-----------|----------|--------------|
| ROBUST-01 | Fehlermeldung erscheint nach fehlgeschlagener Aktion | Manuell | Netzwerk abschalten, Aktion triggern, Alert prüfen |
| ROBUST-02 | Bestätigungsdialog erscheint vor jeder destruktiven Aktion | Manuell | Jede Aktion tippen, Dialog prüfen |
| ROBUST-03 | Nur aktiver Roboter pollt bei Roboter-Wechsel | Manuell | Netzwerk-Logs, 2+ Roboter konfigurieren |

---

## Open Questions

1. **ROBUST-03: activeRobotId-Träger**
   - Was wir wissen: `selectedRobotId` existiert in `ContentView`, `RobotManager` kennt keinen aktiven Roboter
   - Unklar: Soll `activeRobotId` in `RobotManager` leben (zentralisiert) oder als `Binding` von `ContentView` nach unten gereicht werden?
   - Empfehlung: In `RobotManager` — es ist der natürliche Ort für Roboter-Zustand, und `ContentView` setzt ihn über `onChange`

2. **Remove Robot in RobotListView — Bestätigungsdialog nötig?**
   - Was wir wissen: ROBUST-02 nennt "Remove Robot" explizit als destruktive Aktion
   - Unklar: Betrifft es nur `EditRobotView` (Button) oder auch `RobotListView` (Swipe)?
   - Empfehlung: Beide Einstiegspunkte brauchen Bestätigung — selbe Konsequenz (Datenverlust)

---

## Sources

### Primary (HIGH confidence)
- `/ValetudoApp/ValetudoApp/Services/RobotManager.swift` — Polling-Mechanismus, startRefreshing(), SSEConnectionManager
- `/ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift` — ErrorRouter-Lücken, Aktionen
- `/ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift` — ErrorRouter-Lücken, Map-Polling
- `/ValetudoApp/ValetudoApp/ViewModels/RobotSettingsViewModel.swift` — restoreMapSnapshot, ErrorRouter
- `/ValetudoApp/ValetudoApp/Views/ConsumablesView.swift` — confirmationDialog-Pattern (Referenz)
- `/ValetudoApp/ValetudoApp/Views/RobotSettingsView.swift` — .alert-Pattern für Bestätigung (Referenz)
- `/ValetudoApp/ValetudoApp/Views/TimersView.swift` — fehlendes confirmationDialog bei deleteTimers
- `/ValetudoApp/ValetudoApp/Views/SettingsView.swift` — fehlendes confirmationDialog bei deleteRobots / EditRobotView
- `/ValetudoApp/ValetudoApp/Views/RobotListView.swift` — fehlendes confirmationDialog bei onDelete
- `/ValetudoApp/ValetudoApp/ContentView.swift` — selectedRobotId-State, Robot-Auswahl-Flow
- `/ValetudoApp/ValetudoApp/Helpers/ErrorRouter.swift` — ErrorRouter-Implementierung, withErrorAlert

---

## Metadata

**Confidence breakdown:**
- ROBUST-01 (ErrorRouter-Lücken): HIGH — vollständige Quellcode-Analyse aller catch-Blöcke
- ROBUST-02 (Confirmation Dialogs): HIGH — alle Aktionen und bestehende Patterns direkt geprüft
- ROBUST-03 (Polling): HIGH — RobotManager-Implementierung vollständig gelesen, Polling-Logik klar

**Research date:** 2026-04-04
**Valid until:** 2026-05-04 (stabiler Code, keine externen Dependencies)
