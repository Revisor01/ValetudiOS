# Phase 11: View Decomposition - Context

**Gathered:** 2026-03-29
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase — discuss skipped)

<domain>
## Phase Boundary

Die drei größten Views sind in überschaubare Sub-Views aufgeteilt; keine einzelne View-Datei überschreitet eine handhabbare Größe. MapView (2532 Zeilen), RobotSettingsView (1801 Zeilen), RobotDetailView (1253 Zeilen) werden in logische Sub-View-Structs aufgebrochen.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — pure infrastructure/refactoring phase.

Key constraints:
- Sub-Views müssen als eigene Structs in separaten Dateien oder als Extensions definiert werden
- Alle Sub-Views bekommen die nötigen Bindings/Properties via init Parameter
- ViewModels bleiben unverändert — nur die View-Layer wird aufgeteilt
- Xcode Previews müssen identisch bleiben
- Neue Dateien via xcodegen registrieren

### MapView Decomposition Hints
- MiniMapView (Overlay-Karte unten links)
- MapControlsView (Zoom/Pan/Mode Buttons)
- MapDrawingHelpers (Canvas-Zeichnungs-Extension-Methoden)
- MapGestureHandlers (Touch/Drag/Pinch)
- Haupt-MapView bleibt als Container/Coordinator

### RobotSettingsView Decomposition Hints
- Aktuell hat Settings viele Sections: Volume, Carpet, KeyLock, Map, Station etc.
- Jede Section als eigene View-Struct
- RobotSettingsView wird zur Scroll-/List-Container

### RobotDetailView Decomposition Hints
- Status/Controls Section
- Cleaning Actions Section
- Events Section
- Consumables Section
- Properties Section
- RobotDetailView wird zum Container mit NavigationStack

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- MapViewModel, RobotDetailViewModel, RobotSettingsViewModel already extracted (Phase 4)
- Pattern: @StateObject var viewModel in parent, passed to sub-views

### Established Patterns
- Sub-views receive robot: RobotConfig and viewModel via init
- @Binding for two-way state in sub-components
- MVVM: Views are declarative shells, logic in ViewModels

### Integration Points
- MapContentView.swift contains MapView — the 2532 line file
- RobotSettingsView.swift — 1801 lines
- RobotDetailView.swift — 1253 lines
- New files need xcodegen project.yml registration

</code_context>

<specifics>
## Specific Ideas

No specific requirements — follow existing patterns.

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
