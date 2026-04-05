# Phase 5: UI Restore - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning
**Mode:** Auto-generated (restoration phase — discuss skipped)

<domain>
## Phase Boundary

Phase 5 verdrahtet die in Phase 3 implementierten API-Capabilities (Events, CleanRoute, MapSnapshots, PendingMapChange, ObstaclePhotos, Notification-Actions) in den neuen ViewModels aus Phase 4. Die API-Methoden in ValetudoAPI.swift und die Model-Structs in RobotState.swift existieren bereits — nur die ViewModel-Properties, -Methoden und View-Sections fehlen.

**Wichtig:** Die Phase-4 ViewModel-Extraktion hat die Phase-3 UI-Änderungen überschrieben, weil die Worktree-Agents auf einem älteren Branch basierten. Die API-Schicht ist intakt.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
Alle Implementierungsdetails liegen bei Claude. Die Patterns aus den bestehenden ViewModels (capability-gating, async loading, ErrorRouter) als Vorlage nutzen.

Wichtige Constraints:
- Alle neuen UI-Sections müssen capability-gated sein (existierendes Pattern: `hasXYZ` Bool in ViewModel)
- ViewModels nutzen @Published Properties, Views nutzen viewModel.xyz
- Notification-Actions brauchen AppDelegate + static weak var robotManagerRef Pattern (aus Phase 3 Decisions)
- ObstaclePhotoView.swift existiert bereits als eigene Datei

</decisions>

<code_context>
## Existing Code Insights

### Vorhandene API-Methoden (ValetudoAPI.swift)
- `getMapSnapshots()` / `restoreMapSnapshot(id:)`
- `getPendingMapChange()` / `handlePendingMapChange(action:)`
- `getCleanRoute()` / `setCleanRoute(route:)`
- `getEvents()` (dict/array Fallback)
- `getObstacleImage(id:)` (binary fetch)

### Vorhandene Models (RobotState.swift)
- `MapSnapshot` (Identifiable, id: String)
- `PendingMapChangeState` (enabled: Bool)
- `CleanRouteState` (route: String)
- `ValetudoEvent` (Identifiable, displayName, iconName, processed, timestamp)

### Vorhandene View (ObstaclePhotoView.swift)
- Nimmt obstacleId, label, api als Parameter
- Lazy-Loading mit task(id:)

### ViewModel-Pattern (Vorlage)
- RobotDetailViewModel: @Published properties + async load methods + capability bools
- RobotSettingsViewModel: @Published properties + async load/set methods + capability bools
- Capability-Check: `hasXYZ = DebugConfig.showAllCapabilities || capabilities.contains("XYZCapability")`

</code_context>

<specifics>
## Specific Ideas

Keine spezifischen Anforderungen — bestehende Patterns wiederverwenden.

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
