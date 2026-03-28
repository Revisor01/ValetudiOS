# Phase 6: New Capabilities - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 6 integriert vier neue Valetudo-Capabilities die bisher nicht in der App vorhanden sind: VoicePackManagement, AutoEmptyDockDuration, MopDockDryingTime und Robot Properties. Jede braucht: neue API-Methoden in ValetudoAPI.swift, ggf. neue Model-Structs, ViewModel-Integration und UI-Section (capability-gated).

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
Alle Implementierungsdetails bei Claude. Bestehende Patterns wiederverwenden:
- API-Methoden: GET/PUT Pattern wie bei existierenden Capabilities
- Models: Codable Structs wie MapSnapshot, CleanRouteState etc.
- ViewModel: @Published properties + capability-gated loading
- Views: Sections in RobotSettingsView (VoicePack, AutoEmpty, MopDock) und RobotDetailView (Properties)

Valetudo API v2 Endpunkte (aus Research):
- VoicePack: GET/PUT `/api/v2/robot/capabilities/VoicePackManagementCapability`
- AutoEmptyDuration: GET/PUT `/api/v2/robot/capabilities/AutoEmptyDockAutoEmptyDurationControlCapability/preset`
- MopDockDrying: GET/PUT `/api/v2/robot/capabilities/MopDockMopDryingTimeControlCapability/preset`
- Robot Properties: GET `/api/v2/robot/properties`

</decisions>

<code_context>
## Existing Code Insights

### Etablierte Patterns
- Preset-Capabilities: getFanSpeedPresets/setFanSpeed als Vorlage für Duration/DryingTime
- Toggle-Capabilities: getCarpetMode/setCarpetMode als Vorlage
- Complex Capabilities: getQuirks/setQuirk als Vorlage für VoicePack

</code_context>

<specifics>
## Specific Ideas

Robot Properties (CAP-04) als eigenständige Section in RobotDetailView — nicht in Settings, da es Info ist (nicht Einstellung).

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
