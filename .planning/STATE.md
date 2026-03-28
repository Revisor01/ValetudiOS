---
gsd_state_version: 1.0
milestone: v1.3.0
milestone_name: Polish & Full API Coverage
status: verifying
stopped_at: Completed 08-test-coverage 08-01-PLAN.md
last_updated: "2026-03-28T15:33:35.490Z"
last_activity: 2026-03-28
progress:
  total_phases: 8
  completed_phases: 7
  total_plans: 25
  completed_plans: 24
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-28)

**Core value:** Zuverlässige, native iOS-Steuerung von Valetudo-Robotern ohne Cloud-Abhängigkeit
**Current focus:** Phase 08 — test-coverage

## Current Position

Phase: 08 (test-coverage) — EXECUTING
Plan: 2 of 2
Status: Phase complete — ready for verification
Last activity: 2026-03-28

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity (v1.2.0 reference):**

- Total plans completed: 13
- Average duration: ~12 min/plan
- Total execution time: ~2.5h

**By Phase (v1.2.0):**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-foundation | 3 | ~31min | ~10min |
| 02-network-layer | 3 | ~33min | ~11min |
| 03-api-completeness | 3 | ~10min | ~3min |
| 04-view-refactoring-tests | 4 | ~69min | ~17min |

**By Phase (v1.3.0):**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 05-ui-restore | TBD | - | - |
| 06-new-capabilities | TBD | - | - |
| 07-bugfixes-robustness | TBD | - | - |
| 08-test-coverage | TBD | - | - |

*Updated after each plan completion*
| Phase 05-ui-restore P02 | 15min | 2 tasks | 3 files |
| Phase 05-ui-restore P01 | 3min | 2 tasks | 4 files |
| Phase 06-new-capabilities P01 | 8min | 2 tasks | 4 files |
| Phase 06-new-capabilities P02 | 7min | 2 tasks | 4 files |
| Phase 06-new-capabilities P04 | 5min | 2 tasks | 4 files |
| Phase 07-bugfixes-robustness P03 | 2min | 1 tasks | 1 files |
| Phase 07-bugfixes-robustness P02 | 8min | 2 tasks | 2 files |
| Phase 08-test-coverage P02 | 1min | 1 tasks | 1 files |
| Phase 08-test-coverage P01 | 2min | 2 tasks | 3 files |

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
- [Phase 05-ui-restore]: restoreMapSnapshot() reloads mapSnapshots after restore using try? fallback — keeps UI consistent without failing if reload errors
- [Phase 05-ui-restore]: Pending Map Change section is double-gated: hasPendingMapChange AND pendingMapChangeEnabled — hides section when no change is pending
- [Phase 05-ui-restore]: loadObstacles() uses api.getMap() directly — RobotManager has no mapData dict
- [Phase 05-ui-restore]: Events always available (hasEvents = true) — no Valetudo capability gate for /valetudo/events
- [Phase 06-new-capabilities]: VoicePack Structs am Ende der ValetudoAPI.swift definiert; setVoicePack() laedt Zustand bei Fehler automatisch neu; Section doppelt gated (hasVoicePack AND !voicePacks.isEmpty)
- [Phase 06-new-capabilities]: StationSettingsView nutzt lokale @State statt RobotSettingsViewModel — Duration-Picker in StationSettingsView mit lokalen State-Properties implementiert
- [Phase 06-new-capabilities]: displayNameForAutoEmptyDockDuration() nutzt preset.* l10n-Keys statt eigenem Enum
- [Phase 06-new-capabilities]: RobotProperties all fields optional — different Valetudo versions return different fields, optional Codable prevents runtime crashes
- [Phase 06-new-capabilities]: Properties section nil-gated (if let props = viewModel.robotProperties) — no Capability gate needed since /robot/properties is a base endpoint
- [Phase 07-bugfixes-robustness]: [Phase 07-bugfixes-robustness]: SSE backoff uses retryCount-based switch (1s/5s/30s) — retryCount reset to 0 after successful connect; each retry attempt logged with count and delay
- [Phase 07-bugfixes-robustness]: MapViewModel uses @Published errorMessage for cleanSelectedRooms failures — not ErrorRouter.shared — consistent with established ViewModel pattern
- [Phase 07-bugfixes-robustness]: checkUpdaterState failure uses logger.warning only — not user-facing, not actionable by user
- [Phase 08-test-coverage]: ValetudoAPI actor private URLSession: test APIError, RobotConfig.baseURL, and JSON decoding without session injection
- [Phase 08-test-coverage]: @MainActor per test method (not class) — consistent with existing KeychainStoreTests/TimerTests pattern

### v1.3.0 Context

- Phase 5 (UI Restore): API-Methoden und Modelle aus Phase 3 existieren bereits. Nur ViewModel/View-Verdrahtung fehlt.
- Phase 6 (New Capabilities): Neue API-Methoden + Modelle + UI erforderlich. Capability-IDs in Valetudo-Doku prüfen.
- Phase 7 (Bugfixes): FIX-04 (Koordinaten) betrifft MapViewModel — nach Float-to-CGFloat-Analyse im Codebase-Doc vorgehen.
- Phase 8 (Tests): @MainActor-Isolation in XCTest — einzelne Test-Methoden annotieren, nicht die Klasse (bekanntes Pitfall).

### Pending Todos

None.

### Blockers/Concerns

- Phase 5: UIR-06 (Notification-Actions) — AppDelegate-Handler muss nach ViewModel-Extraktion korrekt verdrahtet sein; robotManagerRef-Pattern aus Phase 3 als Vorlage nutzen.
- Phase 8: @MainActor-Isolation in XCTest — einzelne Test-Methoden annotieren, nicht die Klasse.

## Session Continuity

Last session: 2026-03-28T15:33:35.488Z
Stopped at: Completed 08-test-coverage 08-01-PLAN.md
Resume file: None
