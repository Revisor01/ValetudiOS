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

### Active

<!-- v2.0.0 — Update Process Hardening -->
(Defined in REQUIREMENTS.md)

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

## Current Milestone: v2.0.0 Update Process Hardening

**Goal:** Den Firmware-Update-Prozess des Roboters robust und fehlerfrei machen — kein Doppelklick, klare Zustandsanzeige, Fehlerfeedback, Schutz während kritischer Phasen.

**Target features:**
- Zustandsmaschine für den Update-Lifecycle (Idle → Checking → Download → Ready → Applying → Done/Error)
- Doppelklick-Schutz und UI-Lock während kritischer Phasen (Download/Apply)
- Error-State-Handling mit User-Feedback (Download-Fehler, Apply-Fehler)
- Konsolidierung der doppelten Update-Logik (eine Source of Truth)
- Dead-Code-Bereinigung (ungenutzte Properties)
- Intelligenteres Update-Checking (nicht bei jedem View-Erscheinen)
- Apply-Phase: Vollbild-Lock oder Modal, das nicht weggeklickt werden kann

## Current State

**Shipped:** v1.4.0 (2026-03-29)
**Version:** 1.4.0 — Code Quality & Robustness

Die App hat vollständige Valetudo API-Abdeckung mit capability-gated UI, MVVM-Architektur mit 3 ViewModels, SSE-Echtzeit-Updates, mDNS-Discovery, 57 Unit-Tests, robustes Error-Handling, durchgängiges os.Logger-Logging, zentralisierte Constants, und aufgeräumte View-Struktur.

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
- **Architektur:** MVVM mit ViewModels (@MainActor ObservableObject) + zentralem RobotManager
- **API:** Valetudo REST API v2, Basic Auth, optionales SSL
- **Persistenz:** UserDefaults + Keychain (Credentials), kein CoreData
- **Tests:** Keine vorhanden
- **Version:** v1.1.0 (App Store), Xcode 15+, XcodeGen
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
*Last updated: 2026-03-29 — Milestone v2.0.0 started*
