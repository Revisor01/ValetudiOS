# Requirements: ValetudiOS

**Defined:** 2026-04-05
**Core Value:** Zuverlässige, native iOS-Steuerung von Valetudo-Robotern ohne Cloud-Abhängigkeit

## v4.0.0 Requirements

Requirements for App Store Release. Each maps to roadmap phases.

### Web-Präsenz

- [ ] **WEB-01**: Privacy Policy auf simonluthe.de/apps/valetudios/datenschutz/ ist DSGVO + Apple-konform, nennt LAN-Kommunikation, Keychain-Speicherung, SSE-Streaming, keine Analytics, keine Cloud
- [ ] **WEB-02**: Attraktive App-Beschreibung auf simonluthe.de/apps/valetudios/ mit Features, Download-Link-Platzhalter und Links zu Datenschutz/Impressum

### App Store Listing

- [ ] **STORE-01**: App Store Titel, Untertitel und Beschreibungstext in Deutsch und Englisch
- [ ] **STORE-02**: Keywords-Liste für App Store Connect (DE + EN, max 100 Zeichen je Sprache)
- [ ] **STORE-03**: App Review Notes mit Testhinweisen für Apple (LAN-only, Valetudo-Server nötig)
- [ ] **STORE-04**: Screenshots-Anleitung (welche Screens, welche Geräte, welche Zustände)

### Bug-Fixes

- [ ] **FIX-01**: Support-Symbol (Taube) wird in SupportView korrekt angezeigt — identischer Fix wie in Steadflow
- [ ] **FIX-02**: SSE-Verbindung erkennt Netzwerk-Wechsel (WiFi→VPN, LAN→LTE) und reconnectet statt Zombie-Socket zu halten

## Out of Scope

| Feature | Reason |
|---------|--------|
| Eigener Analytics-SDK | Keine Tracking — Privacy ist Core Value |
| App Store Screenshots automatisiert | Manuell schneller für v1, Fastlane Snapshots erst bei Bedarf |
| TestFlight Beta | Direkt in Review, keine Beta-Phase nötig |
| Konfi Quest App-Seite | Wird manuell oder von eigenem Agent befüllt |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| FIX-01 | Phase 30 | Pending |
| FIX-02 | Phase 30 | Pending |
| WEB-01 | Phase 31 | Pending |
| WEB-02 | Phase 31 | Pending |
| STORE-01 | Phase 32 | Pending |
| STORE-02 | Phase 32 | Pending |
| STORE-03 | Phase 32 | Pending |
| STORE-04 | Phase 32 | Pending |

**Coverage:**
- v4.0.0 requirements: 8 total
- Mapped to phases: 8/8 (100%)

---
*Requirements defined: 2026-04-05*
