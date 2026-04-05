---
phase: 30-bug-fixes
plan: 01
subsystem: ui, network
tags: [sf-symbols, sse, nwpathmonitor, network, reconnection]

# Dependency graph
requires: []
provides:
  - "dove.fill replaced by bird symbol in SettingsView footer (iOS 17+ compatible)"
  - "SSEConnectionManager reconnects automatically on network path change (WiFi->VPN, LAN->LTE)"
affects: [app-store-submission]

# Tech tracking
tech-stack:
  added: ["Network framework (NWPathMonitor)"]
  patterns:
    - "NWPathMonitor actor integration: path updates dispatched into actor via Task { await self.handle... }"
    - "ConnectionParams struct stored per robot-id for clean reconnect after network restoration"

key-files:
  created: []
  modified:
    - "ValetudoApp/ValetudoApp/Views/SettingsView.swift"
    - "ValetudoApp/ValetudoApp/Services/SSEConnectionManager.swift"

key-decisions:
  - "bird statt dove.fill: SF Symbols verfuegbar ab iOS 16 (dove.fill erst ab iOS 18)"
  - "Reconnect nur bei path.status == .satisfied nach previousStatus != .satisfied: vermeidet Loop bei kurzen Unterbrechungen"

patterns-established:
  - "NWPathMonitor in actor: pathUpdateHandler dispatcht via Task { await self.handle() } fuer Actor-Isolation"

requirements-completed: [FIX-01, FIX-02]

# Metrics
duration: 9min
completed: 2026-04-05
---

# Phase 30 Plan 01: Bug Fixes Summary

**SF Symbols `dove.fill` durch `bird` ersetzt und SSEConnectionManager mit NWPathMonitor fuer automatischen Reconnect bei Netzwerk-Wechsel erweitert**

## Performance

- **Duration:** 9 min
- **Started:** 2026-04-05T18:23:29Z
- **Completed:** 2026-04-05T18:32:30Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- `dove.fill` (iOS 18+ only) in SettingsView Footer durch `bird` (iOS 16+) ersetzt — Symbol erscheint jetzt auf allen Deployment-Target-Geraeten
- `NWPathMonitor` in `SSEConnectionManager` integriert — erkennt Netzwerkpfad-Wechsel und triggert Reconnect aller aktiven SSE-Streams
- Monitor startet automatisch beim ersten `connect()` und stoppt bei `disconnectAll()` oder wenn alle Verbindungen getrennt sind

## Task Commits

1. **Task 1: FIX-01 dove.fill Symbol-Fix** - `1eb1dd7` (fix)
2. **Task 2: FIX-02 NWPathMonitor SSE Reconnection** - `0ddf6af` (feat)

## Files Created/Modified

- `ValetudoApp/ValetudoApp/Views/SettingsView.swift` - `dove.fill` -> `bird` in Settings About Footer
- `ValetudoApp/ValetudoApp/Services/SSEConnectionManager.swift` - `import Network`, `NWPathMonitor`, `ConnectionParams` Struct, `reconnectAll()`, `handlePathUpdate()`

## Decisions Made

- **`bird` statt `dove.fill`:** `dove.fill` ist erst ab SF Symbols 6 / iOS 18 verfuegbar. `bird` existiert seit SF Symbols 4 / iOS 16 und passt zum Deployment Target iOS 17.
- **Reconnect-Bedingung:** Nur bei `path.status == .satisfied` nach `previousStatus != .satisfied` — kein Loop bei kurzem Flackern, kein Reconnect wenn Netzwerk wegbleibt.
- **`ConnectionParams` Struct:** Parameter werden pro Robot-ID gespeichert damit `reconnectAll()` ohne externe Aufrufer auskommt — der Actor ist vollstaendig eigenstaendig.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- xcodebuild akzeptiert `platform=iOS Simulator,name=iPhone 16` nicht ohne OS-Version wegen Xcode 26.4 / iOS 26.4 SDK. Verwendet stattdessen Device-ID direkt. Build SUCCEEDED.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- FIX-01 und FIX-02 sind abgeschlossen — beide Bugs vor App Store Submission behoben
- Phase 31 (Web-Praesenz: Privacy Policy + App-Beschreibung) kann beginnen

## Self-Check: PASSED

- FOUND: SettingsView.swift
- FOUND: SSEConnectionManager.swift
- FOUND: 30-01-SUMMARY.md
- FOUND commit 1eb1dd7 (FIX-01)
- FOUND commit 0ddf6af (FIX-02)
- FOUND: `bird` symbol in SettingsView
- OK: `dove.fill` removed
- FOUND: `NWPathMonitor` in SSEConnectionManager
- FOUND: `import Network` in SSEConnectionManager

---
*Phase: 30-bug-fixes*
*Completed: 2026-04-05*
