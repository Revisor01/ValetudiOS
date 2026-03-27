# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-27)

**Core value:** Zuverlässige, native iOS-Steuerung von Valetudo-Robotern ohne Cloud-Abhängigkeit
**Current focus:** Phase 1 — Foundation

## Current Position

Phase: 1 of 4 (Foundation)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-03-27 — Roadmap erstellt, Milestone v1.2.0 initialisiert

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Roadmap: Keychain-Migration muss Read-back-Verifikation vor UserDefaults-Delete enthalten (Pitfall 2)
- Roadmap: SSE aktiv = Polling explizit deaktiviert; nie beides gleichzeitig (Pitfall 3)
- Roadmap: NSBonjourServices + NSLocalNetworkUsageDescription in project.yml vor NWBrowser-Code eintragen (Pitfall 4)
- Roadmap: @StateObject für alle neuen ViewModels, nie @ObservedObject wenn im View erstellt (Pitfall 1)
- Codebase mapped: .planning/codebase/ (7 documents, 2026-03-27)
- Previous releases: v1.0 (App Store), v1.1.0 (Touchpad steering, floor materials)

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 2 (SSE): Valetudo 5-Client-SSE-Limit — SSEConnectionManager muss eine geteilte Verbindung pro Roboter erzwingen. Mit attributes-SSE starten, map-SSE conditional in MapView hinzufügen.
- Phase 4 (Tests): @MainActor-Isolation in XCTest — einzelne Test-Methoden annotieren, nicht die Klasse.

## Session Continuity

Last session: 2026-03-27
Stopped at: Roadmap erstellt (ROADMAP.md, STATE.md, REQUIREMENTS.md Traceability aktualisiert)
Resume file: None
