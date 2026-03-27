# ValetudiOS

## What This Is

Native iOS-App (SwiftUI) zur Steuerung von Valetudo-basierten Saugrobotern im lokalen Netzwerk. Bietet Roboter-Management, Live-Karte, Raumreinigung, Timer, manuelle Steuerung und Siri-Integration. Kommuniziert direkt mit der Valetudo REST API v2.

## Core Value

Zuverlässige, native iOS-Steuerung von Valetudo-Robotern ohne Cloud-Abhängigkeit.

## Requirements

### Validated

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

- [ ] Alle technischen Concerns bearbeiten (Credentials, Caching, ViewModels, Error-Handling, Debug-Prints)
- [ ] Valetudo API vollständig integrieren (fehlende Capabilities)
- [ ] Robot-Liste: Gesamte Zeile klickbar
- [ ] mDNS/Bonjour statt IP-Brute-Force
- [ ] Adaptive Polling / SSE
- [ ] Notification-Actions implementieren
- [ ] Test-Coverage aufbauen

### Out of Scope

- Multi-Floor-Support -- Valetudo unterstützt dies nicht offiziell, nur Workarounds via SSH
- Cloud-Anbindung -- Lokale Kommunikation ist Core Value
- Android-Version -- Nur iOS

## Current Milestone: v1.2.0 Quality & API Completeness

**Goal:** Technische Schulden abbauen, Valetudo API vollständig integrieren, UX-Verbesserungen

**Target features:**
- Alle Concerns aus Codebase-Analyse bearbeiten
- Neueste Valetudo API-Definition abrufen und fehlende Capabilities einbauen
- Robot-Liste: gesamte Zeile klickbar machen
- Notification-Actions implementieren (GO_HOME, LOCATE)
- mDNS/Bonjour statt IP-Brute-Force-Scan
- Adaptive Polling / SSE

## Context

- **Stack:** Swift 5.9, SwiftUI, iOS 17+, Zero externe Dependencies
- **Architektur:** MVVM-lite mit zentralem RobotManager als ObservableObject
- **API:** Valetudo REST API v2, Basic Auth, optionales SSL
- **Persistenz:** UserDefaults (kein Keychain, kein CoreData)
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
*Last updated: 2026-03-27 after milestone v1.2.0 initialization*
