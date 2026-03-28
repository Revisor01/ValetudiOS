# Phase 9: Logger Migration - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase — discuss skipped)

<domain>
## Phase Boundary

Kein einziger print()-Aufruf verbleibt in Views oder Services; alle Concurrency-Patterns folgen Swift Structured Concurrency. Betrifft 30 print()-Stellen in 8 View-Dateien + SupportManager, plus DispatchQueue→Task.sleep in SupportReminderView.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — pure infrastructure phase. Use established os.Logger pattern from existing ViewModels (subsystem=Bundle.main.bundleIdentifier, category=type name). Follow ROADMAP phase goal, success criteria, and codebase conventions.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- os.Logger already used in: RobotDetailViewModel, RobotSettingsViewModel, MapViewModel, ValetudoAPI, NotificationService, RobotManager, NWBrowserService, NetworkScanner, SSEConnectionManager
- Pattern: `private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ValetudiOS", category: "TypeName")`

### Established Patterns
- Privacy: `.private` for sensitive data (IPs, hostnames), `.public` for error descriptions
- Error logging: `logger.error("Description: \(error.localizedDescription, privacy: .public)")`
- Debug logging: `logger.debug("...")` for verbose output

### Integration Points
- Files needing Logger: DoNotDisturbView, StatisticsView, IntensityControlView, MapView, ManualControlView, RoomsManagementView, TimersView, SupportManager
- SupportReminderView: DispatchQueue.main.asyncAfter → Task.sleep migration

</code_context>

<specifics>
## Specific Ideas

No specific requirements — infrastructure phase. Follow existing Logger pattern exactly.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
