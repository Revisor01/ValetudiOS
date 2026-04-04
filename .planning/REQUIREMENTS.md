# Requirements: ValetudiOS

**Defined:** 2026-04-04
**Core Value:** Zuverlässige, native iOS-Steuerung von Valetudo-Robotern ohne Cloud-Abhängigkeit

## v2.2.0 Requirements

Requirements for Room Interaction & Cleaning Order. Each maps to roadmap phases.

### Reinigungsreihenfolge

- [ ] **ROOM-01**: Beim Auswählen der Räume erscheinen Zahlen 1, 2, 3 auf der Karte über den Räumen — die Auswahl-Reihenfolge definiert die Reinigungsreihenfolge
- [x] **ROOM-02**: Die definierte Reihenfolge wird beim Start der Raumreinigung an die Valetudo API übergeben

### Raumauswahl

- [ ] **TAP-01**: Benutzer kann einen Raum durch Tap auf die Raumfläche auswählen, nicht nur durch Tap auf das Label
- [ ] **TAP-02**: Die Tap-auf-Fläche-Auswahl funktioniert auch wenn Raum-Labels ausgeblendet sind

## Out of Scope

| Feature | Reason |
|---------|--------|
| Drag & Drop Reihenfolge | Auswahl-Reihenfolge ist einfacher und intuitiver |
| Gespeicherte Reinigungsreihenfolgen | Kann in späterem Milestone kommen |
| Multi-Floor Map Management | Valetudo unterstützt dies nicht offiziell |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TAP-01 | Phase 20 | Pending |
| TAP-02 | Phase 20 | Pending |
| ROOM-01 | Phase 21 | Pending |
| ROOM-02 | Phase 21 | Complete |

**Coverage:**
- v2.2.0 requirements: 4 total
- Mapped to phases: 4
- Unmapped: 0

---
*Requirements defined: 2026-04-04*
