---
phase: 01-foundation
plan: 02
subsystem: ui
tags: [swiftui, error-handling, navigation, observable-object]

# Dependency graph
requires: []
provides:
  - ErrorRouter as @MainActor ObservableObject for centralized error display
  - withErrorAlert(router:) View extension for alert presentation with optional retry
  - ErrorRouter injected app-wide via EnvironmentObject
  - NavigationLink(value:) for fully clickable robot list rows
affects: [all views that surface API errors, RobotDetailView navigation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Centralized error routing via ObservableObject injected as EnvironmentObject at app root"
    - "Alert presentation via custom View extension modifier"
    - "NavigationLink(value:) + navigationDestination(for:) for value-based navigation"

key-files:
  created:
    - ValetudoApp/ValetudoApp/Helpers/ErrorRouter.swift
  modified:
    - ValetudoApp/ValetudoApp/ValetudoApp.swift
    - ValetudoApp/ValetudoApp/ContentView.swift
    - ValetudoApp/ValetudoApp/Views/RobotListView.swift
    - ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings
    - ValetudoApp/ValetudoApp.xcodeproj/project.pbxproj

key-decisions:
  - "selectedRobotId set in onAppear of navigationDestination, not cleared on disappear — Map tab stays visible for last-viewed robot (safe UX, no false onDisappear triggers)"
  - "withErrorAlert(router:) applied at WindowGroup root level, not per-view — single alert source of truth"

patterns-established:
  - "Error routing: call errorRouter.show(_:retry:) from any view or service; alert appears automatically"
  - "NavigationLink(value:) pattern: ForEach robot → NavigationLink(value: robot) → navigationDestination(for: RobotConfig.self)"

requirements-completed: [UX-02, UX-01]

# Metrics
duration: 12min
completed: 2026-03-27
---

# Phase 01 Plan 02: Error Routing and NavigationLink Fix Summary

**ErrorRouter as @MainActor ObservableObject with alert modifier injected app-wide, plus NavigationLink(value:) replacing Button for fully clickable robot list rows**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-03-27T17:30:00Z
- **Completed:** 2026-03-27T17:42:00Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- ErrorRouter service created with show/dismiss/retryAction API, injected into entire view hierarchy
- withErrorAlert(router:) View extension provides consistent error alert with optional "Retry" button
- Localization keys error.title and error.retry added for both German and English
- Robot list rows now use NavigationLink(value:) for full-row tap targets
- selectedRobotId wired via onAppear for Map tab visibility

## Task Commits

Each task was committed atomically:

1. **Task 1: ErrorRouter Service + Alert-ViewModifier + App-Injection** - `ac510d4` (feat)
2. **Task 2: NavigationLink(value:) fuer vollstaendig klickbare Robot-Zeile** - `7c09097` (feat)

**Plan metadata:** committed after SUMMARY.md creation (docs)

## Files Created/Modified
- `ValetudoApp/ValetudoApp/Helpers/ErrorRouter.swift` - New: ErrorRouter ObservableObject + withErrorAlert extension
- `ValetudoApp/ValetudoApp/ValetudoApp.swift` - Added errorRouter StateObject, environmentObject, withErrorAlert on both branches
- `ValetudoApp/ValetudoApp/ContentView.swift` - Added @EnvironmentObject errorRouter + Preview injection
- `ValetudoApp/ValetudoApp/Views/RobotListView.swift` - Replaced Button with NavigationLink(value:), removed navigateToRobot state
- `ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings` - Added error.title and error.retry localizations
- `ValetudoApp/ValetudoApp.xcodeproj/project.pbxproj` - Registered ErrorRouter.swift in Helpers group and Sources build phase

## Decisions Made
- `selectedRobotId` is only set in `onAppear` (not cleared on `onDisappear`) to avoid false triggers when pushing secondary views from RobotDetailView. Map tab remains visible for last-viewed robot — acceptable UX.
- Error alert applied at the WindowGroup root level via `withErrorAlert(router:)` on both ContentView and OnboardingView branches, ensuring a single alert source regardless of which view triggers the error.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- xcodebuild destination "iPhone 16" does not exist in this environment; used "iPhone 17" instead. Build succeeded.

## Next Phase Readiness
- ErrorRouter is ready for use: any view or service can inject `@EnvironmentObject var errorRouter: ErrorRouter` and call `errorRouter.show(error)` or `errorRouter.show(error, retry: { ... })`
- Robot navigation foundation is value-based (NavigationLink(value:)) — compatible with future deep-linking or programmatic navigation

---
*Phase: 01-foundation*
*Completed: 2026-03-27*
