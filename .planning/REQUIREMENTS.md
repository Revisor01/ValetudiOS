# Requirements: ValetudiOS

**Defined:** 2026-03-28
**Core Value:** Zuverlässige, native iOS-Steuerung von Valetudo-Robotern ohne Cloud-Abhängigkeit

## v1.3.0 Requirements

Requirements for milestone v1.3.0: Polish & Full API Coverage.

### UI Restore

- [x] **UIR-01**: Events-Section in RobotDetailView zeigt Valetudo-Events chronologisch mit Dismiss-Button
- [x] **UIR-02**: CleanRoute-Picker in RobotDetailView erlaubt Auswahl der Reinigungsroute (capability-gated)
- [x] **UIR-03**: Map-Snapshots Section in RobotSettingsView zeigt Liste und ermöglicht Restore (capability-gated)
- [x] **UIR-04**: Pending-Map-Change Section in RobotSettingsView erlaubt Accept/Reject (capability-gated)
- [x] **UIR-05**: Obstacle-Photos Section in RobotDetailView mit Navigation zu ObstaclePhotoView (capability-gated)
- [x] **UIR-06**: Notification-Actions GO_HOME und LOCATE funktionieren (AppDelegate + Handler)

### Neue Capabilities

- [x] **CAP-01**: Benutzer kann Sprachpakete des Roboters verwalten (VoicePackManagementCapability)
- [x] **CAP-02**: Benutzer kann Absaugdauer der Auto-Empty-Station steuern (AutoEmptyDockAutoEmptyDurationControlCapability)
- [ ] **CAP-03**: Benutzer kann Trocknungszeit der Mop-Station steuern (MopDockMopDryingTimeControlCapability)
- [x] **CAP-04**: Benutzer sieht Robot-Properties (Modell, Firmware, Seriennummer) via /api/v2/robot/properties

### Bugfixes & Robustness

- [ ] **FIX-01**: Force-unwrap URLs durch sichere optionale Bindung ersetzen (NetworkScanner, RobotDetailView)
- [ ] **FIX-02**: Stille Fehler in ViewModels/Services durch ErrorRouter-Alerts oder Logger-Warnungen ersetzen
- [x] **FIX-03**: SSE-Reconnect mit Exponential Backoff (1s → 5s → 30s) statt fester 30s-Wartezeit
- [ ] **FIX-04**: Koordinaten-Transformation in MapView (Float→Int Rundungsfehler bei Zonen/GoTo) beheben

### Test Coverage

- [ ] **TEST-01**: ViewModel-Unit-Tests (RobotDetailViewModel, RobotSettingsViewModel, MapViewModel State-Transitions)
- [ ] **TEST-02**: ValetudoAPI-Tests (Request/Response Encoding, Error-Handling, HTTP-Statuscodes)

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
| UIR-01 | Phase 5 | Complete |
| UIR-02 | Phase 5 | Complete |
| UIR-03 | Phase 5 | Complete |
| UIR-04 | Phase 5 | Complete |
| UIR-05 | Phase 5 | Complete |
| UIR-06 | Phase 5 | Complete |
| CAP-01 | Phase 6 | Complete |
| CAP-02 | Phase 6 | Complete |
| CAP-03 | Phase 6 | Pending |
| CAP-04 | Phase 6 | Complete |
| FIX-01 | Phase 7 | Pending |
| FIX-02 | Phase 7 | Pending |
| FIX-03 | Phase 7 | Complete |
| FIX-04 | Phase 7 | Pending |
| TEST-01 | Phase 8 | Pending |
| TEST-02 | Phase 8 | Pending |
