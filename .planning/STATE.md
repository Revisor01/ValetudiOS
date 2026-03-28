---
gsd_state_version: 1.0
milestone: v1.3.0
milestone_name: Polish & Full API Coverage
status: defining
stopped_at: null
last_updated: "2026-03-28"
last_activity: 2026-03-28
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-28)

**Core value:** Zuverlässige, native iOS-Steuerung von Valetudo-Robotern ohne Cloud-Abhängigkeit
**Current focus:** Defining requirements for v1.3.0

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-03-28 — Milestone v1.3.0 started

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
| Phase 02-network-layer P03 | 10min | 2 tasks | 2 files |
| Phase 03-api-completeness P01 | 8min | 2 tasks | 3 files |
| Phase 03-api-completeness P02 | 2min | 2 tasks | 3 files |
| Phase 04-view-refactoring-tests P03 | 9min | 2 tasks | 4 files |
| Phase 04-view-refactoring-tests P02 | 15min | 2 tasks | 4 files |
| Phase 04-view-refactoring-tests P04 | 25min | 2 tasks | 3 files |
| Phase 04-view-refactoring-tests P01 | 20min | 2 tasks | 7 files |

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
- [Phase 02-network-layer]: MapLayerCache uses final class (not lazy var) — MapLayer is a struct, lazy var would require mutating which fails in SwiftUI let-binding context
- [Phase 02-network-layer]: Map-SSE lifecycle bounded to MapContentView open/close via refreshTask — SSEConnectionManager handles attributes-SSE only, not map-SSE
- [Phase 03-api-completeness]: getEvents() dict-first then array fallback — API spec ambiguous, defensive decoding avoids runtime crashes across Valetudo versions
- [Phase 03-api-completeness]: getObstacleImage uses raw URLSession.data (not request<T: Decodable>) — binary image data cannot be JSON-decoded
- [Phase 03-api-completeness]: Static weak var robotManagerRef on NotificationService set via onAppear — avoids singleton coupling while staying MainActor-safe
- [Phase 03-api-completeness]: completionHandler() called immediately in didReceive, Task runs independently — UNNotificationCenterDelegate pitfall 6 compliance
- [Phase 03-api-completeness]: No Map Snapshot create button — snapshots created automatically by firmware (pitfall 3)
- [Phase 04-view-refactoring-tests]: @StateObject injected via init with explicit robotManager parameter — not via @EnvironmentObject — to keep ViewModel init testable and self-contained
- [Phase 04-view-refactoring-tests]: RobotManager passed explicitly via RobotDetailView init for @StateObject compatibility (not @EnvironmentObject)
- [Phase 04-view-refactoring-tests]: RobotDetailView reduced from 30+ @State to 2 UI-only @State (showFullMap, showUpdateWarning) after ViewModel extraction
- [Phase 04-view-refactoring-tests]: @StateObject initialized in MapContentView init(robot:robotManager:isFullscreen:) — robotManager passed explicitly to avoid @EnvironmentObject capture issues in non-view context
- [Phase 04-view-refactoring-tests]: Gesture/drawing state (scale, offset, currentDrawStart/End) kept View-local in MapContentView — frame-dependent, tied to SwiftUI render loop
- [Phase 04-view-refactoring-tests]: XcodeGen used for all project changes to avoid hand-editing project.pbxproj
- [Phase 04-view-refactoring-tests]: Timer tests use round-trip invariant (localToUTC(utcToLocal(h,m))==(h,m)) instead of hardcoded UTC offsets for timezone-independence
- [Phase 04-view-refactoring-tests]: MapLayerTests use JSONDecoder to construct structs — avoids fileprivate init and matches production data flow
- [Phase 04-view-refactoring-tests]: KeychainStoreTests use unique UUID per test + tearDown cleanup to prevent cross-test Keychain pollution

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 2 (SSE): Valetudo 5-Client-SSE-Limit — SSEConnectionManager muss eine geteilte Verbindung pro Roboter erzwingen. Mit attributes-SSE starten, map-SSE conditional in MapView hinzufügen.
- Phase 4 (Tests): @MainActor-Isolation in XCTest — einzelne Test-Methoden annotieren, nicht die Klasse.

## Session Continuity

Last session: 2026-03-27T23:47:04.479Z
Stopped at: Completed 04-view-refactoring-tests 04-01-PLAN.md
Resume file: None
