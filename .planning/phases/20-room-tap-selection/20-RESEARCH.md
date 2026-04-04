# Phase 20: Room Tap Selection - Research

**Researched:** 2026-04-04
**Domain:** SwiftUI Canvas Hit-Testing, Pixel-Space Coordinate Transformation
**Confidence:** HIGH

## Summary

Phase 20 implementiert Pixel-basiertes Hit-Testing auf dem Valetudo-Kartencanvas. Der Nutzer soll einen Raum durch Tap auf seine farbig gezeichnete Fläche auswählen — unabhängig davon, ob Room-Labels sichtbar sind. Die gesamte technische Infrastruktur ist bereits vorhanden: `decompressedPixels` auf jedem `MapLayer`, `calculateMapParams()` für die Koordinatentransformation, `toggleSegment()` für den Toggle-Effekt und `screenToMapCoords()` in `MapContentView` für die Rücktransformation aus Zoom/Pan-Kontext.

Die Kernaufgabe besteht darin, einen `SpatialTapGesture` auf dem Canvas zu registrieren, der Tap-Koordinaten empfängt, sie in Pixel-Koordinaten rücktransformiert und dann für jede Segment-Layer prüft, ob das berechnete Pixel in `decompressedPixels` enthalten ist. Der erste Treffer gewinnt (Layer-Reihenfolge wie von API geliefert). Taps auf leere Flächen (keine Segment-Layer trifft) lösen keinen Toggle aus.

Der Tap-Gesture soll nur in den Modi `.none` und `.roomEdit` aktiv sein. In allen anderen Modi (`.zone`, `.noGoArea`, `.noMopArea`, `.virtualWall`, `.goTo`, `.savePreset`, `.splitRoom`, `.deleteRestriction`) fangen bereits bestehende `DragGesture`-Overlays den Input ab — der Flächen-Tap würde dort nie ausgeführt.

**Primary recommendation:** `SpatialTapGesture` auf dem `Canvas` in `InteractiveMapView` registrieren; Hit-Testing via Pixel-Lookup in `decompressedPixels`; Rücktransformation via vorhandenes `calculateMapParams()`.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Hit-Testing Verhalten**
- Pixel-Lookup in Segment-Layer: Tap-Koordinate wird in Pixel-Space rücktransformiert und gegen `decompressedPixels` der Segment-Layer geprüft
- Bei überlappenden Segmenten gewinnt das erste Segment (Layer-Reihenfolge wie von API geliefert)
- Exakte Toleranz auf Pixel — ein Segment-Pixel muss getroffen werden, kein zusätzlicher Radius
- Tap-auf-Fläche nur im Normal- und roomEdit-Modus aktiv — in Zone/NoGo/VirtualWall-Modi fangen DragGestures den Input ab

**Visuelles Feedback**
- Gleicher visueller Effekt wie Label-Tap — Raum wechselt Opacity (0.6→0.9) + blauer Border, kein zusätzlicher Effekt nötig
- Label-Tap und Flächen-Tap koexistieren — beide Wege führen zu `toggleSegment()`, Labels bleiben sichtbar wenn aktiviert
- SpatialTapGesture auf dem Canvas für Koordinaten-Erkennung, Rücktransformation in Pixel-Space

### Claude's Discretion

Keine — alle Fragen beantwortet.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TAP-01 | Benutzer kann einen Raum durch Tap auf die Raumfläche auswählen, nicht nur durch Tap auf das Label | Pixel-Lookup via `decompressedPixels` + `SpatialTapGesture` auf Canvas |
| TAP-02 | Die Tap-auf-Fläche-Auswahl funktioniert auch wenn Raum-Labels ausgeblendet sind | Tap-Gesture ist unabhängig vom `showRoomLabels`-Flag — Labels-Overlay und Tap-Gesture trennen |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | Canvas, SpatialTapGesture, Gesture-Komposition | Bereits im Projekt, passt zur Canvas-Architektur |

### Supporting
Keine zusätzlichen Libraries erforderlich. Alle benötigten Bausteine sind im Projekt vorhanden.

**Installation:** Keine.

## Architecture Patterns

### Vorhandene Struktur (relevant für diese Phase)

```
Views/
├── MapInteractiveView.swift   # Canvas + tapTargetsOverlay — HIER wird SpatialTapGesture ergänzt
├── MapView.swift              # MapContentView mit screenToMapCoords() + combinedGesture
ViewModels/
└── MapViewModel.swift         # selectedSegmentIds, toggleSegment() (inline), editMode
Models/
└── RobotMap.swift             # MapLayer.decompressedPixels, MapLayerCache
```

### Pattern 1: SpatialTapGesture auf SwiftUI Canvas

**Was:** `SpatialTapGesture` liefert die genaue CGPoint-Position im lokalen Koordinatensystem der View, auf der er registriert ist. Im Gegensatz zu `TapGesture` enthält er die Position des Taps.

**Wann verwenden:** Immer wenn eine präzise Tap-Position benötigt wird und die View mit `.gesture()` statt Button arbeitet.

**Wichtig — Koordinatensystem:** Der `SpatialTapGesture` liefert Koordinaten im Koordinatensystem der `InteractiveMapView`, **bevor** `scaleEffect(scale).offset(offset)` aus `MapContentView` angewendet wurde. Das bedeutet: die Tap-Koordinate ist bereits im "ungezoomed/unpanned" Raum des Canvas. Die Transformation über `screenToMapCoords()` aus `MapContentView` ist daher NICHT direkt anwendbar auf den `SpatialTapGesture`-Callback — dieser läuft in `InteractiveMapView`, nicht in `MapContentView`.

**Innerhalb von `InteractiveMapView`:** Der Canvas zeichnet mit `calculateMapParams()` — diese Funktion liefert `scale`, `offsetX`, `offsetY` relativ zur View-Größe. Der `SpatialTapGesture`-Callback erhält eine Position in diesem selben Koordinatensystem. Die Rücktransformation zu Pixel-Koordinaten ist:

```swift
// Source: Valetudo-Projekt, MapInteractiveView.swift + MapView.swift (abgeleitet)
// tapLocation: CGPoint aus SpatialTapGesture.onEnded { value in let loc = value.location }
let pixelX = Int(((tapLocation.x - p.offsetX) / p.scale).rounded())
let pixelY = Int(((tapLocation.y - p.offsetY) / p.scale).rounded())
```

**Beispiel SpatialTapGesture:**

```swift
// Source: Apple SwiftUI Dokumentation (SpatialTapGesture, iOS 16+)
Canvas { context, size in
    // ... Zeichnen
}
.gesture(
    SpatialTapGesture()
        .onEnded { value in
            handleTap(at: value.location, size: ...)
        }
)
```

### Pattern 2: Pixel-Lookup in decompressedPixels

**Was:** Für jede Segment-Layer wird geprüft, ob das berechnete Pixel `(pixelX, pixelY)` in `decompressedPixels` enthalten ist. Das Array enthält (x, y)-Paare als flaches Int-Array.

**Effiziente Suche:** Das lineare Suchen im Array ist bei einer typischen Karte (einige tausend Pixel pro Segment, wenige Segmente) performant genug für einen einzelnen Tap-Event. Ein `Set<Int>` als Cache (Schlüssel: `y * mapWidth + x`) wäre optional optimierbar, aber nicht notwendig für Phase 20.

```swift
// Source: Valetudo-Projekt, abgeleitet aus decompressedPixels-Struktur
func segmentId(at pixelX: Int, pixelY: Int, in layers: [MapLayer]) -> String? {
    for layer in layers where layer.type == "segment" {
        let pixels = layer.decompressedPixels
        var i = 0
        while i < pixels.count - 1 {
            if pixels[i] == pixelX && pixels[i + 1] == pixelY {
                return layer.metaData?.segmentId
            }
            i += 2
        }
    }
    return nil
}
```

### Pattern 3: Gesture-Aktivierung nur in relevanten Modi

**Was:** Der `SpatialTapGesture` soll nur in `.none` und `.roomEdit` aktiv sein. In allen anderen Modi gibt es bereits `drawingOverlay`-Gesten (`DragGesture` mit `minimumDistance: 0`) als transparentes `Color.clear`-Overlay — diese fangen Taps ab bevor der Canvas sie empfangen kann.

**Umsetzung:** Conditional modifier in `InteractiveMapView`:

```swift
// Source: Valetudo-Projekt, abgeleitet aus MapContentView drawingOverlay-Logik
Canvas { ... }
.gesture(
    (editMode == .none || editMode == .roomEdit)
        ? SpatialTapGesture().onEnded { ... }
        : nil
)
```

Alternativ: Im Handler selbst prüfen und früh zurückgeben — einfacher, da SwiftUI conditional gesture-Syntax etwas umständlich ist:

```swift
Canvas { ... }
.gesture(
    SpatialTapGesture()
        .onEnded { value in
            guard editMode == .none || editMode == .roomEdit else { return }
            handleCanvasTap(at: value.location)
        }
)
```

### Anti-Patterns to Avoid

- **Zoom/Pan nicht berücksichtigen:** Der `SpatialTapGesture` in `InteractiveMapView` läuft *innerhalb* des `.scaleEffect().offset()`-Containers. SwiftUI transformiert die Tap-Koordinate automatisch in das lokale Koordinatensystem der View — die Rücktransformation über Zoom/Pan ist daher NICHT nötig. Nur die `calculateMapParams()`-Transformation (Offset + Scale für Karten-Pixels) muss angewendet werden.
- **Radius/Toleranz hinzufügen:** Laut User-Entscheidung exakte Pixel-Toleranz. Kein `±N`-Radius um den Tap-Punkt.
- **tapTargetsOverlay für Flächen-Tap missbrauchen:** Das Label-Overlay ist bedingt auf `showRoomLabels`. Der neue Flächen-Tap muss direkt auf dem Canvas liegen und darf nicht vom Label-Flag abhängen.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tap-Position in View | Eigenes Gesture-Tracking mit UIKit | `SpatialTapGesture` (SwiftUI native) | Seit iOS 16, sauber in SwiftUI-Architektur integriert |
| Koordinatentransformation | Neue Transformation | Vorhandenes `calculateMapParams()` + abgeleitete Formel | Identisch zur bestehenden Rendering-Logik |

**Key insight:** Keine neuen Hilfsfunktionen für Koordinatentransformation nötig — die Formel `pixelX = (tapX - offsetX) / scale` ist die direkte Umkehrung von `screenX = pixelX * scale + offsetX` die bereits im Canvas-Rendering verwendet wird.

## Common Pitfalls

### Pitfall 1: Koordinatensystem-Verwirrung — SpatialTapGesture vs. screenToMapCoords

**What goes wrong:** Entwickler verwendet `screenToMapCoords()` aus `MapContentView` für die Koordinaten-Rücktransformation im Canvas-Tap-Handler.

**Why it happens:** `screenToMapCoords()` berücksichtigt Zoom (`scale`) und Pan (`offset`) der `MapContentView`. Der `SpatialTapGesture` in `InteractiveMapView` empfängt aber bereits transformierte Koordinaten — SwiftUI übersetzt den Tap automatisch in das lokale Koordinatensystem der View *nach* `scaleEffect/offset*. Die Zoom/Pan-Transformation ist also bereits herausgerechnet.

**How to avoid:** Nur `calculateMapParams()` für die Pixel-Rücktransformation verwenden. Die Formel lautet: `pixelX = (tapX - p.offsetX) / p.scale`.

**Warning signs:** Räume werden falsch erkannt wenn die Karte hineingezoomt oder verschoben ist.

### Pitfall 2: pixelSize vergessen

**What goes wrong:** Pixel-Koordinaten aus `decompressedPixels` entsprechen direkt den Karten-Pixel-Einheiten (z.B. 1 Einheit = 5mm bei `pixelSize = 5`). Die Rücktransformation aus Canvas-Koordinaten muss konsistent mit dem Rendering sein.

**Why it happens:** Im Rendering ist die Formel `screenX = CGFloat(pixelX) * params.scale + params.offsetX` — `pixelX` ist hier die Pixel-Koordinate direkt aus `decompressedPixels`. Die Rücktransformation muss dieselbe Skala verwenden.

**How to avoid:** Rücktransformation `pixelX = Int(((tapX - p.offsetX) / p.scale).rounded())` — identisch mit der bereits in `finishDrawing()` verwendeten Logik.

**Warning signs:** Taps in der richtigen Gegend werden nicht erkannt oder falsche Räume werden getroffen.

### Pitfall 3: SpatialTapGesture kollidiert mit combinedGesture

**What goes wrong:** `SpatialTapGesture` auf dem Canvas-Canvas konkurriert mit dem `combinedGesture` (MagnificationGesture + DragGesture) in `MapContentView`.

**Why it happens:** SwiftUI löst Gesture-Konflikte nach Priorität auf. Ein kurzer Tap (kein Movement) sollte `SpatialTapGesture` gewinnen lassen, aber ein sehr langsamer Tap könnte als DragGesture interpretiert werden.

**How to avoid:** `DragGesture` in `combinedGesture` hat `minimumDistance` von Standard (10pt). Kurze Taps (<10pt Bewegung) werden nicht als Drag erkannt. Dies ist das bestehende Verhalten — keine Änderung nötig.

**Warning signs:** Raum-Taps lösen stattdessen Pan-Gesten aus.

### Pitfall 4: Tap in `.none` Modus bricht roomEdit-Workflow

**What goes wrong:** In `.none` Modus (normaler Betrieb, keine Bearbeitung) sollen Räume für Reinigung ausgewählt werden. In `.roomEdit` für Umbenennen/Trennen. Beide Modi nutzen `selectedSegmentIds`, aber die Konsequenz eines Taps kann verschieden sein.

**Why it happens:** Das aktuelle Label-Tap-System ruft einfach `toggleSegment()` auf — egal in welchem Modus. Der neue Flächen-Tap soll dasselbe tun. Kein unterschiedliches Verhalten nötig, laut User-Entscheidung.

**How to avoid:** `toggleSegment()` in beiden Modi aufrufen — identisch zum Label-Tap. Kein Mode-Switch-Logic im Tap-Handler.

## Code Examples

### Vollständige Tap-Handler-Logik

```swift
// Anzufügen in InteractiveMapView
// Source: Abgeleitet aus bestehendem Code (calculateMapParams, decompressedPixels-Struktur)

private func handleCanvasTap(at location: CGPoint, size: CGSize) {
    guard editMode == .none || editMode == .roomEdit else { return }
    guard let layers = map.layers else { return }

    let pixelSize = map.pixelSize ?? 5
    guard let p = calculateMapParams(layers: layers, pixelSize: pixelSize, size: size) else { return }

    // Rücktransformation: Canvas-Koordinate → Pixel-Koordinate
    let pixelX = Int(((location.x - p.offsetX) / p.scale).rounded())
    let pixelY = Int(((location.y - p.offsetY) / p.scale).rounded())

    // Segment-Lookup: erste Layer gewinnt bei Überlappung
    for layer in layers where layer.type == "segment" {
        let pixels = layer.decompressedPixels
        var i = 0
        while i < pixels.count - 1 {
            if pixels[i] == pixelX && pixels[i + 1] == pixelY {
                if let segmentId = layer.metaData?.segmentId {
                    toggleSegment(segmentId)
                }
                return  // Erster Treffer gewinnt, kein weiteres Suchen
            }
            i += 2
        }
    }
    // Kein Treffer → kein Toggle, kein unbeabsichtigter State-Change
}
```

### Integration in InteractiveMapView Canvas

```swift
// In InteractiveMapView body — Canvas mit SpatialTapGesture
Canvas { context, size in
    // ... bestehender Zeichencode unverändert
}
.gesture(
    SpatialTapGesture()
        .onEnded { value in
            // size muss aus GeometryReader oder als gespeicherter State übergeben werden
            handleCanvasTap(at: value.location, size: viewSize)
        }
)
.overlay {
    if showRoomLabels {
        tapTargetsOverlay  // Label-Tap bleibt unverändert
    }
}
```

**Hinweis zu `viewSize`:** `InteractiveMapView` erhält bereits `viewSize: CGSize` als Parameter — dieser kann direkt im `onEnded`-Handler verwendet werden.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Nur Label-Buttons als Tap-Targets | SpatialTapGesture direkt auf Canvas | Phase 20 | Flächen-Tap ohne Labels möglich |

## Open Questions

Keine — alle Entscheidungen sind im CONTEXT.md getroffen.

## Environment Availability

Step 2.6: SKIPPED (rein code-interne Änderung, keine externen Dependencies)

## Sources

### Primary (HIGH confidence)
- Valetudo-Projekt: `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift` — vollständiger Canvas-Code, tapTargetsOverlay, toggleSegment, calculateMapParams
- Valetudo-Projekt: `ValetudoApp/ValetudoApp/Views/MapView.swift` — screenToMapCoords, finishDrawing (Pixel-Rücktransformations-Referenz), combinedGesture
- Valetudo-Projekt: `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift` — selectedSegmentIds, editMode, showRoomLabels
- Valetudo-Projekt: `ValetudoApp/ValetudoApp/Models/RobotMap.swift` — decompressedPixels, MapLayer-Struktur

### Secondary (MEDIUM confidence)
- Apple SwiftUI Dokumentation: `SpatialTapGesture` — iOS 16+, liefert `location: CGPoint` im lokalen View-Koordinatensystem

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — Reiner SwiftUI-Code, keine neuen Libraries
- Architecture: HIGH — Bestehende Funktionen direkt wiederverwendet, Formel eindeutig ableitbar aus Rendering-Code
- Pitfalls: HIGH — Koordinatensystem-Verwirrung ist dokumentiert aus direkter Code-Analyse

**Research date:** 2026-04-04
**Valid until:** Stabil bis zur nächsten Änderung an MapInteractiveView oder MapView
