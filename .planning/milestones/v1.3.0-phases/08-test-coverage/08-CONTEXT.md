# Phase 8: Test Coverage - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase)

<domain>
## Phase Boundary

Phase 8 erstellt Unit-Tests für die ViewModels (State-Transitions, Capability-Loading, Error-Handling) und den API-Layer (Request/Response Encoding, HTTP Error Codes). Die Test-Dateien werden im ValetudoAppTests/-Verzeichnis erstellt. Das XCTest-Target muss vom User in Xcode hinzugefügt werden.

WICHTIG: Es existieren bereits 4 Test-Dateien aus v1.2.0 Phase 4:
- ValetudoAppTests/TimerTests.swift
- ValetudoAppTests/ConsumableTests.swift
- ValetudoAppTests/MapLayerTests.swift
- ValetudoAppTests/KeychainStoreTests.swift

Diese NICHT löschen oder überschreiben — nur neue Tests hinzufügen.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
- ViewModel-Tests: Mock-freier Ansatz wo möglich (direkte Property-Prüfung)
- API-Tests: URLProtocol-basierte Mocking für HTTP-Responses
- @MainActor in Tests: Einzelne Methoden annotieren, nicht die Klasse

</decisions>

<code_context>
## Existing Code Insights

### Bestehende Test-Patterns (aus Phase 4)
- XCTestCase mit setUp/tearDown
- JSONDecoder für Struct-Konstruktion
- Direkte Property-Assertions
- Unique UUIDs pro Test + tearDown Cleanup

</code_context>

<specifics>
## Specific Ideas

None.

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
