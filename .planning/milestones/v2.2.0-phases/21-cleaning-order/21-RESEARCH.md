# Phase 21: Cleaning Order — Research

**Researched:** 2026-04-04
**Domain:** SwiftUI, iOS Observable ViewModel, Set→Array Migration, SwiftUI Canvas/Overlay
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Datenstruktur für Reihenfolge**
- `selectedSegmentIds` wird von `Set<String>` zu `[String]` Array geändert — Reihenfolge = Einfügereihenfolge
- Bei Abwahl: Element aus Array entfernen, Array-Index = neue Nummer (keine Lücken, automatisch korrekt)
- Beide ViewModels werden geändert: MapViewModel (`selectedSegmentIds`) und RobotDetailViewModel (`selectedSegments`)

**Zahlen-Visualisierung auf der Karte**
- Zahlen erscheinen auf dem Raum-Mittelpunkt (gleiche Position wie Labels, aus `segmentInfos` midX/midY)
- Aussehen: Blauer Kreis mit weißer Zahl — ähnlich iOS Badge, konsistent mit blauem Selektions-Theme
- Zahlen sind unabhängig von `showRoomLabels` — immer sichtbar wenn Räume ausgewählt sind
- Größe: 24pt Kreis, 14pt Zahl

**API-Integration**
- Array-Reihenfolge wird direkt an `cleanSegments(ids:)` übergeben — API nimmt bereits `[String]`, IDs in Einfügereihenfolge
- Reihenfolge gilt konsistent: sowohl über Karte als auch über Detailansicht

### Claude's Discretion
Keine — alle Fragen beantwortet.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ROOM-01 | Beim Auswählen der Räume erscheinen Zahlen 1, 2, 3 auf der Karte über den Räumen — die Auswahl-Reihenfolge definiert die Reinigungsreihenfolge | Set→Array-Migration liefert Reihenfolge; Badge-Overlay via SwiftUI über `segmentInfos` |
| ROOM-02 | Die definierte Reihenfolge wird beim Start der Raumreinigung an die Valetudo API übergeben | `cleanSegments(ids:)` nimmt bereits `[String]` — Array direkt übergeben, kein Mapping nötig |
</phase_requirements>

---

## Summary

Phase 21 ist eine gezielte Refaktorierung ohne neue externe Abhängigkeiten. Alle Bausteine sind vorhanden — es müssen nur zwei Datentypen von `Set<String>` zu `[String]` migriert und ein Badge-Overlay ergänzt werden.

Die Migration betrifft zwei ViewModels (`MapViewModel.selectedSegmentIds`, `RobotDetailViewModel.selectedSegments`) und alle Stellen im UI und in den Tests, die auf diese Properties zugreifen. Die Reihenfolge ergibt sich automatisch aus der Einfügereihenfolge des Arrays — beim Abwählen wird `removeAll(where:)` verwendet, damit keine Lücken entstehen.

Die Zahlen-Badges werden als SwiftUI-Overlay neben dem bestehenden `tapTargetsOverlay` in `InteractiveMapView` gerendert. Sie nutzen dieselben `segmentInfos`-Mittelpunkte und sind immer sichtbar, unabhängig von `showRoomLabels`. Das Overlay läuft außerhalb des `Canvas` (Pattern bereits etabliert) und braucht keinen eigenen Zugriff auf den Canvas-Context.

**Primäre Empfehlung:** Alle Set-Operationen durch Array-Äquivalente ersetzen, dann Badge-Overlay separat hinzufügen. Beide Schritte sind unabhängig voneinander testbar.

---

## Standard Stack

### Core (keine neuen Abhängigkeiten)

| Komponente | Version | Zweck |
|-----------|---------|-------|
| SwiftUI | iOS 17+ (bestehendes Ziel) | Badge-Overlay, bestehende Canvas-Architektur |
| Swift `Array` | stdlib | Ersatz für `Set<String>` — Reihenfolge via Index |
| `@Observable` / `@MainActor` | Swift 5.9 (bereits verwendet) | ViewModel-Reaktivität — keine Änderung nötig |

**Installation:** Keine. Phase braucht keine neuen Pakete.

---

## Architecture Patterns

### Bestehende Struktur (relevant für diese Phase)

```
ValetudoApp/
├── ViewModels/
│   ├── MapViewModel.swift          — selectedSegmentIds: Set<String>  → [String]
│   └── RobotDetailViewModel.swift  — selectedSegments: Set<String>    → [String]
├── Views/
│   ├── MapInteractiveView.swift    — tapTargetsOverlay + toggleSegment()
│   ├── MapControlBarsView.swift    — selectedSegmentIds.isEmpty check
│   └── RobotDetailView.swift       — selectedSegments.contains / .count
└── ValetudoAppTests/
    ├── MapViewModelTests.swift      — selectedSegmentIds.isEmpty assertion
    └── RobotDetailViewModelTests.swift
```

### Pattern 1: Set→Array Migration

**Was:** `Set<String>` — ungeordnet, O(1) insert/contains/remove
**Neu:** `[String]` — geordnet, O(n) bei kleinen Arrays (3–8 Räume, kein Problem)

Vollständige Ersetzung aller Set-Operatoren:

| Set-Operation | Array-Äquivalent |
|---------------|-----------------|
| `insert(id)` | `append(id)` (nur wenn nicht enthalten) |
| `remove(id)` | `removeAll(where: { $0 == id })` |
| `contains(id)` | `contains(id)` — gleiche Signatur, bleibt |
| `removeAll()` | `removeAll()` — gleiche Signatur, bleibt |
| `.count` | `.count` — gleiche Signatur, bleibt |
| `.isEmpty` | `.isEmpty` — gleiche Signatur, bleibt |
| `.first` | `.first` — gleiche Signatur, bleibt |
| `Array(set)` | direkt verwenden — kein Wrapping nötig |

```swift
// toggleSegment — MapViewModel (vorher: Set)
func toggleSegment(_ id: String) {
    if selectedSegmentIds.contains(id) {
        selectedSegmentIds.removeAll(where: { $0 == id })
    } else {
        selectedSegmentIds.append(id)
    }
}

// toggleSegment — RobotDetailViewModel (vorher: Set)
func toggleSegment(_ id: String) {
    if selectedSegments.contains(id) {
        selectedSegments.removeAll(where: { $0 == id })
    } else {
        selectedSegments.insert(id)  // → append(id)
    }
}

// cleanSelectedRooms — beide ViewModels
// Vorher: try await api.cleanSegments(ids: Array(selectedSegmentIds), ...)
// Nachher: direkt, kein Array()-Wrapper mehr nötig
try await api.cleanSegments(ids: selectedSegmentIds, iterations: selectedIterations)
```

### Pattern 2: Badge-Overlay in InteractiveMapView

Die Zahlen-Badges sind ein zweites SwiftUI-Overlay über den bestehenden `tapTargetsOverlay`-Badges. Beide teilen denselben `segmentInfos`-Mittelpunkt.

**Wichtig:** Das Badge-Overlay ist unabhängig von `showRoomLabels`. Es muss deshalb außerhalb der bestehenden `if showRoomLabels`-Bedingung platziert werden.

```swift
// In InteractiveMapView.body — nach dem bestehenden .overlay { if showRoomLabels { tapTargetsOverlay } }
.overlay {
    orderBadgesOverlay
}

// Neuer @ViewBuilder
@ViewBuilder
private var orderBadgesOverlay: some View {
    GeometryReader { geometry in
        let params = calculateMapParams(
            layers: map.layers ?? [],
            pixelSize: map.pixelSize ?? 5,
            size: geometry.size
        )

        if let p = params, let layers = map.layers {
            ForEach(Array(selectedSegmentIds.enumerated()), id: \.element) { index, segmentId in
                // segmentInfos enthält midX/midY für alle Segmente
                if let info = segmentInfos(from: layers).first(where: { $0.id == segmentId }) {
                    let x = CGFloat(info.midX) * p.scale + p.offsetX
                    let y = CGFloat(info.midY) * p.scale + p.offsetY

                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 24, height: 24)
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .position(x: x, y: y - 20)  // Etwas über Raummittelpunkt versetzt
                }
            }
        }
    }
}
```

**Positionierung:** Die Zahl erscheint leicht über dem Raummittelpunkt (`y - 20`), damit sie nicht mit dem Label-Badge überlappt wenn `showRoomLabels == true`. Exakter Offset nach visuellem Test anpassbar.

### Pattern 3: Binding-Typ in InteractiveMapView

`InteractiveMapView` empfängt `selectedSegmentIds` als `@Binding`. Der Binding-Typ muss von `Set<String>` zu `[String]` geändert werden — alle Callsites passen sich automatisch an, wenn MapViewModel geändert wurde.

```swift
// Vorher:
@Binding var selectedSegmentIds: Set<String>

// Nachher:
@Binding var selectedSegmentIds: [String]
```

### Anti-Patterns zu vermeiden

- **Array ohne Duplikat-Check:** Beim `append` immer prüfen `if !selectedSegmentIds.contains(id)`, sonst doppelte Einträge wenn `toggleSegment` zweimal aufgerufen wird
- **`Array(set)` stehen lassen:** Compiler erlaubt es, aber es ist unnötig und erzeugt undefinierte Reihenfolge — alle Wrapper entfernen
- **Badge über Canvas zeichnen:** Canvas-Context ist stateless und nicht geeignet für reaktive SwiftUI-Elemente mit Animationen — SwiftUI-Overlay ist korrekt

---

## Don't Hand-Roll

| Problem | Nicht bauen | Stattdessen |
|---------|-------------|-------------|
| Nummerierung ohne Lücken | Eigenen Re-Index-Algorithmus | Array-Index direkt: `enumerated()` liefert 0-basiert, Badge zeigt `index + 1` |
| Duplikat-Verhinderung | Custom Set-Wrapper | `if !contains(id) { append(id) }` — reicht für 3–8 Räume |
| Badge-Position | Neuberechnung der Mittelpunkte | `segmentInfos(from:)` ist bereits vorhanden und korrekt |

---

## Common Pitfalls

### Pitfall 1: Vergessene Callsites

**Was passiert:** `Set<String>` wird in den ViewModels geändert, aber `InteractiveMapView` (Binding), Test-Assertions oder `MapControlBarsView` referenzieren noch `Set`-Operationen.

**Warum:** Compiler fängt Typ-Mismatches, aber semantische Fehler (z.B. `Array(selectedSegmentIds)`) kompilieren weiterhin ohne Warnung.

**Wie vermeiden:** Vollständige Suche nach allen Vorkommen vor dem Commit:
```bash
grep -rn "selectedSegmentIds\|selectedSegments" ValetudoApp/ --include="*.swift"
```
Danach prüfen: Gibt es noch `Array(selectedSegmentIds)`? → Entfernen. Gibt es noch `insert(` statt `append(`? → Ersetzen.

**Warnsignale:** Build erfolgreich aber Reihenfolge in API-Call ist nicht deterministisch.

### Pitfall 2: Badge-Position bei ausgeblendetem Label

**Was passiert:** Wenn `showRoomLabels == false`, ist der `tapTargetsOverlay` nicht sichtbar. Das Badge-Overlay muss trotzdem gerendert werden — es darf NICHT innerhalb der `if showRoomLabels`-Bedingung landen.

**Wie vermeiden:** `orderBadgesOverlay` als eigenes, bedingungsloses `.overlay { }` platzieren, getrennt vom bestehenden `tapTargetsOverlay`.

### Pitfall 3: Reihenfolge im roomEdit-Modus

**Was passiert:** Im `roomEdit`-Modus (`editMode == .roomEdit`) wählt der Benutzer Räume zum Bearbeiten, nicht zum Reinigen. Beide Modi teilen `selectedSegmentIds`. Der Badge würde auch im Edit-Modus Zahlen anzeigen.

**Analyse:** Laut CONTEXT.md ist der Badge immer sichtbar wenn Räume ausgewählt sind — also auch im Edit-Modus. Dies ist wahrscheinlich akzeptabel, weil Edit-Modus im Normalfall 1–2 Räume auswählt und die Zahl keine Bedeutung hat aber auch nicht stört.

**Empfehlung:** Badge nur außerhalb von `editMode == .roomEdit` und `editMode == .splitRoom` zeigen. Entscheidung im Plan dokumentieren.

### Pitfall 4: Test-Assertions prüfen `isEmpty`

**Was passiert:** `MapViewModelTests` prüft `XCTAssertTrue(viewModel.selectedSegmentIds.isEmpty)` — das ist typ-agnostisch und klappt weiterhin. Aber falls ein Test einen Set-Vergleich verwendet (z.B. `XCTAssertEqual(viewModel.selectedSegmentIds, ["1", "2"])`), schlägt er bei falscher Reihenfolge fehl.

**Aktueller Stand:** Bestehende Tests prüfen nur `.isEmpty` — kein Problem. Neue Tests für ROOM-01 müssen Reihenfolge explizit prüfen.

---

## Code Examples

### Vollständige `toggleSegment`-Implementierung (MapViewModel)

```swift
// MapViewModel — toggleSegment (Array-Version)
// Wird von InteractiveMapView via Binding aufgerufen
private func toggleSegment(_ id: String) {
    if selectedSegmentIds.contains(id) {
        selectedSegmentIds.removeAll(where: { $0 == id })
    } else {
        selectedSegmentIds.append(id)
    }
}
```

### `cleanSelectedRooms` nach Migration (MapViewModel)

```swift
func cleanSelectedRooms() async {
    guard let api = api, !selectedSegmentIds.isEmpty else { return }
    isCleaning = true
    defer { isCleaning = false }

    do {
        // selectedSegmentIds ist jetzt [String] — direkt übergeben, Reihenfolge erhalten
        try await api.cleanSegments(ids: selectedSegmentIds, iterations: selectedIterations)
        selectedSegmentIds.removeAll()
        selectedIterations = 1
        await robotManager.refreshRobot(robot.id)
    } catch {
        logger.error("cleanSelectedRooms FAILED: \(error.localizedDescription, privacy: .public)")
        errorMessage = error.localizedDescription
    }
}
```

### `joinRooms` nach Migration (MapViewModel)

```swift
// Vorher: Array(viewModel.selectedSegmentIds) — jetzt direkt
func joinRooms(ids: [String]) async {
    // ids kommt von Callsite: Array(selectedSegmentIds) → selectedSegmentIds direkt
    guard let api = api, ids.count == 2 else { return }
    // ...
}

// Callsite in MapControlBarsView (roomEditBar):
// Vorher: Task { await viewModel.joinRooms(ids: Array(viewModel.selectedSegmentIds)) }
// Nachher: Task { await viewModel.joinRooms(ids: viewModel.selectedSegmentIds) }
```

### `renameRoom`-Callsite in MapControlBarsView

```swift
// Vorher:
if let segmentId = viewModel.selectedSegmentIds.first {

// Nachher (unverändert — .first funktioniert bei Array genauso):
if let segmentId = viewModel.selectedSegmentIds.first {
```

---

## Vollständige Änderungsliste (alle Dateien)

Diese Liste ist das Kernstück für den Planner — alle betroffenen Stellen wurden im Code verifiziert.

### MapViewModel.swift

| Zeile | Vorher | Nachher |
|-------|--------|---------|
| 47 | `var selectedSegmentIds: Set<String> = []` | `var selectedSegmentIds: [String] = []` |
| 195 | `try await api.cleanSegments(ids: Array(selectedSegmentIds), ...)` | `try await api.cleanSegments(ids: selectedSegmentIds, ...)` |
| 273 | `selectedSegmentIds.removeAll()` | unverändert |
| 293 | `selectedSegmentIds.removeAll()` | unverändert |
| 375 | `selectedSegmentIds.removeAll()` | unverändert |
| 436 | `selectedSegmentIds.removeAll()` | unverändert |

Außerdem: Neue `toggleSegment`-Hilfsmethode hinzufügen (oder `toggleSegment` existiert bereits implizit über Binding — im Binding ist es `InteractiveMapView.toggleSegment`).

### RobotDetailViewModel.swift

| Zeile | Vorher | Nachher |
|-------|--------|---------|
| 18 | `var selectedSegments: Set<String> = []` | `var selectedSegments: [String] = []` |
| 342 | `try await api.cleanSegments(ids: Array(selectedSegments), ...)` | `try await api.cleanSegments(ids: selectedSegments, ...)` |
| 351–356 | `toggleSegment` mit `insert`/`remove` | mit `append`/`removeAll(where:)` |

### MapInteractiveView.swift

| Zeile | Vorher | Nachher |
|-------|--------|---------|
| 7 | `@Binding var selectedSegmentIds: Set<String>` | `@Binding var selectedSegmentIds: [String]` |
| 61 | `selectedSegmentIds.contains($0)` | unverändert |
| 151 | `selectedSegmentIds.contains(info.id)` | unverändert |
| 183–189 | `toggleSegment` mit `insert`/`remove` | mit `append`/`removeAll(where:)` |
| **NEU** | — | `orderBadgesOverlay` als zweites `.overlay { }` |

### MapControlBarsView.swift

| Stelle | Vorher | Nachher |
|--------|--------|---------|
| `selectedSegmentIds.isEmpty` (Zeile 154) | unverändert | unverändert |
| `viewModel.selectedSegmentIds.count` | unverändert | unverändert |
| `Array(viewModel.selectedSegmentIds)` in roomEditBar | entfernen | `viewModel.selectedSegmentIds` direkt |

### RobotDetailView.swift

| Stelle | Vorher | Nachher |
|--------|--------|---------|
| `viewModel.selectedSegments.contains(segment.id)` (Zeile 1004) | unverändert | unverändert |
| `viewModel.selectedSegments.count` (Zeile 1019, 1076) | unverändert | unverändert |
| `viewModel.selectedSegments.isEmpty` (Zeile 1018, 1031) | unverändert | unverändert |
| Toggle-Aufruf (via `toggleSegment`) | unverändert | unverändert |

### MapViewModelTests.swift

| Zeile | Vorher | Nachher |
|-------|--------|---------|
| 31 | `XCTAssertTrue(viewModel.selectedSegmentIds.isEmpty)` | unverändert (typ-agnostisch) |

---

## Environment Availability

Step 2.6: SKIPPED — Phase ist rein code-intern, keine externen Tools oder Dienste nötig.

---

## State of the Art

| Alter Ansatz | Aktueller Ansatz | Auswirkung |
|-------------|-----------------|------------|
| `Set<String>` für Raumauswahl | `[String]` Array | Reihenfolge deterministisch, kein Performance-Verlust bei 3–8 Räumen |
| `Array(set)` beim API-Call | Direktes Array | Undefinierte Reihenfolge eliminiert |

---

## Open Questions

1. **Badge-Sichtbarkeit im roomEdit-Modus**
   - Was wir wissen: Im `roomEdit`-Modus werden auch 1–2 Räume via `selectedSegmentIds` ausgewählt
   - Was unklar ist: Soll das Badge dort erscheinen (harmlos) oder ausgeblendet werden?
   - Empfehlung: Badge nur zeigen wenn `editMode == .none` (normaler Auswahl-Modus) — verhindert Verwirrung

2. **Badge-Y-Offset bei überlappenden Labels**
   - Was wir wissen: Badge und Label sitzen am selben `segmentInfos`-Mittelpunkt
   - Was unklar ist: Exakter Pixel-Offset muss visuell überprüft werden
   - Empfehlung: Plan schlägt `y - 20` vor, finaler Wert nach visuellem Test

---

## Sources

### Primary (HIGH confidence — direkte Code-Analyse)

- `MapViewModel.swift` Zeile 47 — `selectedSegmentIds: Set<String>` verifiziert
- `RobotDetailViewModel.swift` Zeile 18 — `selectedSegments: Set<String>` verifiziert
- `MapInteractiveView.swift` Zeilen 7, 183–189, 228–268 — Binding-Typ und `segmentInfos` verifiziert
- `MapControlBarsView.swift` Zeilen 152–155 — `cleanSelectedRooms()` und `isEmpty`-Check verifiziert
- `RobotDetailView.swift` Zeile 1004, 1018, 1031 — `selectedSegments`-Nutzung im UI verifiziert
- `MapViewModelTests.swift` Zeile 31 — Test-Assertion verifiziert (typ-agnostisch, kein Breaking Change)
- `ValetudoAPI.swift` — `cleanSegments(ids: [String], iterations: Int)` nimmt bereits Array

### Secondary (HIGH confidence — Swift stdlib)

- Swift stdlib `Array` — `contains`, `append`, `removeAll(where:)`, `removeAll()`, `first`, `isEmpty`, `count` — identische Signaturen zu Set wo relevant

---

## Metadata

**Confidence breakdown:**
- Datenstruktur-Migration: HIGH — alle Callsites im Code verifiziert
- Badge-Overlay: HIGH — Pattern aus bestehendem `tapTargetsOverlay` direkt übertragbar
- API-Integration: HIGH — `cleanSegments(ids: [String])` Signatur verifiziert

**Research date:** 2026-04-04
**Valid until:** 2026-05-04 (stabile Codebasis, kein externer Drift erwartet)
