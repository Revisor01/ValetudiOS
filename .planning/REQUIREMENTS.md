# Requirements: ValetudiOS

**Defined:** 2026-03-27
**Core Value:** Zuverlässige, native iOS-Steuerung von Valetudo-Robotern ohne Cloud-Abhängigkeit

## v1.2.0 Requirements

Requirements for milestone v1.2.0: Quality & API Completeness.

### UX

- [ ] **UX-01**: Robot-Zeile in der Liste ist vollständig klickbar
- [ ] **UX-02**: Benutzer sieht Fehlermeldungen bei fehlgeschlagenen Aktionen (statt stiller Fehler)
- [ ] **UX-03**: Notification-Actions GO_HOME und LOCATE führen die jeweilige Aktion aus
- [ ] **UX-04**: Benutzer kann Valetudo Events einsehen (DustBinFull, MopReminder, Errors etc.)

### Netzwerk

- [ ] **NET-01**: App nutzt SSE-Streams für Echtzeit-State-Updates statt 5s-Polling
- [ ] **NET-02**: App findet Roboter via mDNS/Bonjour (mit IP-Scan-Fallback)
- [ ] **NET-03**: Credentials werden im iOS Keychain gespeichert (Migration aus UserDefaults)

### API Capabilities

- [ ] **API-01**: Benutzer kann Map-Snapshots erstellen und wiederherstellen
- [ ] **API-02**: Benutzer kann ausstehende Kartenänderungen akzeptieren/ablehnen
- [ ] **API-03**: Benutzer kann Reinigungsroute wählen (Standard, Bow-Tie, Spiral etc.)
- [ ] **API-04**: Benutzer kann Fotos erkannter Hindernisse ansehen

### Tech Debt

- [ ] **DEBT-01**: Alle print()-Aufrufe durch os.Logger ersetzt, Debug-Output nur in DEBUG-Builds
- [ ] **DEBT-02**: MapView, RobotDetailView, RobotSettingsView in ViewModels + Sub-Views aufgeteilt
- [ ] **DEBT-03**: Map-Pixel-Dekompression wird gecacht statt bei jedem Render neu berechnet
- [ ] **DEBT-04**: XCTest-Target mit Tests für Timer, Consumable, MapLayer

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Extended Capabilities

- **EXT-01**: VoicePackManagement (Sprachpakete herunterladen/ändern)
- **EXT-02**: AutoEmptyDock Duration Control
- **EXT-03**: MopDock Drying Time Control
- **EXT-04**: Robot Properties Endpoint anzeigen (Modelldetails, Quirk-Info)
- **EXT-05**: Background-Monitoring via BGAppRefreshTask
- **EXT-06**: WiFi-Rekonfiguration in-App

## Out of Scope

| Feature | Reason |
|---------|--------|
| Multi-Floor Map Management | Valetudo unterstützt dies nicht offiziell, nur Workarounds via SSH |
| MQTT in-App | Valetudo SSE erreicht dasselbe ohne Broker-Konfiguration |
| Cloud-Anbindung | Lokale Kommunikation ist Core Value |
| Android-Version | Nur iOS |
| Valetudo-Update in-App | Reboot während Update bricht Verbindung; Link zu Web UI stattdessen |
| @Observable Migration | Zu riskant ohne Test-Coverage; erst nach DEBT-04 evaluieren |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| UX-01 | Phase 1 | Pending |
| UX-02 | Phase 1 | Pending |
| UX-03 | Phase 3 | Pending |
| UX-04 | Phase 3 | Pending |
| NET-01 | Phase 2 | Pending |
| NET-02 | Phase 2 | Pending |
| NET-03 | Phase 1 | Pending |
| API-01 | Phase 3 | Pending |
| API-02 | Phase 3 | Pending |
| API-03 | Phase 3 | Pending |
| API-04 | Phase 3 | Pending |
| DEBT-01 | Phase 1 | Pending |
| DEBT-02 | Phase 4 | Pending |
| DEBT-03 | Phase 2 | Pending |
| DEBT-04 | Phase 4 | Pending |

**Coverage:**
- v1.2.0 requirements: 15 total
- Mapped to phases: 15
- Unmapped: 0

---
*Requirements defined: 2026-03-27*
*Last updated: 2026-03-27 after roadmap creation — all 15 requirements mapped*
