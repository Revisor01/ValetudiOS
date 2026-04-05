---
phase: 21-cleaning-order
verified: 2026-04-04T14:00:00Z
status: human_needed
score: 7/7 must-haves verified (automated)
human_verification:
  - test: "Badge-Visualisierung im Simulator"
    expected: "Blaue Badges (1, 2, 3) erscheinen über ausgewählten Räumen, Abwählen nummeriert lückenlos um, keine Badges im roomEdit-Modus"
    why_human: "Visuelles Rendering und SwiftUI Layout können nicht per grep verifiziert werden — Badge-Position und Darstellung nur im laufenden Simulator prüfbar"
---

# Phase 21: Cleaning Order — Verification Report

**Phase Goal:** Die Auswahlreihenfolge der Räume wird als Reinigungsreihenfolge auf der Karte visualisiert und beim Start an die Valetudo API übergeben
**Verified:** 2026-04-04T14:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `selectedSegmentIds` in MapViewModel ist `[String]` | ✓ VERIFIED | Zeile 47: `var selectedSegmentIds: [String] = []` |
| 2 | `selectedSegments` in RobotDetailViewModel ist `[String]` | ✓ VERIFIED | Zeile 18: `var selectedSegments: [String] = []` |
| 3 | Reihenfolge bleibt beim API-Call erhalten — Array direkt übergeben | ✓ VERIFIED | MapViewModel Z.195: `cleanSegments(ids: selectedSegmentIds, ...)` ohne Array()-Wrapper |
| 4 | Alle insert/remove Set-Operationen ersetzt | ✓ VERIFIED | `append(id)` + `removeAll(where: { $0 == id })` in beiden ViewModels und MapInteractiveView |
| 5 | Keine `Array()` Wrapper mehr vorhanden | ✓ VERIFIED | Grep über alle 4 relevanten Dateien ergibt 0 Treffer |
| 6 | `orderBadgesOverlay` zeigt nummerierte Badges (1, 2, 3) | ✓ VERIFIED | Z.188-214: `ForEach(Array(selectedSegmentIds.enumerated()), id: \.element) { index, segmentId in` + `Text("\(index + 1)")` |
| 7 | Badges unabhängig von showRoomLabels, nur im `.none` editMode | ✓ VERIFIED | Eigenes `.overlay { orderBadgesOverlay }` außerhalb des `if showRoomLabels`-Blocks; Guard: `if editMode == .none` |

**Score:** 7/7 truths verified (automated)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift` | `var selectedSegmentIds: [String] = []` | ✓ VERIFIED | Zeile 47 — korrekte Deklaration |
| `ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift` | `var selectedSegments: [String] = []` | ✓ VERIFIED | Zeile 18 — korrekte Deklaration |
| `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift` | `@Binding var selectedSegmentIds: [String]` + `orderBadgesOverlay` | ✓ VERIFIED | Z.7 Binding, Z.135 Aufruf, Z.188 Definition |
| `ValetudoApp/ValetudoApp/Views/MapControlBarsView.swift` | Kein `Array()` Wrapper | ✓ VERIFIED | Z.346: `viewModel.joinRooms(ids: viewModel.selectedSegmentIds)` ohne Wrapper |
| `ValetudoApp/ValetudoApp/Models/RobotState.swift` | `customOrder: Bool?` Feld in SegmentCleanRequest | ✓ VERIFIED | Z.76: `let customOrder: Bool?` |
| `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift` | `cleanSegments(ids:iterations:customOrder:)` | ✓ VERIFIED | Z.192: Parameter vorhanden |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `MapInteractiveView.toggleSegment` | `MapViewModel.selectedSegmentIds` | `@Binding` + `append` | ✓ WIRED | Z.221-223: `removeAll(where:)` / `append(id)` |
| `MapViewModel.cleanSelectedRooms` | `ValetudoAPI.cleanSegments` | direct array pass | ✓ WIRED | Z.195: `cleanSegments(ids: selectedSegmentIds, ..., customOrder: selectedSegmentIds.count > 1)` |
| `RobotDetailViewModel.cleanSelectedRooms` | `ValetudoAPI.cleanSegments` | direct array pass | ✓ WIRED | Z.342: `cleanSegments(ids: selectedSegments, ..., customOrder: selectedSegments.count > 1)` |
| `orderBadgesOverlay` | `selectedSegmentIds` | `enumerated()` für Index+1 | ✓ WIRED | Z.198: `ForEach(Array(selectedSegmentIds.enumerated()), id: \.element)` |
| `orderBadgesOverlay` | `segmentInfos` | `midX`/`midY` für Positionierung | ✓ WIRED | Z.199-201: `info.midX`, `info.midY` für Badge-Position |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `orderBadgesOverlay` | `selectedSegmentIds` | User-Tap via `toggleSegment` → `append` | Ja — Array wächst durch User-Interaktion | ✓ FLOWING |
| `cleanSegments` API-Call | `selectedSegmentIds` / `selectedSegments` | Direkt aus Array ohne Wrapper | Ja — kein statisches Return | ✓ FLOWING |
| `customOrder` Flag | `selectedSegmentIds.count > 1` | Anzahl ausgewählter Räume | Ja — berechnet aus Live-Array | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `[String]` statt `Set<String>` in MapViewModel | `grep "var selectedSegmentIds: \[String\]" MapViewModel.swift` | 1 Treffer | ✓ PASS |
| `[String]` statt `Set<String>` in RobotDetailViewModel | `grep "var selectedSegments: \[String\]" RobotDetailViewModel.swift` | 1 Treffer | ✓ PASS |
| Kein `Array()` Wrapper | grep über 4 Dateien | 0 Treffer | ✓ PASS |
| `orderBadgesOverlay` Definition + Aufruf | `grep "orderBadgesOverlay" MapInteractiveView.swift` | 2 Treffer (Z.135 + Z.188) | ✓ PASS |
| `enumerated()` für Badge-Nummerierung | `grep "selectedSegmentIds.enumerated()" MapInteractiveView.swift` | 1 Treffer | ✓ PASS |
| Badge-Guard: nur `editMode == .none` | `grep "editMode == .none" MapInteractiveView.swift` | Treffer bei Z.189 | ✓ PASS |
| Badges unabhängig von showRoomLabels | Overlay-Struktur: `.overlay { orderBadgesOverlay }` außerhalb `if showRoomLabels` | Separates Overlay bestätigt | ✓ PASS |
| customOrder: true bei Mehrraum-Reinigung | `grep "customOrder:" MapViewModel.swift + RobotDetailViewModel.swift` | `selectedSegmentIds.count > 1` / `selectedSegments.count > 1` | ✓ PASS |
| Commits existieren | `git cat-file -t b3b0f3b 5a28366 7eca004 aaf9e57` | Alle 4 als `commit` bestätigt | ✓ PASS |
| Visuelle Badge-Darstellung | Simulator-Test nötig | — | ? SKIP (needs human) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| ROOM-02 | 21-01-PLAN | Reihenfolge beim Start an Valetudo API übergeben | ✓ SATISFIED | `cleanSegments(ids: selectedSegmentIds, ...)` direkt ohne Wrapper + `customOrder: true` bei 2+ Räumen |
| ROOM-01 | 21-02-PLAN | Zahlen 1, 2, 3 auf der Karte über Räumen | ✓ SATISFIED (automated) | `orderBadgesOverlay` implementiert mit `enumerated()` + `Text("\(index + 1)")` — visuelle Darstellung benötigt Human-Verify |

**Hinweis:** REQUIREMENTS.md markiert ROOM-01 noch als `[ ]` (Pending) obwohl Plan 21-02-SUMMARY die Implementierung als abgeschlossen dokumentiert. Der Checkbox-Status in REQUIREMENTS.md sollte nach Human-Verification auf `[x]` gesetzt werden.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | — | — | Keine gefunden |

Kein `TODO`, `FIXME`, leere Handler oder Placeholder-Returns in den geänderten Dateien gefunden.

### Human Verification Required

#### 1. Badge-Visualisierung im Simulator

**Test:** App im iPhone Simulator starten, einen Roboter mit Raumkarte öffnen, Räume nacheinander antippen
**Expected:**
1. Erster Raum: blauer Kreis "1" über dem Raum-Mittelpunkt
2. Zweiter Raum: blauer Kreis "2" zusätzlich
3. Zweiten Raum abwählen: "2" verschwindet, dritter Raum wird zu "2"
4. Room-Labels ausblenden: Badges bleiben sichtbar
5. roomEdit-Modus: Badges verschwinden
**Why human:** SwiftUI-Rendering, Badge-Position (`y - 20` Offset) und Darstellung nur im laufenden Simulator überprüfbar

### Gaps Summary

Keine Lücken bei der Ziel-Erreichung festgestellt. Alle automatisch prüfbaren Must-Haves sind erfüllt:

- Set-zu-Array-Migration vollständig in allen relevanten Dateien
- Reihenfolge-Information wird korrekt durch den gesamten Stack propagiert
- `customOrder: true` wird bei Mehrraum-Reinigung an die API gesendet (unerwarteter Zusatz aus Plan 02)
- `orderBadgesOverlay` ist implementiert, unabhängig von showRoomLabels, korrekt mit editMode-Guard
- Badge-Nummerierung nutzt `enumerated()` für lückenlose Umnummerierung

Einzig ausstehend ist die visuelle Bestätigung durch Human-Verify im Simulator.

---

_Verified: 2026-04-04T14:00:00Z_
_Verifier: Claude (gsd-verifier)_
