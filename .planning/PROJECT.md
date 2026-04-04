# ValetudiOS

## What This Is

Native iOS-App (SwiftUI) zur Steuerung von Valetudo-basierten Saugrobotern im lokalen Netzwerk. Bietet Roboter-Management, Live-Karte, Raumreinigung, Timer, manuelle Steuerung und Siri-Integration. Kommuniziert direkt mit der Valetudo REST API v2.

## Core Value

Zuverlässige, native iOS-Steuerung von Valetudo-Robotern ohne Cloud-Abhängigkeit.

## Requirements

### Validated

- Keychain-Credential-Speicher: Passwörter sicher im iOS Keychain -- Phase 1
- ErrorRouter: Zentrales Error-Handling mit .alert-basierter Fehlermeldung -- Phase 1
- Robot-Zeile klickbar: Gesamte Zeile navigiert zur Detailansicht -- Phase 1
- Strukturiertes Logging: os.Logger statt print() in allen Services -- Phase 1
- SSE Real-Time Updates: Roboterstatus via Server-Sent Events mit Polling-Fallback -- Phase 2
- mDNS/Bonjour Discovery: NWBrowser-basierte Roboter-Erkennung mit IP-Scan-Fallback -- Phase 2
- Map-Pixel-Caching: MapLayerCache class-wrapper für gecachte Dekompression -- Phase 2
- Robot-Management: Hinzufügen, Konfigurieren, Entfernen von Robotern via LAN
- Live-Karte: Interaktive Kartenansicht mit Zoom/Pan, Raumanzeige, Zonen
- Raumreinigung: Einzelne Räume auswählen und reinigen
- Grundsteuerung: Start, Stop, Pause, Home
- Timer-Verwaltung: Erstellen/Bearbeiten/Löschen von Reinigungstimern
- Manuelle Steuerung: Touchpad-basierte Robotersteuerung (High-Resolution)
- Verbrauchsmaterial-Anzeige: Status und Benachrichtigungen
- GoTo-Presets: Gespeicherte Positionen auf der Karte
- Siri-Integration: Sprachsteuerung via App Intents
- Einstellungen: Fan-Speed, Wasser-Level, Operationsmodus
- Netzwerk-Scanner: Automatische Roboter-Erkennung im LAN
- Lokale Benachrichtigungen: Reinigung fertig, Fehler, Verbrauchsmaterial niedrig
- Floor Material Management
- Lokalisierung: Deutsch + Englisch

### Validated (v2.0.0)

- UpdatePhase State Machine: Enum-basiertes Update-Lifecycle-Management -- v2.0.0
- Re-Entrancy-Guard: Doppelklick-Schutz via State-Pattern-Matching -- v2.0.0
- Error-State: Fehlermeldungen bei Update-Problemen sichtbar -- v2.0.0
- UpdateService als Single Source of Truth: Keine doppelte Update-Logik -- v2.0.0
- Fullscreen-Lock: Nicht-schliessbares Overlay während Apply/Reboot -- v2.0.0
- Idle Timer: Display bleibt an während Update -- v2.0.0
- Reboot-Erkennung: Neustart wird nicht als Fehler gewertet -- v2.0.0
- Background Task: Apply wird bei App-Hintergrund nicht abgebrochen -- v2.0.0
- Download-Fortschritt: ProgressView mit Prozentanzeige -- v2.0.0
- Error-Banner: Inline-Fehlermeldung mit Retry-Button -- v2.0.0
- Update-Check Throttling: Max 1x/Stunde -- v2.0.0
- Property-Cleanup: isUpdating/showUpdateWarning entfernt -- v2.0.0
- Französische Übersetzung: 206 Strings aus Community-PR -- v2.0.0

### Validated (v2.1.0)

- DeviceInfoSection: Geräte-Info vereinheitlicht in RobotDetailView -- v2.1.0
- BGAppRefreshTask: Hintergrund-Status-Prüfung mit Notifications -- v2.1.0
- Map-Caching: Offline-Karte mit automatischer Wiederherstellung -- v2.1.0
- @Observable Migration: 11 Klassen, 19 Views, zero legacy patterns -- v2.1.0

### Validated (v2.2.0)

- Reinigungsreihenfolge: Zahlen 1, 2, 3 auf der Karte beim Raumauswählen -- v2.2.0 Phase 21
- Raumauswahl ohne Labels: Tap auf Raumfläche statt nur auf Label -- v2.2.0 Phase 20

### Active

<!-- v3.0.0 — Quality, Performance & Hardening -->
- [ ] Map Geometry: calculateMapParams dedupliziert, Koordinaten-Transforms zentral, Room-Selection-State einheitlich -- v3.0.0 Phase 22
- [ ] Error Handling: Stille try?-Fehler eliminiert, DebugConfig-Masking gefixt, isInitialLoad ersetzt, Capability-Refresh -- v3.0.0 Phase 23
- [ ] Map Performance: SSE Map-Streaming, Spatial Hit-Testing, segmentInfos-Cache, CGImage Pre-Rendering -- v3.0.0 Phase 24
- [ ] View Architecture: RobotDetailView/SettingsSections dekomponiert, MapContentView-State in ViewModel -- v3.0.0 Phase 25
- [ ] Security: HTTP-Warnung, SSL-Bypass-Warnung, verschlüsselte Config-Speicherung -- v3.0.0 Phase 26
- [ ] Accessibility: VoiceOver-Labels für Controls, Status, Consumables, Map-Canvas -- v3.0.0 Phase 27
- [ ] Test Coverage: Unit-Tests für Transforms, UpdateService, SSE, MapCache -- v3.0.0 Phase 28
- [ ] UX Robustness: ErrorRouter verdrahtet, Confirmation-Dialogs, Multi-Robot-Polling -- v3.0.0 Phase 29

### Validated (v1.4.0)

- print() → os.Logger in allen Views und Services -- v1.4.0
- Force-Unwrap in SettingsView eliminiert -- v1.4.0
- KeychainStore Fehlerbehandlung mit OSStatus-Logging -- v1.4.0
- DispatchQueue → Task.sleep structured concurrency -- v1.4.0
- Constants.swift für URLs/ProductIDs -- v1.4.0
- View-Decomposition: MapView 66%, RobotSettingsView 72% Reduktion -- v1.4.0

### Out of Scope

- Multi-Floor-Support -- Valetudo unterstützt dies nicht offiziell, nur Workarounds via SSH
- Cloud-Anbindung -- Lokale Kommunikation ist Core Value
- Android-Version -- Nur iOS

## Current State

**Shipped:** v2.2.0 (2026-04-04)
**In Progress:** v3.0.0 — Quality, Performance & Hardening (8 Phasen, 31 Requirements)
**Version:** 2.2.0 — Room Interaction & Cleaning Order

Die App ermöglicht Raumauswahl per Tap auf die Raumfläche (nicht nur Labels), zeigt die Reinigungsreihenfolge als nummerierte Badges auf der Karte und in der Raumliste, und übergibt die gewählte Reihenfolge mit `customOrder: true` an die Valetudo API. Basiert auf moderner @Observable-Architektur (iOS 17+), vollständiger Valetudo API-Abdeckung, SSE-Echtzeit-Updates, mDNS-Discovery, 57 Unit-Tests und dreisprachiger Lokalisierung (DE/EN/FR).

<details>
<summary>v2.2.0 Milestone (completed)</summary>

**Goal:** Raumauswahl per Flächen-Tap und Reinigungsreihenfolge

**Delivered:**
- SpatialTapGesture mit Pixel-Lookup auf Canvas für Raumauswahl per Fläche
- Set→Array Migration für deterministische Auswahlreihenfolge
- Nummerierte blaue Badges (1, 2, 3) auf Karte und in Raumliste
- customOrder API-Parameter für tatsächliche Einhaltung der Reinigungsreihenfolge
</details>

<details>
<summary>v2.1.0 Milestone (completed)</summary>

**Goal:** App-Architektur modernisieren, Hintergrund-Monitoring, Karten-Caching, @Observable-Migration

**Delivered:**
- DeviceInfoSection: Firmware, Host-Info, Memory, CPU, Robot Properties in einer DisclosureGroup
- BGAppRefreshTask für periodische Status-Prüfung mit lokalen Notifications
- MapCacheService für Offline-Karte mit automatischer Wiederherstellung
- Vollständige @Observable-Migration: 11 Klassen, 19 Views, 0 Legacy-Patterns
</details>

<details>
<summary>v2.0.0 Milestone (completed)</summary>

**Goal:** Update-Prozess robust machen — State Machine, Fullscreen-Lock, Reboot-Erkennung, Error-Banner

**Delivered:**
- UpdatePhase Enum (8 States) + UpdateService als @MainActor ObservableObject
- Re-Entrancy-Guards via State-Pattern-Matching (kein Doppelklick)
- Fullscreen-Lock Overlay während Apply/Rebooting
- Idle Timer Deaktivierung + Background Task Schutz
- Reboot-Erkennung (120s Polling, Netzwerkfehler ignoriert)
- Download-ProgressView mit Prozent + Error-Banner mit Retry
- Update-Check Throttling (1x/Stunde)
- Doppelte Properties und Check-Logik konsolidiert
</details>

<details>
<summary>v1.4.0 Milestone (completed)</summary>

**Goal:** Codebase sauber machen — print()-Migration, Force-Unwraps, Keychain-Fehlerbehandlung, View-Decomposition

**Delivered:**
- 30 print() → os.Logger in 8 Views + SupportManager
- Force-Unwrap in SettingsView eliminiert
- Keychain-Fehlerbehandlung mit OSStatus-Logging
- DispatchQueue → Task.sleep Migration
- Constants.swift für URLs/ProductIDs
- MapView: 2532 → 859 Zeilen (66% Reduktion)
- RobotSettingsView: 1801 → 502 Zeilen (72% Reduktion)
- RobotDetailView: Helper-Structs extrahiert
</details>

<details>
<summary>v1.3.0 Milestone (completed)</summary>

**Goal:** Phase-3-UI wiederherstellen, fehlende Valetudo-Capabilities nachrüsten, Concerns beheben, Test-Coverage erweitern

**Delivered:**
- UI-Features in ViewModels wiederhergestellt (Events, CleanRoute, Snapshots, Notifications, Obstacles)
- 4 neue Capabilities: VoicePack, AutoEmptyDuration, MopDockDrying, Robot Properties
- Force-unwraps eliminiert, stille Fehler durch Logger ersetzt, SSE Exponential Backoff
- Koordinaten-Rundungsfehler in MapView behoben
- 28 neue Unit-Tests (ViewModel + API-Layer)
</details>

## Context

- **Stack:** Swift 5.9, SwiftUI, iOS 17+, Zero externe Dependencies
- **Architektur:** MVVM mit ViewModels (@MainActor @Observable) + zentralem RobotManager
- **API:** Valetudo REST API v2, Basic Auth, optionales SSL
- **Persistenz:** UserDefaults + Keychain (Credentials) + FileManager (Map Cache), kein CoreData
- **Tests:** 57 Unit-Tests (ViewModel + API-Layer)
- **Version:** v2.1.0, Xcode 15+, XcodeGen
- **Lokalisierung:** Deutsch, Englisch, Französisch
- **Robot:** Primär getestet mit Roborock S5 Max

## Constraints

- **Platform:** iOS 17+ only, rein Apple-Frameworks
- **Network:** Lokales Netzwerk erforderlich (LAN-only)
- **API:** Valetudo REST API v2 -- kein MQTT in der App
- **Dependencies:** Zero externe Packages (bewusste Entscheidung)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Keine externen Dependencies | Weniger Wartung, kein Supply-Chain-Risiko | -- Pending |
| UserDefaults statt CoreData | Einfachheit, kleine Datenmengen | -- Revisit (Credentials sollten in Keychain) |
| Actor-basierte API | Thread-Safety bei concurrent requests | -- Good |
| XcodeGen | Merge-Konflikt-freie Projektkonfiguration | -- Good |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check -- still the right priority?
3. Audit Out of Scope -- reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-04 — Milestone v2.2.0 started*
