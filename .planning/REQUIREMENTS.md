# Requirements: ValetudiOS

**Defined:** 2026-03-28
**Core Value:** Zuverlässige, native iOS-Steuerung von Valetudo-Robotern ohne Cloud-Abhängigkeit

## v1.4.0 Requirements

Requirements for milestone v1.4.0: Code Quality & Robustness.

### Logging & Diagnostics

- [ ] **LOG-01**: Alle print()-Aufrufe in View-Dateien sind durch os.Logger ersetzt (DoNotDisturbView, StatisticsView, IntensityControlView, MapView, ManualControlView, RoomsManagementView, TimersView)
- [ ] **LOG-02**: SupportManager.swift print() durch os.Logger ersetzen
- [ ] **LOG-03**: Alle Views mit print()-Aufrufen haben eine private Logger-Property

### Safety & Error Handling

- [ ] **SAFE-01**: Force-Unwrap in SettingsView.swift eliminiert durch nil-coalescing/optional binding
- [ ] **SAFE-02**: KeychainStore.swift prüft SecItemDelete/SecItemAdd Return-Status und loggt Fehler
- [ ] **SAFE-03**: SupportReminderView nutzt Task.sleep statt DispatchQueue.main.asyncAfter

### Code Organization

- [ ] **ORG-01**: Hardcoded GitHub-API-URLs in RobotDetailViewModel und RobotSettingsView in zentrale Constants extrahieren
- [ ] **ORG-02**: MapView (2532 Zeilen) in logische Sub-Views aufbrechen (MiniMap, Controls, Drawing-Helpers)
- [ ] **ORG-03**: RobotSettingsView (1801 Zeilen) in Section-Views aufbrechen
- [ ] **ORG-04**: RobotDetailView (1253 Zeilen) in Section-Views aufbrechen

## v1.3.0 Requirements (Completed)

### UI Restore

- [x] **UIR-01**: Events-Section in RobotDetailView zeigt Valetudo-Events chronologisch mit Dismiss-Button
- [x] **UIR-02**: CleanRoute-Picker in RobotDetailView erlaubt Auswahl der Reinigungsroute (capability-gated)
- [x] **UIR-03**: Map-Snapshots Section in RobotSettingsView zeigt Liste und ermöglicht Restore (capability-gated)
- [x] **UIR-04**: Pending-Map-Change Section in RobotSettingsView erlaubt Accept/Reject (capability-gated)
- [x] **UIR-05**: Obstacle-Photos Section in RobotDetailView mit Navigation zu ObstaclePhotoView (capability-gated)
- [x] **UIR-06**: Notification-Actions GO_HOME und LOCATE funktionieren (AppDelegate + Handler)

### Neue Capabilities

- [x] **CAP-01**: Benutzer kann Sprachpakete des Roboters verwalten (VoicePackManagementCapability)
- [x] **CAP-02**: Benutzer kann Absaugdauer der Auto-Empty-Station steuern
- [x] **CAP-03**: Benutzer kann Trocknungszeit der Mop-Station steuern
- [x] **CAP-04**: Benutzer sieht Robot-Properties (Modell, Firmware, Seriennummer)

### Bugfixes & Robustness

- [x] **FIX-01**: Force-unwrap URLs durch sichere optionale Bindung ersetzen
- [x] **FIX-02**: Stille Fehler durch ErrorRouter-Alerts oder Logger-Warnungen ersetzen
- [x] **FIX-03**: SSE-Reconnect mit Exponential Backoff (1s → 5s → 30s)
- [x] **FIX-04**: Koordinaten-Transformation in MapView (Rundungsfehler) behoben

### Test Coverage

- [x] **TEST-01**: ViewModel-Unit-Tests
- [x] **TEST-02**: ValetudoAPI-Tests

## v1.2.0 Requirements (Completed)

### UX
- [x] **UX-01**: Robot-Zeile in der Liste ist vollständig klickbar
- [x] **UX-02**: Benutzer sieht Fehlermeldungen bei fehlgeschlagenen Aktionen
- [x] **UX-03**: Notification-Actions GO_HOME und LOCATE führen die jeweilige Aktion aus
- [x] **UX-04**: Benutzer kann Valetudo Events einsehen

### Netzwerk
- [x] **NET-01**: App nutzt SSE-Streams für Echtzeit-State-Updates
- [x] **NET-02**: App findet Roboter via mDNS/Bonjour
- [x] **NET-03**: Credentials werden im iOS Keychain gespeichert

### API Capabilities
- [x] **API-01**: Benutzer kann Map-Snapshots erstellen und wiederherstellen
- [x] **API-02**: Benutzer kann ausstehende Kartenänderungen akzeptieren/ablehnen
- [x] **API-03**: Benutzer kann Reinigungsroute wählen
- [x] **API-04**: Benutzer kann Fotos erkannter Hindernisse ansehen

### Tech Debt
- [x] **DEBT-01**: Alle print()-Aufrufe durch os.Logger ersetzt
- [x] **DEBT-02**: MapView, RobotDetailView, RobotSettingsView in ViewModels aufgeteilt
- [x] **DEBT-03**: Map-Pixel-Dekompression wird gecacht
- [x] **DEBT-04**: XCTest-Target mit Unit-Tests

## v2 Requirements (Deferred)

- **EXT-01**: Background-Monitoring via BGAppRefreshTask
- **EXT-02**: WiFi-Rekonfiguration in-App
- **EXT-03**: Map-Caching auf Disk (Offline-Zugriff)
- **EXT-04**: @Observable Migration (nach ausreichender Test-Coverage)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Multi-Floor Map Management | Valetudo unterstützt dies nicht offiziell |
| MQTT in-App | SSE erreicht dasselbe ohne Broker-Konfiguration |
| Cloud-Anbindung | Lokale Kommunikation ist Core Value |
| Android-Version | Nur iOS |
| Valetudo-Update in-App | Reboot bricht Verbindung; Link zu Web UI |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| LOG-01 | TBD | Pending |
| LOG-02 | TBD | Pending |
| LOG-03 | TBD | Pending |
| SAFE-01 | TBD | Pending |
| SAFE-02 | TBD | Pending |
| SAFE-03 | TBD | Pending |
| ORG-01 | TBD | Pending |
| ORG-02 | TBD | Pending |
| ORG-03 | TBD | Pending |
| ORG-04 | TBD | Pending |

**Coverage:**
- v1.4.0 requirements: 10 total
- Mapped to phases: 0
- Unmapped: 10 ⚠️

---
*Requirements defined: 2026-03-28*
*Last updated: 2026-03-28 after milestone v1.4.0 definition*
