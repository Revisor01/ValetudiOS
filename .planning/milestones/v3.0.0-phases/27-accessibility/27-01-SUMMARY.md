---
phase: 27-accessibility
plan: 01
subsystem: ui
tags: [swiftui, accessibility, voiceover, a11y, localization]

requires:
  - phase: 23-error-handling-robustness-patterns
    provides: ErrorRouter injection pattern used in RobotDetailView

provides:
  - VoiceOver accessibility labels on all control buttons (ControlButton, DockActionButton, MapControlButton, RoomEditButton)
  - Status header combined accessibility element with status + battery info
  - Locate button accessibility label
  - ConsumableRow accessibilityValue with percentage + reset button label
  - Map Canvas accessibilityElement summary label with room count
  - Three localization keys for map canvas (EN/DE/FR)

affects: [28-test-coverage, 29-ux-robustness]

tech-stack:
  added: []
  patterns:
    - ".accessibilityLabel(title) on reusable button components (ControlButton, DockActionButton, MapControlButton, RoomEditButton)"
    - ".accessibilityElement(children: .combine) + computed accessibilityStatusLabel for multi-element status rows"
    - ".accessibilityElement(children: .ignore) + .accessibilityLabel on Canvas for non-interactive graphics"
    - ".accessibilityHidden(true) on decorative icons and redundant text when accessibilityValue covers the info"

key-files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/Views/RobotDetailSections.swift
    - ValetudoApp/ValetudoApp/Views/MapControlBarsView.swift
    - ValetudoApp/ValetudoApp/Views/RobotDetailView.swift
    - ValetudoApp/ValetudoApp/Views/ConsumablesView.swift
    - ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift
    - ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings

key-decisions:
  - "accessibilityLabel(title) placed directly on Button (not on label VStack) — correct SwiftUI pattern"
  - "compactStatusHeader uses .accessibilityElement(children: .combine) so VoiceOver reads status+battery as one element"
  - "Map Canvas uses .accessibilityElement(children: .ignore) + .accessibilityAddTraits(.isImage) — tap targets in tapTargetsOverlay remain separately accessible via their Button labels"
  - "canvasAccessibilityLabel is a computed property dynamically reflecting room count and selection state"

patterns-established:
  - "Reusable button components own their .accessibilityLabel — callers do not need to add it"
  - "Multi-element header rows combine into one VoiceOver element via .accessibilityElement(children: .combine)"
  - "Canvas elements get .accessibilityElement(children: .ignore) to prevent VoiceOver entering drawing context"

requirements-completed: [A11Y-01, A11Y-02, A11Y-03, A11Y-04, A11Y-05]

duration: 7min
completed: 2026-04-05
---

# Phase 27 Plan 01: Accessibility Summary

**VoiceOver accessibility labels on all interactive controls, status header, consumable progress bars, and map canvas via .accessibilityLabel/.accessibilityValue/.accessibilityElement modifiers**

## Performance

- **Duration:** 7 min
- **Started:** 2026-04-05T00:28:53Z
- **Completed:** 2026-04-05T00:35:53Z
- **Tasks:** 5
- **Files modified:** 6

## Accomplishments

- ControlButton, DockActionButton, MapControlButton, RoomEditButton all have `.accessibilityLabel(title)` — VoiceOver announces button action instead of reading icon name
- Status header combines online/offline status, model name and battery level into one VoiceOver element via `.accessibilityElement(children: .combine)` with a computed `accessibilityStatusLabel`
- Locate button (icon-only waveform) gets `.accessibilityLabel(String(localized: "action.locate"))`
- ConsumableRow VStack gets `.accessibilityValue` with formatted percentage; icon and remaining-display text hidden from VoiceOver; reset button labeled with `consumables.reset_title`
- Map Canvas gets `.accessibilityElement(children: .ignore)` and `.accessibilityLabel(canvasAccessibilityLabel)` — dynamic label reports room count and selection state; three new localization keys in EN/DE/FR

## Task Commits

All tasks combined into one atomic commit (all changes tightly coupled, build verified together):

1. **Tasks 1-5: VoiceOver accessibility for all interactive elements** - `3af778e` (feat)

## Files Created/Modified

- `ValetudoApp/ValetudoApp/Views/RobotDetailSections.swift` - `.accessibilityLabel(title)` on ControlButton and DockActionButton
- `ValetudoApp/ValetudoApp/Views/MapControlBarsView.swift` - `.accessibilityLabel(title)` on MapControlButton and RoomEditButton
- `ValetudoApp/ValetudoApp/Views/RobotDetailView.swift` - `accessibilityStatusLabel` computed property, `.accessibilityElement(children: .combine)` on status header, locate button label
- `ValetudoApp/ValetudoApp/Views/ConsumablesView.swift` - `.accessibilityValue` on progress VStack, `.accessibilityHidden(true)` on icon+text, reset button label
- `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift` - `.accessibilityElement(children: .ignore)` + `canvasAccessibilityLabel` on Canvas
- `ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings` - Three new `map.accessibility_label_*` keys in EN/DE/FR

## Decisions Made

- `accessibilityLabel(title)` placed on the Button itself (not inside the label VStack) — correct SwiftUI placement ensures VoiceOver reads it for the interactive element
- `compactStatusHeader` uses `.accessibilityElement(children: .combine)` so the entire row reads as one sentence rather than individual fragments
- Map Canvas uses `.accessibilityElement(children: .ignore)` — the overlaid tap-target buttons in `tapTargetsOverlay` retain their own VoiceOver accessibility and are the preferred way to interact with rooms via VoiceOver
- `canvasAccessibilityLabel` is a computed property (not a static string) so it dynamically reflects the current room count and selection state

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Next Phase Readiness

- A11Y-01 through A11Y-05 all fulfilled
- Phase 27 Plan 02 can add accessibility to remaining views (ManualControlView touchpad, TimersView, Settings toggles)
- The established pattern (`.accessibilityLabel(title)` on reusable button components) should be applied to any new button components in future phases

---
*Phase: 27-accessibility*
*Completed: 2026-04-05*
