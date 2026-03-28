# Phase 7: Bugfixes & Robustness - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase)

<domain>
## Phase Boundary

Phase 7 behebt 4 spezifische Concerns aus dem Codebase-Audit: Force-unwrap URLs, stille Fehler, SSE Reconnect Backoff, und Koordinaten-Transformation in der MapView.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
Alle Implementierungsdetails bei Claude. Codebase-CONCERNS.md als Referenz nutzen.

Key constraints:
- FIX-01: URL(string:) statt URL(string:)! — guard let mit Logger-Fehler
- FIX-02: ErrorRouter.shared.show() für user-facing Fehler, logger.warning() für interne
- FIX-03: Exponential Backoff in SSEConnectionManager.streamWithReconnect() — 1s, 5s, 30s, max 30s
- FIX-04: CGFloat-Arithmetic in MapViewModel splitRoom/zone coordinate transformation

</decisions>

<code_context>
## Existing Code Insights

### Betroffene Dateien (aus CONCERNS.md)
- FIX-01: NetworkScanner.swift:154, RobotDetailView.swift (URL force-unwraps)
- FIX-02: MapViewModel.swift, RobotSettingsViewModel.swift, RobotManager.swift (silent catch blocks)
- FIX-03: SSEConnectionManager.swift:98-105 (30s sleep)
- FIX-04: MapViewModel.swift:276-353 (splitRoom), MapView.swift (gesture coords)

</code_context>

<specifics>
## Specific Ideas

None.

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
