---
gsd_state_version: 1.0
milestone: v1.2.0
milestone_name: Quality & API Completeness
status: executing
last_updated: "2026-04-01T17:15:42.291Z"
last_activity: 2026-04-01
progress:
  total_phases: 14
  completed_phases: 12
  total_plans: 37
  completed_plans: 35
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-29)

**Core value:** Zuverlässige, native iOS-Steuerung von Valetudo-Robotern ohne Cloud-Abhängigkeit
**Current focus:** Phase 14 — apply-phase-hardening

## Current Position

Phase: 14 (apply-phase-hardening) — EXECUTING
Plan: 2 of 2
Status: Ready to execute
Last activity: 2026-04-01

```
[Phase 12]──[Phase 13]──[Phase 14]──[Phase 15]
 State        State      Apply Phase  UI Wiring
 Machine      Consol.    Hardening
 Foundation
    ▲ next
```

Progress: 0/4 phases complete

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Codebase mapped: .planning/codebase/ (7 documents, 2026-03-28)
- Deep audit completed: 30 print() stmts in 8 files, 1 force-unwrap, keychain error handling, hardcoded URLs
- Previous releases: v1.0 (App Store), v1.1.0, v1.2.0, v1.3.0, v1.4.0
- Phase 9 groups all logging work + SAFE-03 (DispatchQueue → Task.sleep, same concurrency concern)
- Phase 10 handles remaining safety/organization quick-fixes
- Phase 11 is the largest structural change (3 big views decomposed)
- [Phase 09-logger-migration]: try? (nicht try) fuer Task.sleep in SupportReminderView: CancellationError wird ignoriert damit Animation nicht bricht
- [Phase 09-logger-migration]: Logger-Property in MapPreviewView platziert (nicht file-top-level), da dort der print()-Aufruf liegt
- [Phase 09-logger-migration]: Sub-Structs in derselben Datei erhalten eigene Logger-Property mit gleicher category wie Haupt-View
- [Phase 10-safety-fixes]: Constants als enum — verhindert Instanziierung, reine Namespace-Funktion, Swift-idiomatisch
- [Phase 10-safety-fixes]: xcodegen generate ausgefuehrt nach Constants.swift-Erstellung — Datei automatisch ins Xcode-Target eingetragen
- [Phase 11-view-decomposition]: PulseAnimation ist ViewModifier (nicht View-Struct) — korrekte Benennung aus tatsaechlichem Code uebernommen
- [Phase 11-view-decomposition]: sectionsLogger fuer RobotSettingsSections.swift als file-top-level Logger, konsistent mit settingsLogger-Pattern
- [Phase 11-view-decomposition]: WifiSettingsView Struct-Name beibehalten (camelCase, nicht WiFiSettingsView) — passt zur bestehenden Call-Site
- [Phase 11]: Control Bars als MapContentView extension statt eigenstaendige Structs -- vermeidet 10+ Parameter fuer State-Zugriff
- [v2.0.0 Roadmap]: Phasen aus Requirements abgeleitet — 4 strikte Dependency-Layers: Model → Service → Manager/ViewModel → UI
- [v2.0.0 Roadmap]: Phase 14 (Apply Hardening) bündelt 3 interdependente Pitfalls (Idle Timer + Reboot-Fenster + Background Task) — diese dürfen nicht aufgetrennt werden
- [v2.0.0 Research]: Reboot-Fenster-Erkennung benötigt Bestätigung des Post-Apply-Server-State-Sequence gegen Valetudo Updater.js vor Phase-14-Implementation
- [v2.0.0 Research]: UIBackgroundTask nominell ~30s — für Apply-HTTP-Call ausreichend (<5s), Expiry-Handler-Verhalten auf iOS 17+ vor Phase 14 prüfen
- [Phase 12-state-machine-foundation]: pollUntilReadyToApply() speichert Task in pollingTask-Property fuer externes Cancel via reset()
- [Phase 12-state-machine-foundation]: [Phase 12-01]: Unerwarteter idle-State im Polling-Loop wird als Fehler behandelt (Pitfall 6)
- [Phase 12-state-machine-foundation]: ValetudoInfoView erhält UpdateService als optionalen Init-Parameter (nicht EnvironmentObject) — explizites Ownership, STATE-04 erfüllt
- [Phase 13-state-consolidation]: UpdateService.loadVersionInfo() is public and not guarded by idle-state — version info is orthogonal to the update state machine
- [Phase 14-apply-phase-hardening]: setPhase() Wrapper statt didSet — @Published verhindert Property-Observer, expliziter Wrapper ist idiomatischer und erlaubt zentrale Side-Effects
- [Phase 14-apply-phase-hardening]: pollUntilReboot() ignoriert Netzwerkfehler bewusst — Roboter ist waehrend Reboot nicht erreichbar, das ist kein Fehler-Zustand

### Pending Todos

- Vor Phase 14 Implementation: post-apply Server-State-Sequence gegen Valetudo `Updater.js` validieren (welcher State kommt zuerst nach Reboot: `ValetudoUpdaterIdleState` oder `ValetudoUpdaterNoUpdateRequiredState`?)
- Vor Phase 14 Implementation: exakten `ValetudoUpdaterBusyState`-Klassennamen im bestehenden `UpdaterState`-Model prüfen

### Blockers/Concerns

None.
