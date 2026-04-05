---
phase: 03-api-completeness
plan: 03
subsystem: UI / Views
tags: [swiftui, capabilities, events, cleanroute, obstacles, localization]
dependency_graph:
  requires: [03-01]
  provides: [cleanRouteSection, eventsSection, ObstaclePhotoView]
  affects: [ValetudoApp/ValetudoApp/Views/RobotDetailView.swift, ValetudoApp/ValetudoApp/Views/ObstaclePhotoView.swift, ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings]
tech_stack:
  added: []
  patterns: [capability-gated UI, ViewBuilder sections, lazy image loading via task(id:), EnvironmentObject injection]
key_files:
  created:
    - ValetudoApp/ValetudoApp/Views/ObstaclePhotoView.swift
  modified:
    - ValetudoApp/ValetudoApp/Views/RobotDetailView.swift
    - ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings
    - ValetudoApp/ValetudoApp.xcodeproj/project.pbxproj
decisions:
  - "errorRouter added as @EnvironmentObject to RobotDetailView — needed to display errors from setCleanRoute Picker binding"
  - "ObstaclePhotoView registered in project.pbxproj manually (PBXBuildFile + PBXFileReference + Views group + Sources phase)"
  - "Events loaded unconditionally in loadData() parallel chain — no capability gate needed since endpoint returns empty array when unsupported"
metrics:
  duration: "~15 min"
  completed: "2026-03-27"
  tasks: 2
  files_modified: 4
requirements: [API-03, API-04, UX-04]
---

# Phase 03 Plan 03: Events, CleanRoute, ObstaclePhotoView Summary

**One-liner:** CleanRoute-Picker mit 4 Routen, Events-Liste mit SF-Symbol-Icons, und ObstaclePhotoView mit Lazy-Loading per task(id:) — alle capability-gated in RobotDetailView integriert.

## What Was Built

### Task 1: Events-Section und CleanRoute-Picker in RobotDetailView

**New @State properties added at top of RobotDetailView:**
- `hasCleanRoute: Bool` — capability flag for CleanRouteControlCapability
- `currentCleanRoute: String` — current selected route ("normal", "quick", "intensive", "deep")
- `cleanRouteOptions: [String]` — static list of available routes
- `events: [ValetudoEvent]` — loaded events array
- `hasObstacleImages: Bool` — capability flag for ObstacleImagesCapability

**@EnvironmentObject ErrorRouter added** — required for the Picker's set-binding to call `errorRouter.show(error)` when `setCleanRoute` fails.

**loadCapabilities() extended:**
- Checks for `CleanRouteControlCapability` and `ObstacleImagesCapability`
- Loads current clean route via `api.getCleanRoute()` after capability check (silently ignored if fails)

**loadEvents() added:**
- New private async function fetching events from `api.getEvents()`
- Called in parallel from `loadData()` alongside segments, consumables, etc.
- Silently ignores errors — endpoint may not be available on all robots

**Two new @ViewBuilder sections:**

`cleanRouteSection` — capability-gated Picker with 4 localized options:
- "normal" → "Standard" (DE) / "Standard" (EN)
- "quick" → "Schnell" (DE) / "Quick" (EN)
- "intensive" → "Intensiv" (DE) / "Intensive" (EN)
- "deep" → "Tiefenreinigung" (DE) / "Deep Clean" (EN)

`eventsSection` — shows up to 10 events when non-empty:
- SF Symbol icon per event type (trash.fill, wrench.fill, drop.fill, etc.)
- Error events highlighted in red, others in secondary color
- Event displayName (localized via ValetudoEvent.displayName computed property)
- Optional message text if present
- ISO timestamp in caption2 style
- Blue dot indicator for unprocessed events

**Localization strings added** (DE + EN) for:
- `detail.clean_route`, `cleanroute.{normal,quick,intensive,deep}`
- `detail.events`, `event.{dustbin_full,consumable_depleted,mop_reminder,error,missing_resource,pending_map_change}`
- `obstacle.{no_image,no_image.description,photo}`

### Task 2: ObstaclePhotoView als neue View-Datei

New file `ValetudoApp/ValetudoApp/Views/ObstaclePhotoView.swift` created:

- `obstacleId: String` — UUID for the obstacle image URL
- `label: String?` — optional human-readable label for navigation title
- `api: ValetudoAPI` — injected directly (not via EnvironmentObject since API is robot-specific)
- `@State imageData: Data?` — loaded binary image data
- `@State isLoading: Bool` — shows ProgressView while fetching
- `@State loadError: Bool` — tracked for future use (ContentUnavailableView shown on nil imageData)

Three UI states:
1. Loading: `ProgressView()` centered in full frame
2. Loaded: `Image(uiImage:)` resizable, aspectFit, rounded corners
3. Error/Missing: `ContentUnavailableView` with photo.badge.exclamationmark

Uses `task(id: obstacleId)` modifier for lazy loading — image only fetched when view appears, and re-fetched if obstacleId changes. This respects the Valetudo rate limit (Pitfall 5).

File registered in `project.pbxproj`:
- PBXFileReference: `A4B057E6983548828E2840DF`
- PBXBuildFile: `5AC8DC8FDF9A485180374DC9`
- Added to Views group and Sources build phase

## Decisions Made

1. **errorRouter as @EnvironmentObject in RobotDetailView** — The CleanRoute Picker's `set` binding runs synchronously and needs to launch a Task for the API call. When that task fails, we need to show an error. `ErrorRouter` is already injected via environment from `ValetudoApp.swift`, so adding `@EnvironmentObject var errorRouter: ErrorRouter` is the correct approach. Preview updated with `.environmentObject(ErrorRouter())`.

2. **ObstaclePhotoView registered in pbxproj manually** — The project uses a `.xcodeproj` with `project.pbxproj` (not XcodeGen). New files must be registered explicitly. Generated UUIDs for both PBXBuildFile and PBXFileReference entries and added to Views group and Sources build phase.

3. **Events loaded unconditionally** — `loadEvents()` runs in parallel with other load tasks regardless of capability check, because the events endpoint returns an empty array or gracefully fails rather than a capability gate error. This is simpler and avoids a sequential dependency between loadCapabilities() and loadEvents().

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Added @EnvironmentObject ErrorRouter to RobotDetailView**
- **Found during:** Task 1 — implementing CleanRoute Picker's error handling
- **Issue:** Plan specified `errorRouter.show(error)` in the Picker's set binding, but `errorRouter` was not declared as an environment object in RobotDetailView
- **Fix:** Added `@EnvironmentObject var errorRouter: ErrorRouter` to RobotDetailView and `.environmentObject(ErrorRouter())` to the Preview
- **Files modified:** RobotDetailView.swift
- **Commit:** 7b85664

## Known Stubs

None — all features are fully wired. The ObstaclePhotoView is navigable from any caller that has an obstacle ID and API reference. No mock data, no hardcoded empty values.

## Commits

| Task | Commit | Files |
|------|--------|-------|
| Task 1: Events + CleanRoute | 7b85664 | RobotDetailView.swift, Localizable.xcstrings |
| Task 2: ObstaclePhotoView | 2af5abd | ObstaclePhotoView.swift, project.pbxproj |

## Self-Check: PASSED

All created files exist on disk, all commits exist in git history.
