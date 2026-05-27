---
gsd_state_version: 1.0
milestone: v4.0.1
milestone_name: OTA Hotfix
status: completed
stopped_at: Phase 34 (OTA Flow Bugfixes) deployed via hotfix b754e24
last_updated: "2026-05-27T10:00:00.000Z"
last_activity: 2026-05-27 -- Phase 34 (OTA Flow Bugfixes) completed, hotfix shipped
progress:
  total_phases: 35
  completed_phases: 35
  total_plans: 35
  completed_plans: 35
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-05)

**Core value:** Zuverlässige, native iOS-Steuerung von Valetudo-Robotern ohne Cloud-Abhängigkeit
**Current focus:** v4.0.1 Hotfix für OTA-Flow live (Commit b754e24), nächste App-Store-Submission als v1.0.1

## Current Position

Milestone: v4.0.1 (OTA Hotfix) — COMPLETED
Last phase: 34 (OTA Flow Bugfixes) — Install-Button, Auto-Refresh nach Reboot, Leave-Warning
Status: Hotfix gepusht (b754e24), live an zwei Robotern verifiziert; App-Store-Submission noch ausstehend
Last activity: 2026-05-27 -- OTA Hotfix shipped

Progress: [██████████] 100%

## Performance Metrics

**Velocity:**

- Total plans completed (v4.0.0): 0
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

*Updated after each plan completion*

## Accumulated Context

### Roadmap Evolution

- Phase 34 added (2026-05-27): OTA Flow Bugfixes als v4.0.1-Hotfix — Install-Button, Refresh nach Reboot, Leave-Warning, Tap-Target-Trennung
- Phase 33 added (2026-04-13): App Store Screenshots — iPhone-only, DE+EN, Logo-Branding-Stil
- Phase 32.1 inserted (2026-04-29): Pre-Release Polish — Bonjour-Discovery-Bugfix + Settings-About-Cleanup als letzte Fixes vor Submission

### Decisions

- v3.0.0 completed: Quality, Performance & Hardening (Phases 22-29)
- Bug Fixes kommen vor Screenshots/Review: FIX-01 (Taube) + FIX-02 (SSE Zombie) müssen vor App Store Submission gefixt sein
- WEB-01/WEB-02 schreiben in /Users/simonluthe/Documents/simon-luthe-website/ (Hugo-Repo, nicht ValetudiOS)
- Koordination mit Website-Agent über APPS-INSTRUCTIONS.md
- Taube-Bug identisch in ValetudiOS und Steadflow — gemeinsamer Fix

### Pending Todos

None.

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-05-27
Stopped at: v4.0.1 OTA Hotfix verifiziert und gepusht (b754e24) — App-Store-Submission als v1.0.1 noch ausstehend
Resume file: None
