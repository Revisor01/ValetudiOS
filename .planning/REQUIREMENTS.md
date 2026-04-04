# Requirements: ValetudiOS

**Defined:** 2026-04-04
**Core Value:** Zuverlässige, native iOS-Steuerung von Valetudo-Robotern ohne Cloud-Abhängigkeit

## v3.0.0 Requirements

Requirements for Quality, Performance & Hardening. Each maps to roadmap phases.

### Tech Debt Elimination

- [x] **DEBT-01**: `calculateMapParams` existiert nur einmal als zentrale Funktion — keine duplizierten Kopien in MapView, MapInteractiveView, MapMiniMapView oder MapViewModel
- [x] **DEBT-02**: Room-Selection-State (`selectedSegmentIds`) ist in einer einzigen Quelle zentralisiert — MapViewModel und RobotDetailViewModel lesen/schreiben denselben State
- [ ] **DEBT-03**: Kein `try?` mehr in benutzer-initierten Aktionen (join, split, rename, clean) — Fehler werden dem Benutzer angezeigt
- [ ] **DEBT-04**: DebugConfig maskiert keine API-Fehler mehr — Fehler werden immer geloggt, Debug-Flag steuert nur Mock-Daten
- [ ] **DEBT-05**: `isInitialLoad`-Pattern in RobotSettingsViewModel durch robusteres Two-Phase-Pattern ersetzt
- [ ] **DEBT-06**: Robot-Capabilities werden nach Firmware-Update automatisch neu geladen (Cache mit TTL oder Force-Refresh nach OTA)
- [ ] **DEBT-07**: StoreKit Product IDs sind konfigurierbar mit Runtime-Validierung

### Performance

- [ ] **PERF-01**: Map-Tap-Hit-Testing nutzt Spatial Lookup (Dictionary/Bounding Box) statt linearem Pixel-Scan — Tap-Response unter 16ms
- [ ] **PERF-02**: Map-Updates kommen via SSE-Stream statt HTTP-Polling — `streamMapLines()` API-Endpoint wird genutzt
- [ ] **PERF-03**: `segmentInfos()` wird pro Map-Update einmal berechnet und gecacht — nicht bei jedem Overlay-Render
- [ ] **PERF-04**: Statische Map-Layer (Floor, Walls, Segments) werden als CGImage vorgerendert — Canvas zeichnet nur dynamische Elemente pro Frame
- [ ] **PERF-05**: MapCacheService schreibt nur bei tatsächlicher Datenänderung auf Disk — nicht bei jedem Poll-Zyklus

### View Decomposition

- [ ] **VIEW-01**: RobotDetailView ist in eigenständige Section-Views aufgeteilt — keine Datei über 400 Zeilen
- [ ] **VIEW-02**: RobotSettingsSections.swift ist in einzelne Dateien pro Sub-View aufgeteilt (Settings/-Verzeichnis)
- [ ] **VIEW-03**: MapContentView-State ist in MapViewModel zentralisiert — Control Bars mutieren keinen View-State direkt
- [x] **VIEW-04**: Koordinaten-Transforms sind in einer einzigen, testbaren Utility zentralisiert — keine duplizierten Transforms

### Security

- [ ] **SEC-01**: Benutzer sieht eine Warnung wenn die Verbindung über HTTP (ohne SSL) läuft
- [ ] **SEC-02**: SSL-Zertifikat-Bypass zeigt eine deutliche Warnung in der Robot-Konfiguration
- [ ] **SEC-03**: Robot-Config (Host, Username) wird verschlüsselt gespeichert — nicht in unverschlüsseltem UserDefaults

### Accessibility

- [ ] **A11Y-01**: Alle Control-Buttons (Start, Stop, Home, Dock-Actions) haben `.accessibilityLabel` mit Aktionsbeschreibung
- [ ] **A11Y-02**: Status-Header (Batterie, Reinigungsstatus) hat `.accessibilityValue` für aktuellen Zustand
- [ ] **A11Y-03**: Consumable-Fortschrittsbalken haben `.accessibilityValue` mit Prozentangabe
- [ ] **A11Y-04**: Alle Icon-only-Buttons in der gesamten App haben beschreibende Accessibility-Labels
- [ ] **A11Y-05**: Map-Canvas hat ein `.accessibilityElement` Summary-Label; Raumauswahl ist alternativ über Liste möglich (bereits vorhanden)

### Test Coverage

- [ ] **TEST-01**: Koordinaten-Transforms (`screenToMapCoords`, `mapToScreenCoords`) und Hit-Test-Logik haben Unit-Tests
- [ ] **TEST-02**: UpdateService State-Machine-Transitions (alle 8 Phasen + Error-Recovery) haben Unit-Tests
- [ ] **TEST-03**: SSE-Reconnection-Logik (Backoff-Timing, Connection-State) hat Unit-Tests
- [ ] **TEST-04**: MapCacheService Save/Load-Zyklus und Corrupted-Cache-Handling haben Unit-Tests

### Robustness

- [ ] **ROBUST-01**: ErrorRouter ist systematisch in RobotDetailView und MapContentView für benutzer-initiierte Aktionen verdrahtet
- [ ] **ROBUST-02**: Destructive Actions (Stop während Reinigung, Consumable-Reset) haben Confirmation-Dialogs
- [ ] **ROBUST-03**: Multi-Robot-Polling ist optimiert — nur der aktive/sichtbare Roboter pollt die Map

## Out of Scope

| Feature | Reason |
|---------|--------|
| Metal-basierter Map-Renderer | Overkill für aktuelle Map-Komplexität — CGImage-Caching reicht |
| UI Tests (XCUITest) | Hoher Wartungsaufwand, Unit-Tests decken ViewModel-Logik ab |
| Certificate Pinning | Lokales Netzwerk, selbstsignierte Zertifikate üblich |
| CoreData Migration | UserDefaults + Keychain + FileManager reichen für aktuelle Datenmengen |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DEBT-01 | Phase 22 | Complete |
| DEBT-02 | Phase 22 | Complete |
| DEBT-03 | Phase 23 | Pending |
| DEBT-04 | Phase 23 | Pending |
| DEBT-05 | Phase 23 | Pending |
| DEBT-06 | Phase 23 | Pending |
| DEBT-07 | Phase 23 | Pending |
| PERF-01 | Phase 24 | Pending |
| PERF-02 | Phase 24 | Pending |
| PERF-03 | Phase 24 | Pending |
| PERF-04 | Phase 24 | Pending |
| PERF-05 | Phase 24 | Pending |
| VIEW-01 | Phase 25 | Pending |
| VIEW-02 | Phase 25 | Pending |
| VIEW-03 | Phase 25 | Pending |
| VIEW-04 | Phase 22 | Complete |
| SEC-01 | Phase 26 | Pending |
| SEC-02 | Phase 26 | Pending |
| SEC-03 | Phase 26 | Pending |
| A11Y-01 | Phase 27 | Pending |
| A11Y-02 | Phase 27 | Pending |
| A11Y-03 | Phase 27 | Pending |
| A11Y-04 | Phase 27 | Pending |
| A11Y-05 | Phase 27 | Pending |
| TEST-01 | Phase 28 | Pending |
| TEST-02 | Phase 28 | Pending |
| TEST-03 | Phase 28 | Pending |
| TEST-04 | Phase 28 | Pending |
| ROBUST-01 | Phase 29 | Pending |
| ROBUST-02 | Phase 29 | Pending |
| ROBUST-03 | Phase 29 | Pending |

**Coverage:**
- v3.0.0 requirements: 31 total
- Mapped to phases: 31
- Unmapped: 0

---
*Requirements defined: 2026-04-04*
