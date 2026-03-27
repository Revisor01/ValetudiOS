# Roadmap: ValetudiOS

## Milestones

- 🚧 **v1.2.0 Quality & API Completeness** - Phases 1-4 (in progress)

## Phases

### 🚧 v1.2.0 Quality & API Completeness (In Progress)

**Milestone Goal:** Technische Schulden abbauen, Valetudo API vollständig integrieren, UX-Verbesserungen — ohne externe Dependencies.

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [x] **Phase 1: Foundation** - Keychain, ErrorRouter, os.Logger — Infrastruktur-Grundlage und Fehlerbehandlung (completed 2026-03-27)
- [x] **Phase 2: Network Layer** - SSE-Streaming, mDNS-Discovery, Map-Pixel-Cache (completed 2026-03-27)
- [ ] **Phase 3: API Completeness** - Neue Valetudo-Capabilities und Notification Actions
- [ ] **Phase 4: View Refactoring & Tests** - ViewModel-Extraktion und XCTest-Coverage

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
- [ ] 03-01-PLAN.md — API-Methoden und Model-Structs fuer MapSnapshot, PendingMapChange, CleanRoute, Events, ObstacleImages
- [ ] 03-02-PLAN.md — Map-Snapshot/Pending-Map-Change UI in RobotSettingsView + Notification-Actions (GO_HOME, LOCATE) via AppDelegate
- [ ] 03-03-PLAN.md — Events-Section und CleanRoute-Picker in RobotDetailView + ObstaclePhotoView

### Phase 4: View Refactoring & Tests
**Goal**: Die drei monolithischen Views sind in ViewModels + Sub-Views aufgeteilt und ein XCTest-Target validiert kritische Logik
**Depends on**: Phase 3
**Requirements**: DEBT-02, DEBT-04
**Success Criteria** (what must be TRUE):
  1. MapView, RobotDetailView und RobotSettingsView delegieren ihre Logik an dedizierte @MainActor ViewModels; die Views selbst sind rein deklarative Shells
  2. Ein XCTest-Target existiert mit Tests für Timer-Konvertierung, Consumable-Prozente, Map-RLE-Dekompression und Keychain-Round-Trip
  3. Alle neuen ViewModels nutzen @StateObject (nicht @ObservedObject), sodass kein ViewModel bei Parent-Re-Renders neu erstellt wird
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 3/3 | Complete   | 2026-03-27 |
| 2. Network Layer | 3/3 | Complete   | 2026-03-27 |
| 3. API Completeness | 0/3 | Not started | - |
| 4. View Refactoring & Tests | 0/TBD | Not started | - |
