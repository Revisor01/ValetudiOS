# Roadmap: ValetudiOS

## Milestones

- [x] **v1.2.0 Quality & API Completeness** - Phases 1-4 (completed 2026-03-28)
- [x] **v1.3.0 Polish & Full API Coverage** - Phases 5-8 (completed 2026-03-28)
- [x] **v1.4.0 Code Quality & Robustness** - Phases 9-11 (completed 2026-03-29)
- [ ] **v2.0.0 Update Process Hardening** - Phases 12-15

## Phases

### v1.2.0 Quality & API Completeness (Completed)

- [x] **Phase 1: Foundation** - Keychain, ErrorRouter, os.Logger — Infrastruktur-Grundlage und Fehlerbehandlung (completed 2026-03-27)
- [x] **Phase 2: Network Layer** - SSE-Streaming, mDNS-Discovery, Map-Pixel-Cache (completed 2026-03-27)
- [x] **Phase 3: API Completeness** - Neue Valetudo-Capabilities und Notification Actions (completed 2026-03-28)
- [x] **Phase 4: View Refactoring & Tests** - ViewModel-Extraktion und XCTest-Coverage (completed 2026-03-27)

### v1.3.0 Polish & Full API Coverage (Completed)

**Milestone Goal:** Phase-3-UI in ViewModels wiederherstellen, fehlende Valetudo-Capabilities nachrüsten, Robustness-Concerns beheben, Test-Coverage erweitern.

- [x] **Phase 5: UI Restore** - Events, CleanRoute, Snapshots, Obstacles und Notifications in ViewModels und Views verdrahten (completed 2026-03-28)
- [x] **Phase 6: New Capabilities** - VoicePack, AutoEmptyDuration, MopDryingTime und Robot Properties (completed 2026-03-28)
- [x] **Phase 7: Bugfixes & Robustness** - Force-unwraps, stille Fehler, SSE Backoff, Koordinaten-Fix (completed 2026-03-28)
- [x] **Phase 8: Test Coverage** - ViewModel- und API-Layer-Tests aufbauen (completed 2026-03-28)

### v1.4.0 Code Quality & Robustness (Completed)

**Milestone Goal:** Codebase sauber machen — alle print()-Reste, Force-Unwraps, fehlende Logger, inkonsistente Concurrency-Patterns, Keychain-Fehlerbehandlung, und View-Decomposition.

- [x] **Phase 9: Logger Migration** - print() durch os.Logger in allen Views und Services ersetzen, DispatchQueue auf structured concurrency migrieren (completed 2026-03-28)
- [x] **Phase 10: Safety Fixes** - Force-Unwrap und Keychain-Fehlerbehandlung reparieren, hardcoded URLs/ProductIDs in Constants extrahieren (completed 2026-03-28)
- [x] **Phase 11: View Decomposition** - MapView, RobotSettingsView und RobotDetailView in logische Sub-Views aufbrechen (completed 2026-03-28)

### v2.0.0 Update Process Hardening

**Milestone Goal:** Den Firmware-Update-Prozess robust und fehlerfrei machen — kein Doppelklick, klare Zustandsanzeige, Fehlerfeedback, Schutz während kritischer Phasen.

- [x] **Phase 12: State Machine Foundation** - UpdatePhase-Enum, UpdateService mit Re-Entrancy-Guard und Error-State-Modell einführen (completed 2026-04-01)
- [x] **Phase 13: State Consolidation** - Doppelte Update-Logik entfernen, RobotManager verdrahten, ValetudoInfoView bereinigen (completed 2026-04-01)
- [ ] **Phase 14: Apply Phase Hardening** - Idle Timer, Reboot-Fenster-Erkennung, Background Task und Fullscreen-Lock absichern
- [ ] **Phase 15: UI Wiring** - Fortschrittsanzeige, Error-Banner und gedrosseltes Update-Checking einbauen

## Phase Details

### Phase 1: Foundation
**Goal**: Alle Inhalte der App nutzen sicheren Credential-Speicher, strukturiertes Logging und sichtbare Fehlermeldungen
**Depends on**: Nothing (first phase)
**Requirements**: NET-03, UX-02, UX-01, DEBT-01
**Success Criteria** (what must be TRUE):
  1. Credentials werden im iOS Keychain gespeichert und die UserDefaults-Migration ist verlustfrei abgeschlossen
  2. Fehlgeschlagene Aktionen zeigen dem Benutzer eine lesbare Fehlermeldung (kein stilles Versagen)
  3. Tapping auf eine beliebige Stelle der Robot-Zeile navigiert zur Detailansicht
  4. Alle print()-Aufrufe sind durch os.Logger ersetzt und Debug-Output erscheint nur in DEBUG-Builds
**Plans**: 3 plans

Plans:
- [x] 01-01-PLAN.md — Keychain-Migration: KeychainStore Service, RobotConfig CodingKeys-Exclusion, Migration in RobotManager, ValetudoAPI/Intents Credential-Umstellung
- [x] 01-02-PLAN.md — ErrorRouter fuer sichtbare Fehlermeldungen + NavigationLink-Fix fuer klickbare Robot-Zeilen
- [x] 01-03-PLAN.md — os.Logger-Migration: print() durch strukturiertes Logging in allen Service-Dateien ersetzen

### Phase 2: Network Layer
**Goal**: Roboterstatus-Updates kommen in Echtzeit via SSE, Roboter werden via mDNS entdeckt, Map-Dekompression wird gecacht
**Depends on**: Phase 1
**Requirements**: NET-01, NET-02, DEBT-03
**Success Criteria** (what must be TRUE):
  1. Statusanzeige des Roboters aktualisiert sich bei Zustandsanderungen ohne 5-Sekunden-Verzögerung (SSE aktiv, Polling deaktiviert)
  2. Roboter-Scan per mDNS/Bonjour findet Valetudo-Geräte ohne IP-Brute-Force; IP-Scan bleibt als Fallback aktiv
  3. Map-Rendering ist merklich flüssiger, da Pixel-Dekompression pro Map-Daten-Version gecacht wird (nicht per Frame neu berechnet)
**Plans**: 3 plans

Plans:
- [x] 02-01-PLAN.md — SSE-Echtzeit-Updates: SSEConnectionManager actor, ValetudoAPI SSE-Methoden, RobotManager SSE-first mit Polling-Fallback
- [x] 02-02-PLAN.md — mDNS/Bonjour Discovery: NWBrowserService, NetworkScanner mDNS-Integration, AddRobotView Ergebnisanzeige
- [x] 02-03-PLAN.md — Map-Pixel-Cache und Map-SSE: MapLayerCache class-wrapper, MapView Map-SSE-Lifecycle

### Phase 3: API Completeness
**Goal**: Alle verifizierten Valetudo-Capabilities sind in der App erreichbar und Notification-Actions lösen reale Roboter-Befehle aus
**Depends on**: Phase 2
**Requirements**: API-01, API-02, API-03, API-04, UX-03, UX-04
**Success Criteria** (what must be TRUE):
  1. Benutzer kann einen Map-Snapshot erstellen und einen gespeicherten Snapshot wiederherstellen
  2. Benutzer kann ausstehende Kartenänderungen nach einem Mapping-Durchlauf akzeptieren oder ablehnen
  3. Benutzer kann die Reinigungsroute (Standard, Bow-Tie, Spiral etc.) auswählen und der Roboter übernimmt sie
  4. Benutzer kann Fotos von erkannten Hindernissen im Reinigungsprotokoll ansehen (sofern Roboter AI-Kamera hat)
  5. Benutzer sieht Valetudo Events (DustBinFull, MopReminder, Errors) in einer dedizierten Ansicht
  6. Notification-Actions GO_HOME und LOCATE schicken den Roboter nach Hause bzw. lassen ihn piepen
**Plans**: 3 plans
**UI hint**: yes

Plans:
- [x] 03-01-PLAN.md — API-Methoden und Model-Structs fuer MapSnapshot, PendingMapChange, CleanRoute, Events, ObstacleImages
- [x] 03-02-PLAN.md — Map-Snapshot/Pending-Map-Change UI in RobotSettingsView + Notification-Actions (GO_HOME, LOCATE) via AppDelegate
- [x] 03-03-PLAN.md — Events-Section und CleanRoute-Picker in RobotDetailView + ObstaclePhotoView

### Phase 4: View Refactoring & Tests
**Goal**: Die drei monolithischen Views sind in ViewModels + Sub-Views aufgeteilt und ein XCTest-Target validiert kritische Logik
**Depends on**: Phase 3
**Requirements**: DEBT-02, DEBT-04
**Success Criteria** (what must be TRUE):
  1. MapView, RobotDetailView und RobotSettingsView delegieren ihre Logik an dedizierte @MainActor ViewModels; die Views selbst sind rein deklarative Shells
  2. Ein XCTest-Target existiert mit Tests für Timer-Konvertierung, Consumable-Prozente, Map-RLE-Dekompression und Keychain-Round-Trip
  3. Alle neuen ViewModels nutzen @StateObject (nicht @ObservedObject), sodass kein ViewModel bei Parent-Re-Renders neu erstellt wird
**Plans**: 4 plans

Plans:
- [x] 04-01-PLAN.md — XCTest-Target und Unit-Tests: Timer-Konvertierung, Consumable-Prozente, MapLayer-RLE, Keychain-Round-Trip
- [x] 04-02-PLAN.md — RobotDetailViewModel-Extraktion: State und Logik aus RobotDetailView in ViewModel
- [x] 04-03-PLAN.md — RobotSettingsViewModel-Extraktion: State und Logik aus RobotSettingsView in ViewModel
- [x] 04-04-PLAN.md — MapViewModel-Extraktion: State und Logik aus MapContentView in ViewModel

### Phase 5: UI Restore
**Goal**: Alle in Phase 3 implementierten API-Capabilities sind vollständig in den neuen ViewModels verdrahtet und für den Benutzer nutzbar
**Depends on**: Phase 4
**Requirements**: UIR-01, UIR-02, UIR-03, UIR-04, UIR-05, UIR-06
**Success Criteria** (what must be TRUE):
  1. Benutzer sieht in RobotDetailView eine chronologische Events-Liste mit Dismiss-Button (sofern Roboter Events liefert)
  2. Benutzer kann die Reinigungsroute über einen Picker in RobotDetailView wählen; Picker erscheint nur wenn der Roboter die Capability meldet
  3. Benutzer kann in RobotSettingsView gespeicherte Map-Snapshots sehen und einen davon wiederherstellen; Sektion ist capability-gated
  4. Benutzer kann in RobotSettingsView ausstehende Kartenänderungen akzeptieren oder ablehnen; Sektion ist capability-gated
  5. Benutzer kann in RobotDetailView Obstacle-Fotos aufrufen und die Detailansicht (ObstaclePhotoView) öffnen; Sektion ist capability-gated
  6. Notification-Actions GO_HOME und LOCATE lösen die jeweilige API-Aktion aus, wenn der Benutzer die Notification-Aktion antippt
**Plans**: 2 plans
**UI hint**: yes

Plans:
- [x] 05-01-PLAN.md — Events-Section, CleanRoute-Picker und Obstacle-Photos in RobotDetailViewModel/View + API-Erweiterungen
- [x] 05-02-PLAN.md — Map-Snapshots und Pending-Map-Change Sections in RobotSettingsViewModel/View

### Phase 6: New Capabilities
**Goal**: Benutzer kann vier zusätzliche Roboter-Capabilities steuern, die bislang nicht in der App erreichbar waren
**Depends on**: Phase 5
**Requirements**: CAP-01, CAP-02, CAP-03, CAP-04
**Success Criteria** (what must be TRUE):
  1. Benutzer kann installierten Voice Pack sehen und ein anderes Sprachpaket aus der Liste auswählen und aktivieren
  2. Benutzer kann die Absaugdauer der Auto-Empty-Station über einen Picker steuern (Werte laut API-Enum)
  3. Benutzer kann die Trocknungszeit der Mop-Station über einen Picker steuern (Werte laut API-Enum)
  4. Benutzer sieht Modell, Firmware-Version und Seriennummer des Roboters in einer dedizierten Properties-Ansicht
**Plans**: 4 plans
**UI hint**: yes

Plans:
- [x] 06-01-PLAN.md — VoicePack: API-Methoden + VoicePack/VoicePackState Structs + ViewModel-State + Picker-Section in RobotSettingsView
- [x] 06-02-PLAN.md — AutoEmptyDockDuration: API-Methoden + ViewModel-State + Preset-Picker in Auto-Empty-Section
- [x] 06-03-PLAN.md — MopDockDryingTime: API-Methoden + ViewModel-State + Preset-Picker in Mop-Dock-Section
- [x] 06-04-PLAN.md — RobotProperties: getRobotProperties() API + RobotProperties Struct + Properties-Section in RobotDetailView

### Phase 7: Bugfixes & Robustness
**Goal**: Keine Force-unwraps, keine stillen Fehler, SSE-Reconnect mit Backoff und korrekte Koordinaten-Transformation in der Karte
**Depends on**: Phase 5
**Requirements**: FIX-01, FIX-02, FIX-03, FIX-04
**Success Criteria** (what must be TRUE):
  1. Ungültige URLs in NetworkScanner und RobotDetailView führen zu einem geloggten Fehler statt zu einem Crash
  2. Fehlgeschlagene API-Calls in ViewModels und Services zeigen dem Benutzer eine ErrorRouter-Alert oder einen Logger-Warning-Eintrag; kein Fehler wird mehr lautlos verworfen
  3. SSE-Verbindung re-connectet nach 1s, 5s und dann 30s statt sofort mit 30s; Backoff ist im Logger nachvollziehbar
  4. Zonen und GoTo-Marker werden auf der Karte an der richtigen Position gerendert (kein systematischer Versatz durch Float-zu-Int-Rundung)
**Plans**: 4 plans

Plans:
- [x] 07-01-PLAN.md — FIX-01: Force-unwrap URLs in NetworkScanner.checkHost() und RobotDetailView.updateUrl ersetzen
- [x] 07-02-PLAN.md — FIX-02: Stille catch-Blöcke in MapViewModel und RobotManager durch logger.warning/errorMessage ersetzen
- [x] 07-03-PLAN.md — FIX-03: SSE Exponential Backoff (1s → 5s → 30s) in SSEConnectionManager.streamWithReconnect()
- [x] 07-04-PLAN.md — FIX-04: Koordinaten-Truncation in MapView.finishDrawing(), GoTo-Drag und MapViewModel.splitRoom() durch .rounded() beheben

### Phase 8: Test Coverage
**Goal**: Kritische ViewModel-Logik und der API-Layer sind durch automatisierte Tests abgedeckt und regressionssicher
**Depends on**: Phase 7
**Requirements**: TEST-01, TEST-02
**Success Criteria** (what must be TRUE):
  1. XCTest-Suite enthält Tests für RobotDetailViewModel, RobotSettingsViewModel und MapViewModel State-Transitions (z.B. Laden, Fehlerfall, Capability-Check)
  2. XCTest-Suite enthält Tests für ValetudoAPI Request/Response Encoding, Error-Handling und HTTP-Statuscode-Interpretation (4xx, 5xx)
  3. Alle Tests laufen grün in Xcode und im Xcode Cloud CI-Build
**Plans**: 2 plans

Plans:
- [x] 08-01-PLAN.md — ViewModel-Tests: RobotDetailViewModel, RobotSettingsViewModel und MapViewModel State-Transitions ohne API-Mocking
- [x] 08-02-PLAN.md — API-Tests: APIError-Enum, RobotConfig.baseURL und JSON-Decoding der Kernmodelle

### Phase 9: Logger Migration
**Goal**: Kein einziger print()-Aufruf verbleibt in Views oder Services; alle Concurrency-Patterns folgen Swift Structured Concurrency
**Depends on**: Nothing (first phase of new milestone)
**Requirements**: LOG-01, LOG-02, LOG-03, SAFE-03
**Success Criteria** (what must be TRUE):
  1. Suche nach `print(` in Views und Services liefert null Treffer; stattdessen erscheint strukturierter Output im Xcode-Log via os.Logger
  2. Jede View-Datei mit Log-Output hat eine private `let logger = Logger(...)` Property mit passendem subsystem und category
  3. SupportReminderView nutzt `Task { try await Task.sleep(...) }` statt `DispatchQueue.main.asyncAfter`; kein DispatchQueue-Import nötig
  4. Log-Einträge aus Views sind nach subsystem/category in der Console.app filterbar
**Plans**: 3 plans

Plans:
- [x] 09-01-PLAN.md — Logger-Migration Views (Batch 1): DoNotDisturbView, StatisticsView, IntensityControlView, MapView (11 print()-Stellen)
- [x] 09-02-PLAN.md — Logger-Migration Views (Batch 2): ManualControlView, RoomsManagementView, TimersView (17 print()-Stellen)
- [x] 09-03-PLAN.md — Logger-Migration SupportManager + DispatchQueue→Task.sleep in SupportReminderView

### Phase 10: Safety Fixes
**Goal**: Kein Force-Unwrap gefährdet die App-Stabilität, Keychain-Fehler werden sichtbar geloggt, und alle Magic-Strings sind zentralisiert
**Depends on**: Phase 9
**Requirements**: SAFE-01, SAFE-02, ORG-01
**Success Criteria** (what must be TRUE):
  1. SettingsView enthält keinen `!`-Force-Unwrap mehr; nil-Fälle werden durch optional binding oder nil-coalescing behandelt
  2. KeychainStore loggt jeden fehlgeschlagenen SecItemDelete/SecItemAdd-Call mit dem OSStatus-Fehlercode; kein Fehler wird mehr stillschweigend ignoriert
  3. GitHub-API-URLs und In-App-Purchase-ProductIDs sind in einer zentralen Constants-Datei definiert; kein Literal-String ist doppelt vorhanden
**Plans**: 1 plan

Plans:
- [x] 10-01-PLAN.md — SAFE-01/02/ORG-01: Force-Unwrap fix, Keychain-Fehlerlogger, Constants.swift mit URLs und ProductIDs

### Phase 11: View Decomposition
**Goal**: Die drei größten Views sind in überschaubare Sub-Views aufgeteilt; keine einzelne View-Datei überschreitet eine handhabbare Größe
**Depends on**: Phase 10
**Requirements**: ORG-02, ORG-03, ORG-04
**Success Criteria** (what must be TRUE):
  1. MapView (bisher 2532 Zeilen) ist in eigenständige Sub-Views aufgeteilt (MiniMap, Controls, Drawing-Helpers); die Haupt-Datei delegiert an diese
  2. RobotSettingsView (bisher 1801 Zeilen) ist in Section-Views aufgeteilt; jede Section ist eine eigene View-Struct
  3. RobotDetailView (bisher 1253 Zeilen) ist in Section-Views aufgeteilt; jede Section ist eine eigene View-Struct
  4. Alle Sub-Views kompilieren fehlerfrei und zeigen in der Xcode-Preview dieselben Inhalte wie zuvor
**Plans**: 3 plans
**UI hint**: yes

Plans:
- [x] 11-01-PLAN.md — MapView-Dekomposition: MiniMapView, InteractiveMapView, MapControlBarsView, MapSheetsView
- [x] 11-02-PLAN.md — RobotSettingsView-Dekomposition: RobotSettingsSections.swift mit 7 eigenstaendigen Sub-Views
- [x] 11-03-PLAN.md — RobotDetailView-Dekomposition: RobotDetailSections.swift mit ControlButton, DockActionButton, PulseAnimationView

### Phase 12: State Machine Foundation
**Goal**: Der Update-Prozess hat eine einzige autoritative State Machine — Update-Zustände sind als unveränderliches Enum modelliert, Doppelaufrufe werden type-safe verhindert, und Fehler werden explizit abgebildet
**Depends on**: Phase 11
**Requirements**: STATE-01, STATE-02, STATE-03, STATE-04
**Success Criteria** (what must be TRUE):
  1. Der Update-Zustand des Roboters ist zu jedem Zeitpunkt in genau einem der Zustände Idle, Checking, Downloading, ReadyToApply, Applying, Rebooting oder Error — kein "Zwischen-Boolean" ist mehr nötig
  2. Ein zweiter Tap auf "Nach Updates suchen" oder "Update starten" während ein Update bereits läuft hat keine Wirkung — kein zweiter API-Call wird abgesetzt
  3. Ein Valetudo-Fehler nach einem fehlgeschlagenen Download oder Apply zeigt dem Benutzer eine lesbare Fehlermeldung statt stillem Zurücksetzen
  4. Alle Update-Aufrufe gehen durch `UpdateService` — `RobotDetailViewModel` und `ValetudoInfoView` lesen denselben `@Published phase`-Wert
**Plans**: 2 plans

Plans:
- [x] 12-01-PLAN.md — UpdatePhase-Enum und UpdateService: State Machine mit 8 Cases, Re-Entrancy-Guards, Error-State, Valetudo-State-Mapping
- [x] 12-02-PLAN.md — Verdrahtung: RobotDetailViewModel Proxy-Delegation + ValetudoInfoView UpdateService-Injection

### Phase 13: State Consolidation
**Goal**: Es gibt genau eine Code-Stelle, die Update-Logik besitzt — doppelte Properties und parallele Check-Pfade sind eliminiert
**Depends on**: Phase 12
**Requirements**: CLEAN-01, CLEAN-02
**Success Criteria** (what must be TRUE):
  1. Die Properties `isUpdating` und `showUpdateWarning` existieren nicht mehr im ViewModel — die View leitet alle Darstellungsentscheidungen aus `updatePhase` ab
  2. `ValetudoInfoView` ruft keine eigene `checkForUpdate()`-Variante mehr auf; Update-Status-Anfragen gehen ausschließlich über `UpdateService`
  3. Ein Grep nach `isUpdating` und `showUpdateWarning` im gesamten Codebase liefert null Treffer
**Plans**: 1 plan

Plans:
- [x] 13-01-PLAN.md — Redundante Update-Properties entfernen, UpdateService als alleinige Source of Truth verdrahten

### Phase 14: Apply Phase Hardening
**Goal**: Der kritische Moment zwischen "Apply gedrückt" und "Roboter wieder online" ist vollständig abgesichert — kein Schlafmodus, kein falscher Fehler, kein App-Abbruch
**Depends on**: Phase 13
**Requirements**: APPLY-01, APPLY-02, APPLY-03, APPLY-04
**Success Criteria** (what must be TRUE):
  1. Sobald Apply gestartet wird, erscheint ein Vollbild-Overlay das nicht weggeklickt oder durch Wischen geschlossen werden kann; es verschwindet erst wenn der Roboter wieder erreichbar ist oder ein Timeout eintritt
  2. Das Display bleibt während Download und Apply durchgehend an — kein automatischer Schlafmodus nach 2 Minuten
  3. Nach einem erfolgreichen Apply und Roboter-Neustart wird kein Fehler angezeigt; die App erkennt das Reboot-Fenster (30–90 Sekunden keine Verbindung) als erwartetes Verhalten
  4. Wenn der Benutzer die App in den Hintergrund schiebt während Apply läuft, wird der API-Call nicht durch iOS abgebrochen
**Plans**: TBD
**UI hint**: yes

### Phase 15: UI Wiring
**Goal**: Benutzer sieht jederzeit den exakten Update-Zustand, Download-Fortschritt und Fehlerdetails ohne die App neu starten zu müssen
**Depends on**: Phase 14
**Requirements**: UI-01, UI-02, UI-03
**Success Criteria** (what must be TRUE):
  1. Während des Downloads zeigt die Update-Sektion eine ProgressView mit prozentualer Angabe an — die Zahl steigt sichtbar von 0 bis 100
  2. Schlägt ein Update-Schritt fehl, erscheint ein Error-Banner mit der Fehlermeldung; der Benutzer kann Retry oder Dismiss tippen
  3. Update-Check wird maximal einmal pro Stunde ausgelöst — mehrfaches Öffnen und Schließen der View innerhalb einer Stunde sendet keinen erneuten Check-Request an den Roboter
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
v1.2.0: 1 → 2 → 3 → 4 (completed)
v1.3.0: 5 → 6 → 7 → 8 (completed)
v1.4.0: 9 → 10 → 11 (completed)
v2.0.0: 12 → 13 → 14 → 15

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 3/3 | Complete | 2026-03-27 |
| 2. Network Layer | 3/3 | Complete | 2026-03-27 |
| 3. API Completeness | 3/3 | Complete | 2026-03-28 |
| 4. View Refactoring & Tests | 4/4 | Complete | 2026-03-27 |
| 5. UI Restore | 2/2 | Complete   | 2026-03-28 |
| 6. New Capabilities | 4/4 | Complete | 2026-03-28 |
| 7. Bugfixes & Robustness | 4/4 | Complete | 2026-03-28 |
| 8. Test Coverage | 2/2 | Complete   | 2026-03-28 |
| 9. Logger Migration | 3/3 | Complete   | 2026-03-28 |
| 10. Safety Fixes | 1/1 | Complete    | 2026-03-28 |
| 11. View Decomposition | 3/3 | Complete    | 2026-03-29 |
| 12. State Machine Foundation | 2/2 | Complete   | 2026-04-01 |
| 13. State Consolidation | 1/1 | Complete   | 2026-04-01 |
| 14. Apply Phase Hardening | 0/? | Not started | - |
| 15. UI Wiring | 0/? | Not started | - |
