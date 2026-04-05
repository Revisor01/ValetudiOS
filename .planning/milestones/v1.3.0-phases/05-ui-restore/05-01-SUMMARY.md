---
phase: 05-ui-restore
plan: 01
subsystem: ui
tags: [swiftui, valetudo, events, clean-route, obstacle-images, capability-gated]

# Dependency graph
requires:
  - phase: 03-api-completeness
    provides: getEvents, getCleanRoute, setCleanRoute, getObstacleImage API methods
  - phase: 04-view-refactoring-tests
    provides: RobotDetailViewModel, RobotDetailView MVVM structure
provides:
  - Events section in RobotDetailView (capability-gated, with dismiss)
  - CleanRoute picker in RobotDetailView (capability-gated, with presets)
  - Obstacle photos section in RobotDetailView (capability-gated, NavigationLink to ObstaclePhotoView)
  - dismissEvent(id:) and getCleanRoutePresets() API methods
  - hasEvents, hasCleanRoute, hasObstacleImages capability flags in RobotDetailViewModel
affects: [06-ui-polish, future-testing]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - capability-gated section pattern (hasCapability flag + non-empty data check)
    - loadObstacles via api.getMap() — no direct robotManager.mapData access needed

key-files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift
    - ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift
    - ValetudoApp/ValetudoApp/Views/RobotDetailView.swift
    - ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings

key-decisions:
  - "loadObstacles() uses api.getMap() directly — RobotManager has no mapData dict, map fetched fresh on detail open"
  - "Events always available (hasEvents = true in loadCapabilities) — no Valetudo capability gate for /valetudo/events"
  - "Used existing detail.events and detail.clean_route localization keys; added detail.obstacles and obstacle.unknown"

patterns-established:
  - "Capability-gated sections: guard with hasXxx flag AND non-empty data, placed as @ViewBuilder private var in extension"
  - "Obstacle load pattern: fetch RobotMap via API, filter entities where metaData.id != nil"

requirements-completed: [UIR-01, UIR-02, UIR-05, UIR-06]

# Metrics
duration: 3min
completed: 2026-03-28
---

# Phase 05 Plan 01: UI Restore Summary

**Events-Section, CleanRoute-Picker und Obstacle-Photos in RobotDetailView verdrahtet — Phase-3 API-Methoden jetzt ueber Phase-4 ViewModel-Layer fuer Benutzer erreichbar**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-28T14:30:32Z
- **Completed:** 2026-03-28T14:33:39Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Events-Section zeigt chronologische Event-Liste mit Dismiss-Button (UIR-01)
- CleanRoute-Picker zeigt verfuegbare Routen aus API-Presets (UIR-02)
- Obstacle-Photos Section navigiert zu ObstaclePhotoView mit ObstacleId und Label (UIR-05)
- Notification-Actions GO_HOME/LOCATE bereits verdrahtet, Build bestaetigt (UIR-06)

## Task Commits

1. **Task 1: API-Erweiterungen und ViewModel-Properties** - `d8e49e2` (feat)
2. **Task 2: Events-Section, CleanRoute-Picker und Obstacles-Section** - `eeec5cd` (feat)

## Files Created/Modified

- `/Users/simonluthe/Documents/valetudo-app/ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift` - Added dismissEvent(id:) and getCleanRoutePresets()
- `/Users/simonluthe/Documents/valetudo-app/ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift` - Added events/cleanRoute/obstacles properties, capability flags, load methods, action methods
- `/Users/simonluthe/Documents/valetudo-app/ValetudoApp/ValetudoApp/Views/RobotDetailView.swift` - Added eventsSection, cleanRouteSection, obstaclesSection @ViewBuilders
- `/Users/simonluthe/Documents/valetudo-app/ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings` - Added detail.obstacles and obstacle.unknown keys (de + en)

## Decisions Made

- `loadObstacles()` verwendet `api.getMap()` direkt — `RobotManager` besitzt kein `mapData`-Dictionary. Plan-Hinweis war korrekt: MapViewModel laedt Map ueber API, dasselbe Pattern wird hier verwendet.
- `hasEvents = true` in `loadCapabilities()` gesetzt — Valetudo hat kein Capability-Gate fuer `/valetudo/events`.
- Bestehende Localization-Keys `detail.events` und `detail.clean_route` verwendet statt neuer Keys; `detail.obstacles` und `obstacle.unknown` neu hinzugefuegt.

## Deviations from Plan

None - plan executed exactly as written. The `loadObstacles()` method used `api.getMap()` as anticipated by the plan's note "Alternative: Map-Entities ueber die API laden falls kein direkter Zugriff auf mapData besteht."

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Events, CleanRoute und Obstacle-Photos sind vollstaendig in die UI integriert
- Alle vier UIR-Requirements (UIR-01, UIR-02, UIR-05, UIR-06) erfuellt
- Bereit fuer weitere UI-Verbesserungen oder Testing

## Self-Check: PASSED

All files confirmed present. All commits confirmed in git log.

---
*Phase: 05-ui-restore*
*Completed: 2026-03-28*
