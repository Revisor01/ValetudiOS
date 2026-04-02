---
phase: 17-background-monitoring
plan: 01
subsystem: infra
tags: [BackgroundTasks, BGAppRefreshTask, UserDefaults, NotificationService, iOS17]

# Dependency graph
requires:
  - phase: 15-ui-wiring
    provides: NotificationService with 5 notification types fully implemented
  - phase: 02-network-layer
    provides: ValetudoAPI actor with getAttributes() endpoint

provides:
  - BackgroundMonitorService singleton with BGAppRefreshTask handler
  - PersistedRobotStatus in UserDefaults per robot UUID (bg_last_status_)
  - State comparison logic (cleaning->docked/idle, stuck, error) in background context
  - BGTaskSchedulerPermittedIdentifiers in Info.plist and project.yml

affects:
  - 17-background-monitoring/17-02 (AppDelegate registration + scheduling)

# Tech tracking
tech-stack:
  added: [BackgroundTasks framework (import BackgroundTasks)]
  patterns:
    - BGAppRefreshTask handler with immediate reschedule + expiration handler
    - NotificationService calls wrapped in Task { @MainActor in } from background context
    - UserDefaults JSON snapshot (PersistedRobotStatus: Codable) for cross-launch state comparison
    - BackgroundMonitorService reads RobotConfigs directly from UserDefaults (avoids @MainActor RobotManager)

key-files:
  created:
    - ValetudoApp/ValetudoApp/Services/BackgroundMonitorService.swift
  modified:
    - ValetudoApp/ValetudoApp/Info.plist
    - ValetudoApp/project.yml

key-decisions:
  - "BackgroundMonitorService.taskIdentifier als static let — Plan 02 AppDelegate referenziert diesen statt doppelte String-Literale"
  - "project.yml muss BGTaskSchedulerPermittedIdentifiers enthalten, damit xcodegen generate den Eintrag nicht ueberschreibt"
  - "PersistedRobotStatus als private nested struct in BackgroundMonitorService — kein shared type noetig, Kapselung bleibt erhalten"

patterns-established:
  - "Pattern: BGTask immer sofort reschedulen (erste Zeile im Handler), dann Arbeit starten — garantiert Folge-Zyklus auch bei Abbruch"
  - "Pattern: task.setTaskCompleted(success:) in Expiration Handler (false) UND nach Abschluss der Arbeit (true)"
  - "Pattern: @MainActor-Services (NotificationService) aus non-isolated Context via Task { @MainActor in } aufrufen"

requirements-completed: [BG-01, BG-02, BG-03]

# Metrics
duration: 12min
completed: 2026-04-01
---

# Phase 17 Plan 01: Background Monitor Service Summary

**BGAppRefreshTask-Infrastruktur mit BackgroundMonitorService, UserDefaults-State-Persistenz und NotificationService-Integration fuer Hintergrund-Roboter-Monitoring**

## Performance

- **Duration:** 12 min
- **Started:** 2026-04-01T21:46:00Z
- **Completed:** 2026-04-01T21:58:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- BackgroundMonitorService als Singleton implementiert mit vollstaendigem BGAppRefreshTask-Handler (Reschedule, Expiration, setTaskCompleted in allen Pfaden)
- UserDefaults-Persistenz fuer Roboter-Status-Snapshots (PersistedRobotStatus: Codable, Key-Schema bg_last_status_<UUID>)
- State-Vergleichslogik aus RobotManager portiert (cleaning->docked/idle, stuck, error) mit MainActor-isoliertem Notification-Dispatch
- Info.plist und project.yml mit BGTaskSchedulerPermittedIdentifiers vorbereitet

## Task Commits

1. **Task 1: Info.plist BGTaskSchedulerPermittedIdentifiers eintragen** - `52204c3` (chore)
2. **Task 2: BackgroundMonitorService implementieren** - `9d8dafb` (feat)

## Files Created/Modified
- `ValetudoApp/ValetudoApp/Services/BackgroundMonitorService.swift` - Singleton BGTask-Handler, State-Persistenz, Notification-Dispatch
- `ValetudoApp/ValetudoApp/Info.plist` - BGTaskSchedulerPermittedIdentifiers eingetragen
- `ValetudoApp/project.yml` - BGTaskSchedulerPermittedIdentifiers fuer XcodeGen-Persistenz

## Decisions Made
- `BackgroundMonitorService.taskIdentifier` als `static let` definiert — Plan 02 AppDelegate referenziert diesen direkt, keine duplizierten String-Literale
- `project.yml` musste ebenfalls aktualisiert werden: XcodeGen ueberschreibt Info.plist bei `xcodegen generate`, daher muss der Eintrag in beiden Dateien stehen
- `PersistedRobotStatus` als `private` nested struct — Kapselung innerhalb BackgroundMonitorService, kein oeffentlicher shared type noetig

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] project.yml mit BGTaskSchedulerPermittedIdentifiers ergaenzt**
- **Found during:** Task 2 (BackgroundMonitorService + xcodegen generate)
- **Issue:** Der Plan beschreibt nur die Aenderung an Info.plist, aber XcodeGen generiert Info.plist aus project.yml. Beim naechsten `xcodegen generate` wuerde der BGTaskSchedulerPermittedIdentifiers-Eintrag verloren gehen.
- **Fix:** BGTaskSchedulerPermittedIdentifiers auch in project.yml unter `info.properties` eingetragen. XcodeGen ausgefuehrt, Build verifiziert.
- **Files modified:** ValetudoApp/project.yml
- **Verification:** xcodegen generate ausgefuehrt, Info.plist enthaelt Eintrag, BUILD SUCCEEDED
- **Committed in:** 9d8dafb (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 2 — Missing Critical)
**Impact on plan:** Notwendig fuer Dauerhaftigkeit des Info.plist-Eintrags. Kein Scope Creep.

## Issues Encountered
Keine — Build war beim ersten Versuch erfolgreich.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- BackgroundMonitorService vollstaendig implementiert und kompiliert
- Plan 02 kann BGTaskScheduler.shared.register() in AppDelegate verdrahten via `BackgroundMonitorService.taskIdentifier` und `BackgroundMonitorService.shared.handleBackgroundRefresh()`
- scheduleBackgroundRefresh() kann in applicationDidEnterBackground aufgerufen werden
- Kein Blocker fuer Plan 02

---
*Phase: 17-background-monitoring*
*Completed: 2026-04-01*
