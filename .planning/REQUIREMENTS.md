# Requirements: ValetudiOS

**Defined:** 2026-04-01
**Core Value:** Zuverlässige, native iOS-Steuerung von Valetudo-Robotern ohne Cloud-Abhängigkeit

## v2.1.0 Requirements

Requirements for App Architecture & Background Capabilities. Each maps to roadmap phases.

### UI Reorganization

- [ ] **REORG-01**: ValetudoInfoView (Firmware, Commit, Host-Info, Memory, Uptime) wird von den Einstellungen in den Roboter-Detail-Screen verschoben
- [ ] **REORG-02**: Die Robot Properties Section und ValetudoInfoView werden zu einer einheitlichen Geräte-Info-Sektion zusammengeführt

### Background Monitoring

- [ ] **BG-01**: BGAppRefreshTask prüft periodisch den Roboter-Status im Hintergrund
- [ ] **BG-02**: Lokale Notification bei Reinigungsende auch wenn die App geschlossen ist
- [ ] **BG-03**: Lokale Notification bei Fehlern (Roboter steckt fest, Staubbehälter voll) auch im Hintergrund

### Map Caching

- [ ] **CACHE-01**: Die letzte Karte jedes Roboters wird auf Disk gespeichert
- [ ] **CACHE-02**: Gespeicherte Karte wird angezeigt wenn der Roboter nicht erreichbar ist
- [ ] **CACHE-03**: Karte wird automatisch aktualisiert sobald Verbindung wieder steht

### Observable Migration

- [x] **OBS-01**: Alle ViewModels migrieren von ObservableObject/@Published zu @Observable Macro
- [x] **OBS-02**: RobotManager migriert zu @Observable
- [x] **OBS-03**: UpdateService migriert zu @Observable
- [x] **OBS-04**: Alle @StateObject/@ObservedObject Referenzen werden durch @State/@Environment ersetzt

## Out of Scope

| Feature | Reason |
|---------|--------|
| WiFi-Rekonfiguration | Bereits implementiert (WifiSettingsView) |
| MQTT in-App | SSE erreicht dasselbe ohne Broker-Konfiguration |
| Multi-Floor Map Management | Valetudo unterstützt dies nicht offiziell |
| Cloud-Anbindung | Lokale Kommunikation ist Core Value |
| Android-Version | Nur iOS |
| Changelog in der App | Valetudo Release Notes sind auf GitHub ausreichend |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| REORG-01 | Phase 16 | Pending |
| REORG-02 | Phase 16 | Pending |
| BG-01 | Phase 17 | Pending |
| BG-02 | Phase 17 | Pending |
| BG-03 | Phase 17 | Pending |
| CACHE-01 | Phase 18 | Pending |
| CACHE-02 | Phase 18 | Pending |
| CACHE-03 | Phase 18 | Pending |
| OBS-01 | Phase 19 | Complete |
| OBS-02 | Phase 19 | Complete |
| OBS-03 | Phase 19 | Complete |
| OBS-04 | Phase 19 | Complete |

**Coverage:**
- v2.1.0 requirements: 12 total
- Mapped to phases: 12
- Unmapped: 0

---
*Requirements defined: 2026-04-01*
