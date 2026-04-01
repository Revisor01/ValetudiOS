# Requirements: ValetudiOS

**Defined:** 2026-03-29
**Core Value:** Zuverlässige, native iOS-Steuerung von Valetudo-Robotern ohne Cloud-Abhängigkeit

## v2.0.0 Requirements

Requirements for Update Process Hardening. Each maps to roadmap phases.

### State Machine & Guards

- [x] **STATE-01**: Update-Zustand wird als enum-basierte State Machine modelliert (Idle, Checking, Downloading, ReadyToApply, Applying, Rebooting, Error)
- [x] **STATE-02**: startUpdate() hat einen Re-Entrancy-Guard — Doppelaufruf wird verhindert
- [x] **STATE-03**: Valetudo ErrorState wird im Model abgebildet und zeigt Fehlermeldung an
- [x] **STATE-04**: Ein zentraler UpdateService ist die einzige Source of Truth für Update-Zustand (statt ViewModel + View doppelt)

### Apply-Phase Hardening

- [x] **APPLY-01**: Während der Apply-Phase wird ein Fullscreen-Lock angezeigt, der nicht weggeklickt werden kann
- [x] **APPLY-02**: Bildschirm bleibt während Download und Apply an (Idle Timer deaktiviert)
- [x] **APPLY-03**: Nach Apply wird der Roboter-Neustart erkannt und nicht als Fehler gewertet
- [x] **APPLY-04**: UIBackgroundTask verhindert Abbruch bei App-Hintergrund während Apply

### UI & Feedback

- [ ] **UI-01**: Download-Fortschritt wird aus metaData.progress als ProgressView angezeigt
- [ ] **UI-02**: Fehlermeldungen bei Update-Problemen werden sichtbar als Banner angezeigt
- [ ] **UI-03**: Update-Check wird auf max. 1x/Stunde gedrosselt statt bei jedem View-Erscheinen

### Code Cleanup

- [x] **CLEAN-01**: Ungenutzte isUpdating/showUpdateWarning Properties werden aus dem ViewModel entfernt
- [x] **CLEAN-02**: Doppelte Update-Check-Logik in ValetudoInfoView wird entfernt und an UpdateService angebunden

## v1.4.0 Requirements (Completed)

### Logging & Diagnostics

- [x] **LOG-01**: Alle print()-Aufrufe in View-Dateien sind durch os.Logger ersetzt
- [x] **LOG-02**: SupportManager.swift print() durch os.Logger ersetzen
- [x] **LOG-03**: Alle Views mit print()-Aufrufen haben eine private Logger-Property

### Safety & Error Handling

- [x] **SAFE-01**: Force-Unwrap in SettingsView.swift eliminiert
- [x] **SAFE-02**: KeychainStore.swift prüft SecItemDelete/SecItemAdd Return-Status
- [x] **SAFE-03**: SupportReminderView nutzt Task.sleep statt DispatchQueue

### Code Organization

- [x] **ORG-01**: Hardcoded URLs in zentrale Constants extrahiert
- [x] **ORG-02**: MapView in logische Sub-Views aufgebrochen
- [x] **ORG-03**: RobotSettingsView in Section-Views aufgebrochen
- [x] **ORG-04**: RobotDetailView in Section-Views aufgebrochen

## v1.3.0 Requirements (Completed)

- [x] **UIR-01** – **UIR-06**: UI Restore (Events, CleanRoute, Snapshots, PendingMap, Obstacles, Notifications)
- [x] **CAP-01** – **CAP-04**: Neue Capabilities (VoicePack, AutoEmpty, MopDock, Properties)
- [x] **FIX-01** – **FIX-04**: Bugfixes (Force-unwrap, stille Fehler, SSE Backoff, Koordinaten)
- [x] **TEST-01** – **TEST-02**: Test Coverage (ViewModel + API)

## v1.2.0 Requirements (Completed)

- [x] **UX-01** – **UX-04**: UX (klickbare Zeilen, Fehlermeldungen, Notification-Actions, Events)
- [x] **NET-01** – **NET-03**: Netzwerk (SSE, mDNS, Keychain)
- [x] **API-01** – **API-04**: API Capabilities (Snapshots, Map-Changes, CleanRoute, Obstacles)
- [x] **DEBT-01** – **DEBT-04**: Tech Debt (Logger, ViewModels, Caching, Tests)

## Future Requirements

### Post-v2.0.0

- **UPDATE-F01**: Update-Changelog/Release-Notes in der App anzeigen
- **UPDATE-F02**: Automatische Update-Benachrichtigung via Local Notification
- **UPDATE-F03**: Update-Historie pro Roboter anzeigen
- **EXT-01**: Background-Monitoring via BGAppRefreshTask
- **EXT-02**: WiFi-Rekonfiguration in-App
- **EXT-03**: Map-Caching auf Disk (Offline-Zugriff)
- **EXT-04**: @Observable Migration

## Out of Scope

| Feature | Reason |
|---------|--------|
| Download-Cancel-Button | Valetudo API hat keine Cancel-Action — technisch nicht umsetzbar |
| Automatisches Update ohne Bestätigung | Zu riskant bei Firmware — User muss immer bestätigen |
| Multi-Floor Map Management | Valetudo unterstützt dies nicht offiziell |
| MQTT in-App | SSE erreicht dasselbe ohne Broker-Konfiguration |
| Cloud-Anbindung | Lokale Kommunikation ist Core Value |
| Android-Version | Nur iOS |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| STATE-01 | Phase 12 | Complete |
| STATE-02 | Phase 12 | Complete |
| STATE-03 | Phase 12 | Complete |
| STATE-04 | Phase 12 | Complete |
| CLEAN-01 | Phase 13 | Complete |
| CLEAN-02 | Phase 13 | Complete |
| APPLY-01 | Phase 14 | Complete |
| APPLY-02 | Phase 14 | Complete |
| APPLY-03 | Phase 14 | Complete |
| APPLY-04 | Phase 14 | Complete |
| UI-01 | Phase 15 | Pending |
| UI-02 | Phase 15 | Pending |
| UI-03 | Phase 15 | Pending |

**Coverage:**
- v2.0.0 requirements: 13 total
- Mapped to phases: 13
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-29*
*Last updated: 2026-03-29 — Traceability mapped to Phases 12-15*
