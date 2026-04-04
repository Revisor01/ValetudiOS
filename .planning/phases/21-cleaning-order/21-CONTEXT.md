# Phase 21: Cleaning Order - Context

**Gathered:** 2026-04-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Die Auswahlreihenfolge der Räume wird als Reinigungsreihenfolge auf der Karte visualisiert (nummerierte Badges) und beim Start der Reinigung an die Valetudo API als geordnete Liste übergeben. Beim Abwählen werden die Zahlen automatisch neu nummeriert.

</domain>

<decisions>
## Implementation Decisions

### Datenstruktur für Reihenfolge
- `selectedSegmentIds` wird von `Set<String>` zu `[String]` Array geändert — Reihenfolge = Einfügereihenfolge
- Bei Abwahl: Element aus Array entfernen, Array-Index = neue Nummer (keine Lücken, automatisch korrekt)
- Beide ViewModels werden geändert: MapViewModel (`selectedSegmentIds`) und RobotDetailViewModel (`selectedSegments`)

### Zahlen-Visualisierung auf der Karte
- Zahlen erscheinen auf dem Raum-Mittelpunkt (gleiche Position wie Labels, aus `segmentInfos` midX/midY)
- Aussehen: Blauer Kreis mit weißer Zahl — ähnlich iOS Badge, konsistent mit blauem Selektions-Theme
- Zahlen sind unabhängig von `showRoomLabels` — immer sichtbar wenn Räume ausgewählt sind
- Größe: 24pt Kreis, 14pt Zahl

### API-Integration
- Array-Reihenfolge wird direkt an `cleanSegments(ids:)` übergeben — API nimmt bereits `[String]`, IDs in Einfügereihenfolge
- Reihenfolge gilt konsistent: sowohl über Karte als auch über Detailansicht

### Claude's Discretion
Keine — alle Fragen beantwortet.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `MapViewModel.selectedSegmentIds: Set<String>` — wird zu `[String]`
- `RobotDetailViewModel.selectedSegments: Set<String>` — wird zu `[String]`
- `cleanSegments(ids: [String])` in ValetudoAPI — nimmt bereits geordnetes Array
- `segmentInfos(from:)` in InteractiveMapView — liefert Raum-Mittelpunkte
- `tapTargetsOverlay` in InteractiveMapView — zeigt Labels als SwiftUI Overlay

### Established Patterns
- Canvas zeichnet Segmente mit `drawPixelsWithMaterial()`, Labels als SwiftUI Overlay
- `toggleSegment()` in InteractiveMapView managed Selection
- `handleCanvasTap()` (Phase 20) ruft `toggleSegment()` auf
- MapControlBarsView zeigt selectedSegmentIds.count für "N Räume ausgewählt"

### Integration Points
- `InteractiveMapView` erhält `selectedSegmentIds` als `@Binding`
- `MapView` bindet `$viewModel.selectedSegmentIds` an InteractiveMapView
- `cleanSelectedRooms()` in beiden ViewModels konvertiert zu `Array(selectedSegmentIds)` — wird direkt
- `MapControlBarsView` zeigt Raum-Count und Clean-Button

</code_context>

<specifics>
## Specific Ideas

- Set→Array Migration: `contains()` bleibt O(n) bei kleinen Arrays (typisch 3-8 Räume) — kein Performance-Problem
- Badge-Rendering: Als SwiftUI Overlay neben den Labels, Position aus `segmentInfos`
- Alle Stellen die `selectedSegmentIds` verwenden müssen auf Array-Semantik umgestellt werden (insert→append, remove→removeAll(where:), contains bleibt)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
