---
phase: 07-bugfixes-robustness
plan: 02
subsystem: ui
tags: [swift, ios, logging, error-handling, viewmodel]

requires:
  - phase: 04-view-refactoring-tests
    provides: MapViewModel and RobotManager with established patterns

provides:
  - Silent catch blocks replaced with os.Logger warnings/errors in MapViewModel and RobotManager
  - @Published errorMessage on MapViewModel for user-facing clean failures

affects: [08-testing, any view consuming MapViewModel.errorMessage]

tech-stack:
  added: [os (import added to MapViewModel)]
  patterns: [logger.warning for non-actionable API failures, logger.error + @Published errorMessage for user-facing failures]

key-files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift
    - ValetudoApp/ValetudoApp/Services/RobotManager.swift

key-decisions:
  - "MapViewModel uses @Published errorMessage for user-facing clean failures — not ErrorRouter.shared — consistent with established ViewModel pattern"
  - "checkUpdaterState failure uses logger.warning only — not user-facing, not actionable by user"
  - "checkConsumables silent catch left in place — out of scope for this plan (not listed in plan interfaces)"

patterns-established:
  - "logger.error + errorMessage = for user-facing failures where action is possible"
  - "logger.warning = for background/capability failures not actionable by user"

requirements-completed: [FIX-02]

duration: 8min
completed: 2026-03-28
---

# Phase 07 Plan 02: Silent Error Logging Summary

**Three silent catch blocks in MapViewModel and RobotManager replaced with os.Logger calls and a @Published errorMessage for user-facing clean failures**

## Performance

- **Duration:** 8 min
- **Started:** 2026-03-28T15:10:00Z
- **Completed:** 2026-03-28T15:19:29Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Added `import os` and `Logger` instance to MapViewModel (was missing)
- Added `@Published var errorMessage: String?` to MapViewModel for alerting on clean failures
- Replaced capability check silent catch with `logger.warning`
- Replaced cleanSelectedRooms silent catch with `logger.error` + `errorMessage = error.localizedDescription`
- Replaced checkUpdaterState silent catch with `logger.warning` including robot id and error

## Task Commits

Each task was committed atomically:

1. **Task 1: MapViewModel silent catches durch logging ersetzen** - `f31ff7b` (feat)
2. **Task 2: RobotManager checkUpdaterState silent catch loggen** - `c1a95cb` (fix)

**Plan metadata:** see final metadata commit (docs)

## Files Created/Modified
- `ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift` - Added os import, Logger, @Published errorMessage, replaced 2 silent catches
- `ValetudoApp/ValetudoApp/Services/RobotManager.swift` - Replaced 1 silent catch in checkUpdateForRobot

## Decisions Made
- MapViewModel uses @Published errorMessage for cleanSelectedRooms failures rather than ErrorRouter.shared — consistent with established ViewModel pattern from Phase 04
- checkUpdaterState warning-only (no user alert) — failure is expected for robots that don't support the updater capability
- checkConsumables silent catch at line 248 of RobotManager is pre-existing and out of scope for this plan; deferred

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added import os and Logger to MapViewModel**
- **Found during:** Task 1
- **Issue:** Plan specified using `logger.warning` but MapViewModel had no `import os` and no `logger` property
- **Fix:** Added `import os` at top of file and `private let logger = Logger(...)` in the class body
- **Files modified:** ValetudoApp/ValetudoApp/ViewModels/MapViewModel.swift
- **Verification:** Build succeeded without errors
- **Committed in:** f31ff7b (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** Required for the plan's own instructions to compile. No scope creep.

## Issues Encountered
- checkConsumables (line 248 of RobotManager.swift) also has a `// Silently ignore` but was not listed in the plan's interfaces or action spec. Left in place per scope boundary rules. Noted for future plan.

## Known Stubs
None - no placeholder values or TODO stubs introduced.

## Next Phase Readiness
- errorMessage @Published on MapViewModel is ready for view-layer .alert wiring (Phase 08 or UI polish)
- All three specified silent catches replaced; logging infrastructure now consistent across MapViewModel and RobotManager

---
*Phase: 07-bugfixes-robustness*
*Completed: 2026-03-28*
