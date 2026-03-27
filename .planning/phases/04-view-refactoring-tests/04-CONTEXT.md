# Phase 4: View Refactoring & Tests - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase — discuss skipped)

<domain>
## Phase Boundary

Phase 4 extrahiert Logik aus den drei monolithischen Views (MapView, RobotDetailView, RobotSettingsView) in dedizierte @MainActor ViewModels und erstellt ein XCTest-Target mit Tests für Timer-Konvertierung, Consumable-Prozente, Map-RLE-Dekompression und Keychain-Round-Trip.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — pure refactoring/infrastructure phase. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

Key constraints from success criteria:
- ViewModels müssen @MainActor sein
- Views müssen @StateObject (nicht @ObservedObject) für ViewModels nutzen
- XCTest-Target muss 4 spezifische Test-Kategorien abdecken

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- MapView (~1900 Zeilen), RobotDetailView (~1400 Zeilen), RobotSettingsView (~800 Zeilen)
- Bestehende Services: RobotManager, ValetudoAPI, SSEConnectionManager, NotificationService
- KeychainStore für Credential-Tests

### Established Patterns
- @MainActor für Services (RobotManager, NetworkScanner)
- ObservableObject mit @Published Properties
- Async/await mit Task {} in Views

### Integration Points
- ViewModels ersetzen @State Properties in Views
- XCTest-Target braucht Zugriff auf Models und Services

</code_context>

<specifics>
## Specific Ideas

No specific requirements — infrastructure phase. Refer to ROADMAP phase description and success criteria.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
