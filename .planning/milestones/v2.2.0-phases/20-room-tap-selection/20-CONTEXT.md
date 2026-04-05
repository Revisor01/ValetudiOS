# Phase 20: Room Tap Selection - Context

**Gathered:** 2026-04-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Benutzer kann einen Raum durch Tap auf seine Fläche in der Karte auswählen — nicht nur durch Tap auf das Label. Die Tap-auf-Fläche-Auswahl funktioniert auch wenn Room-Labels ausgeblendet sind. Tap auf eine Stelle ohne Raumfläche wählt keinen Raum aus.

</domain>

<decisions>
## Implementation Decisions

### Hit-Testing Verhalten
- Pixel-Lookup in Segment-Layer: Tap-Koordinate wird in Pixel-Space rücktransformiert und gegen `decompressedPixels` der Segment-Layer geprüft
- Bei überlappenden Segmenten gewinnt das erste Segment (Layer-Reihenfolge wie von API geliefert)
- Exakte Toleranz auf Pixel — ein Segment-Pixel muss getroffen werden, kein zusätzlicher Radius
- Tap-auf-Fläche nur im Normal- und roomEdit-Modus aktiv — in Zone/NoGo/VirtualWall-Modi fangen DragGestures den Input ab

### Visuelles Feedback
- Gleicher visueller Effekt wie Label-Tap — Raum wechselt Opacity (0.6→0.9) + blauer Border, kein zusätzlicher Effekt nötig
- Label-Tap und Flächen-Tap koexistieren — beide Wege führen zu `toggleSegment()`, Labels bleiben sichtbar wenn aktiviert
- SpatialTapGesture auf dem Canvas für Koordinaten-Erkennung, Rücktransformation in Pixel-Space

### Claude's Discretion
Keine — alle Fragen beantwortet.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `InteractiveMapView` (MapInteractiveView.swift) — Canvas-basierte Kartenansicht mit Segment-Rendering
- `toggleSegment(_:)` — existierende Funktion für Raum-Toggle via `selectedSegmentIds: Set<String>`
- `segmentInfos(from:)` — berechnet Segment-Mittelpunkte aus `decompressedPixels` oder `dimensions`
- `calculateMapParams()` — liefert `MapParams` (scale, offsetX, offsetY) für Koordinaten-Transformation
- `decompressedPixels` auf jedem `MapLayer` — Int-Array mit (x,y)-Paaren

### Established Patterns
- Canvas zeichnet Pixel mit `params.scale` und `params.offset` Transformation
- Room-Labels sind SwiftUI Button-Overlays über dem Canvas (`.overlay {}`)
- `showRoomLabels` Bool steuert Label-Sichtbarkeit
- Segment-Selection via `@Binding var selectedSegmentIds: Set<String>`

### Integration Points
- `InteractiveMapView` erhält `selectedSegmentIds` als Binding — Toggle dort direkt
- MapView.swift orchestriert InteractiveMapView mit Gestures und Edit-Modi
- `MapEditMode` enum bestimmt aktiven Interaktionsmodus

</code_context>

<specifics>
## Specific Ideas

- User interagiert primär über die Karte, Labels können aus Platzgründen ausgeblendet sein
- Rücktransformation: Canvas-Tap-Koordinate → Pixel-Koordinate via `(tapX - offsetX) / scale` und `(tapY - offsetY) / scale`
- Pixel-Lookup: Für jedes Segment-Layer prüfen ob berechnete Pixel-Koordinate in `decompressedPixels` enthalten ist (mit pixelSize-Toleranz)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
