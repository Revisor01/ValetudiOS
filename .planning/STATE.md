---
gsd_state_version: 1.0
milestone: v1.2.0
milestone_name: Quality & API Completeness
status: executing
stopped_at: Completed 02-network-layer 02-01-PLAN.md
last_updated: "2026-03-27T19:18:30.273Z"
last_activity: 2026-03-27
progress:
  total_phases: 4
  completed_phases: 1
  total_plans: 6
  completed_plans: 5
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-27)

**Core value:** Zuverlässige, native iOS-Steuerung von Valetudo-Robotern ohne Cloud-Abhängigkeit
**Current focus:** Phase 02 — network-layer

## Current Position

Phase: 02 (network-layer) — EXECUTING
Plan: 3 of 3
Status: Ready to execute
Last activity: 2026-03-27

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
| Phase 01-foundation P02 | 12 | 2 tasks | 6 files |
| Phase 01-foundation P01 | 15 | 2 tasks | 6 files |
| Phase 01-foundation P03 | 4 | 1 tasks | 4 files |
| Phase 02-network-layer P02 | 8min | 2 tasks | 4 files |
| Phase 02-network-layer P01 | 15m | 2 tasks | 4 files |

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
- [Phase 01-foundation]: selectedRobotId set in onAppear only — Map tab stays visible for last-viewed robot, no false onDisappear triggers
- [Phase 01-foundation]: withErrorAlert(router:) applied at WindowGroup root for single alert source of truth
- [Phase 01-foundation]: KeychainStore uses kSecAttrAccessibleWhenUnlockedThisDeviceOnly for device-only credential storage
- [Phase 01-foundation]: RobotConfig.CodingKeys excludes password — never serialized to UserDefaults JSON
- [Phase 01-foundation]: Keychain migration uses read-back verification before clearing password from UserDefaults blob
- [Phase 01-foundation]: os.Logger subsystem=Bundle.main.bundleIdentifier; body/subnet with .private, error descriptions with .public
- [Phase 01-foundation]: url.path used instead of url.absoluteString in API logging to prevent potential credential leakage
- [Phase 02-network-layer]: MainActor.assumeIsolated used for NWBrowser callbacks — browser started on .main, so isolation guaranteed at runtime without extra dispatch overhead
- [Phase 02-network-layer]: DiscoveredRobot Hashable by host (not UUID) — enables deduplication in mDNS+IP-scan merge
- [Phase 02-network-layer]: SSEConnectionManager uses computed property with backing var for sseSession since Swift actors cannot use lazy stored properties directly
- [Phase 02-network-layer]: ErrorRouter not wired to SSE failures — no shared singleton exists; os.Logger warning + polling fallback provides silent recovery without UI alert spam
- [Phase 02-network-layer]: refreshRobot() removes checkConnection() pre-flight — API call errors treated as offline signal, saving one HTTP round-trip per poll cycle

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 2 (SSE): Valetudo 5-Client-SSE-Limit — SSEConnectionManager muss eine geteilte Verbindung pro Roboter erzwingen. Mit attributes-SSE starten, map-SSE conditional in MapView hinzufügen.
- Phase 4 (Tests): @MainActor-Isolation in XCTest — einzelne Test-Methoden annotieren, nicht die Klasse.

## Session Continuity

Last session: 2026-03-27T19:18:30.268Z
Stopped at: Completed 02-network-layer 02-01-PLAN.md
Resume file: None
