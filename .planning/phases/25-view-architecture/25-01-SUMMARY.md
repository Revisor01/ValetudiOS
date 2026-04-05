---
phase: 25-view-architecture
plan: 01
subsystem: ui
tags: [swiftui, view-decomposition, mvvm, robotdetailview]

# Dependency graph
requires: []
provides:
  - 12 eigenstaendige Section-Sub-Views in Views/Detail/
  - RobotDetailView als reine Orchestrierungs-View (143 Zeilen)
  - UpdateStatusBannerView mit 5 Update-Zustaenden
  - RobotControlSectionView mit Intensity-Menus (@Bindable)
  - AttachmentChipsView mit statischer hasAnyAttachmentInfo-Methode
affects: [25-view-architecture, 27-accessibility, phase-25]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Section-Sub-Views erhalten viewModel als let oder @Bindable — kein @Environment-Workaround"
    - "@Bindable nur wo $-Binding benoetigt wird (Picker, Toggle), sonst let"
    - "AttachmentChipsView.hasAnyAttachmentInfo als static func fuer Inline-Guard im parent"

key-files:
  created:
    - ValetudoApp/ValetudoApp/Views/Detail/UpdateStatusBannerView.swift
    - ValetudoApp/ValetudoApp/Views/Detail/UpdateOverlayView.swift
    - ValetudoApp/ValetudoApp/Views/Detail/RobotStatusHeaderView.swift
    - ValetudoApp/ValetudoApp/Views/Detail/RobotControlSectionView.swift
    - ValetudoApp/ValetudoApp/Views/Detail/LiveStatsChipView.swift
    - ValetudoApp/ValetudoApp/Views/Detail/AttachmentChipsView.swift
    - ValetudoApp/ValetudoApp/Views/Detail/ConsumablesPreviewSectionView.swift
    - ValetudoApp/ValetudoApp/Views/Detail/StatisticsSectionView.swift
    - ValetudoApp/ValetudoApp/Views/Detail/RoomsSectionView.swift
    - ValetudoApp/ValetudoApp/Views/Detail/EventsSectionView.swift
    - ValetudoApp/ValetudoApp/Views/Detail/CleanRouteSectionView.swift
    - ValetudoApp/ValetudoApp/Views/Detail/ObstaclesSectionView.swift
  modified:
    - ValetudoApp/ValetudoApp/Views/RobotDetailView.swift

key-decisions:
  - "AttachmentChipsView hat static func hasAnyAttachmentInfo fuer den Guard in RobotDetailView statt einer lokalen computed property"
  - "CleanRouteSectionView benutzt let viewModel (kein @Bindable) — Binding wird inline mit get/set erzeugt"
  - "PulseAnimation ViewModifier bleibt in RobotDetailSections.swift (bereits dort definiert)"

patterns-established:
  - "Views/Detail/ als Konvention fuer RobotDetailView-Sub-Views"
  - "Sub-Views erhalten viewModel direkt, kein Environment-Workaround noetig"

requirements-completed: [VIEW-01]

# Metrics
duration: 5min
completed: 2026-04-05
---

# Phase 25 Plan 01: View Architecture Summary

**RobotDetailView von 1210 auf 143 Zeilen reduziert durch Extraktion von 12 eigenstaendigen Section-Structs in Views/Detail/**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-04T23:56:20Z
- **Completed:** 2026-04-05T00:01:50Z
- **Tasks:** 2
- **Files modified:** 13

## Accomplishments

- 12 neue Swift-Dateien in ValetudoApp/ValetudoApp/Views/Detail/ — jede mit einem eigenstaendigen View-Struct
- RobotDetailView.swift von 1210 auf 143 Zeilen reduziert (88% Reduktion) — reine Orchestrierung
- Build kompiliert erfolgreich ohne Fehler oder Warnungen

## Task Commits

1. **Task 1: Erstelle Views/Detail/ und extrahiere alle Section-Sub-Views** - `25fa634` (feat)
2. **Task 2: RobotDetailView auf Orchestrierung reduzieren und Build verifizieren** - `2df7861` (feat)

## Files Created/Modified

- `Views/Detail/UpdateStatusBannerView.swift` - 5 Update-Zustaende (available, downloading, readyToApply, inProgress, error) + Fallback-Link
- `Views/Detail/UpdateOverlayView.swift` - Fullscreen Apply/Reboot Overlay mit title/subtitle
- `Views/Detail/RobotStatusHeaderView.swift` - Kompakter Status-Header mit Batterie-Pill, Locate-Button, Model-Name
- `Views/Detail/RobotControlSectionView.swift` - Control-Buttons, Intensity-Menus, Dock-Actions (@Bindable)
- `Views/Detail/LiveStatsChipView.swift` - Live-Stats-Chip mit PulseAnimation-Referenz
- `Views/Detail/AttachmentChipsView.swift` - Dustbin/Water/Mop Chips mit static hasAnyAttachmentInfo
- `Views/Detail/ConsumablesPreviewSectionView.swift` - Consumables Accordion mit Reset-Buttons
- `Views/Detail/StatisticsSectionView.swift` - Statistics Accordion mit staticRow und Hilfsfunktionen
- `Views/Detail/RoomsSectionView.swift` - Rooms Selection mit Clean-Button und Iterations-Picker
- `Views/Detail/EventsSectionView.swift` - Events-Liste mit Dismiss-Button
- `Views/Detail/CleanRouteSectionView.swift` - Clean-Route Picker (inline get/set Binding)
- `Views/Detail/ObstaclesSectionView.swift` - Obstacles-Liste mit NavigationLinks
- `Views/RobotDetailView.swift` - Von 1210 auf 143 Zeilen (reine Orchestrierung)

## Decisions Made

- `AttachmentChipsView` erhaelt eine `static func hasAnyAttachmentInfo` damit RobotDetailView den Guard `if AttachmentChipsView.hasAnyAttachmentInfo(viewModel)` inline machen kann — pragmatischer als eine separate ViewModel-Property
- `CleanRouteSectionView` verwendet `let viewModel` (kein `@Bindable`) und baut das Binding fuer den Picker inline mit `get/set` — funktioniert ohne @Bindable weil RobotDetailViewModel @Observable ist
- `PulseAnimation` ViewModifier verbleibt in `RobotDetailSections.swift` wo er bereits definiert ist — LiveStatsChipView referenziert ihn direkt

## Deviations from Plan

Keine — Plan wurde exakt wie spezifiziert ausgefuehrt.

## Issues Encountered

Keine.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- VIEW-01 vollstaendig erfuellt: 12 Sub-Views in Views/Detail/, RobotDetailView.swift unter 250 Zeilen, Build erfolgreich
- Phase 25 Plan 02 (SettingsSections-Dekomposition oder MapContentView-State) kann beginnen
- Phase 27 (Accessibility) kann VoiceOver-Labels direkt auf die dekomponierte Sub-Views setzen

---
*Phase: 25-view-architecture*
*Completed: 2026-04-05*

## Self-Check: PASSED

Files created:
- FOUND: ValetudoApp/ValetudoApp/Views/Detail/UpdateStatusBannerView.swift
- FOUND: ValetudoApp/ValetudoApp/Views/Detail/UpdateOverlayView.swift
- FOUND: ValetudoApp/ValetudoApp/Views/Detail/RobotStatusHeaderView.swift
- FOUND: ValetudoApp/ValetudoApp/Views/Detail/RobotControlSectionView.swift
- FOUND: ValetudoApp/ValetudoApp/Views/Detail/LiveStatsChipView.swift
- FOUND: ValetudoApp/ValetudoApp/Views/Detail/AttachmentChipsView.swift
- FOUND: ValetudoApp/ValetudoApp/Views/Detail/ConsumablesPreviewSectionView.swift
- FOUND: ValetudoApp/ValetudoApp/Views/Detail/StatisticsSectionView.swift
- FOUND: ValetudoApp/ValetudoApp/Views/Detail/RoomsSectionView.swift
- FOUND: ValetudoApp/ValetudoApp/Views/Detail/EventsSectionView.swift
- FOUND: ValetudoApp/ValetudoApp/Views/Detail/CleanRouteSectionView.swift
- FOUND: ValetudoApp/ValetudoApp/Views/Detail/ObstaclesSectionView.swift

Commits:
- FOUND: 25fa634
- FOUND: 2df7861

RobotDetailView.swift: 143 lines (< 250 requirement met)
Build: SUCCEEDED
