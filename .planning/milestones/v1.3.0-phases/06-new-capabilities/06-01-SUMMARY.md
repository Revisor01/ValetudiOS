---
phase: 06-new-capabilities
plan: 01
subsystem: api
tags: [swift, swiftui, valetudo, voice-pack, capability]

# Dependency graph
requires:
  - phase: 05-ui-restore
    provides: RobotSettingsViewModel und RobotSettingsView mit bestehenden Capability-Patterns
provides:
  - VoicePack + VoicePackState Codable Structs in ValetudoAPI.swift
  - getVoicePackState() und setVoicePack(id:) API-Methoden
  - hasVoicePack, voicePacks, currentVoicePackId, isSettingVoicePack published properties im ViewModel
  - Capability-gated Voice Pack Picker Section in RobotSettingsView
  - voice_pack.footer/label/title Lokalisierungskeys (de + en)
affects: [06-new-capabilities, 07-bugfixes-robustness]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - VoicePackManagementCapability follows same Capability-GET/SET pattern as CarpetSensorMode, FanSpeed etc.
    - Picker with onChange guard (isInitialLoad) prevents false-positive triggers on initial load
    - Error recovery in setVoicePack() reloads current state from API on failure

key-files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift
    - ValetudoApp/ValetudoApp/ViewModels/RobotSettingsViewModel.swift
    - ValetudoApp/ValetudoApp/Views/RobotSettingsView.swift
    - ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings

key-decisions:
  - "VoicePack und VoicePackState Structs am Ende der ValetudoAPI.swift Datei definiert (nach closing brace der extension)"
  - "setVoicePack() laedt Zustand bei Fehler automatisch neu — verhindert inkonsistenten UI-State"
  - "Voice Pack Section doppelt gated: hasVoicePack AND !voicePacks.isEmpty — kein leerer Picker moeglich"

patterns-established:
  - "VoicePack capability: GET gibt VoicePackState mit current_language + supported_languages; SET mit action=download + id"

requirements-completed: [CAP-01]

# Metrics
duration: 8min
completed: 2026-03-28
---

# Phase 06 Plan 01: VoicePackManagement Capability Summary

**VoicePackManagementCapability vollstaendig integriert: API-Methoden, ViewModel-State und capability-gated Picker-UI in RobotSettingsView**

## Performance

- **Duration:** 8 min
- **Started:** 2026-03-28T14:46:00Z
- **Completed:** 2026-03-28T14:54:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- VoicePack und VoicePackState Structs als Codable+Identifiable in ValetudoAPI.swift
- getVoicePackState() und setVoicePack(id:) API-Methoden implementiert
- ViewModel laedt Sprachpakete capability-gated in loadSettings(), mit isInitialLoad-Guard
- Picker-Section in RobotSettingsView zeigt verfuegbare Sprachpakete, loest setVoicePack() via onChange aus

## Task Commits

Jeder Task wurde atomar committet:

1. **Task 1: VoicePack API-Methoden und Model-Structs** - `d80ec3b` (feat)
2. **Task 2: VoicePack ViewModel-State und View-Section** - `4382a38` (feat)

## Files Created/Modified
- `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift` - VoicePack/VoicePackState Structs + getVoicePackState()/setVoicePack(id:)
- `ValetudoApp/ValetudoApp/ViewModels/RobotSettingsViewModel.swift` - hasVoicePack/voicePacks/currentVoicePackId published properties + loadVoicePacks/setVoicePack actions
- `ValetudoApp/ValetudoApp/Views/RobotSettingsView.swift` - Capability-gated Voice Pack Picker Section
- `ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings` - voice_pack.footer/label/title (de + en)

## Decisions Made
- VoicePack Structs am Ende der Datei nach der extension definiert — konsistent mit anderen Model-Definitionen
- Section doppelt gated (hasVoicePack AND !voicePacks.isEmpty) — leerer Picker nicht moeglich
- setVoicePack() mit error recovery: laedt currentVoicePackId neu bei API-Fehler

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- VoicePackManagementCapability vollstaendig integriert
- Phase 06 Plan 02 kann mit naechster Capability beginnen
- Keine Blocker

---
*Phase: 06-new-capabilities*
*Completed: 2026-03-28*
