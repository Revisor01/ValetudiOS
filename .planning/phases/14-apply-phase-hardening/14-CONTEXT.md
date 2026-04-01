# Phase 14: Apply Phase Hardening — Context

## Domain Boundary

Den kritischen Moment zwischen "Apply gedrückt" und "Roboter wieder online" absichern. Fullscreen-Lock, Idle Timer Deaktivierung, Reboot-Erkennung, Background Task Schutz.

**Nicht in Scope:** Download-Fortschrittsanzeige (Phase 15), Error-Banner (Phase 15).

## Decisions

### Fullscreen-Lock Overlay
**Decision:** Fullscreen `.overlay()` auf NavigationStack-Ebene in RobotDetailView, getriggert durch `updateService.phase == .applying || .rebooting`.

- Zeigt Spinner + "Update wird angewendet..." Text
- Kann NICHT weggeklickt werden (kein Dismiss-Button, kein Tap-to-close)
- Blockiert Navigation (Back-Button, Tab-Wechsel) via `.interactiveDismissDisabled(true)` und `.navigationBarBackButtonHidden(true)`
- Verschwindet automatisch wenn `updateService.phase` auf `.idle` oder `.error` wechselt

**Why:** APPLY-01 — User darf während Apply die View nicht verlassen oder den Prozess abbrechen.

### Idle Timer Deaktivierung
**Decision:** `UIApplication.shared.isIdleTimerDisabled = true` wenn `phase == .downloading || .applying || .rebooting`.

- Wird in `UpdateService` gesetzt (nicht in der View)
- Zurückgesetzt auf `false` bei `.idle`, `.error`, `.updateAvailable`
- Kein eigener Toggle nötig — direkt an Phase-Transitions gebunden

**Why:** APPLY-02 — Bildschirm muss während des gesamten Update-Prozesses an bleiben.

### Reboot-Erkennung
**Decision:** Nach `applyUpdate()` wechselt UpdateService auf `.rebooting` und pollt `/api/v2/robot` alle 5 Sekunden.

- Timeout: 120 Sekunden (2 Minuten)
- Während Rebooting: Netzwerkfehler/Timeouts werden NICHT als Error gewertet — das ist erwartetes Verhalten
- Erfolg: Roboter antwortet wieder → `.idle`
- Timeout überschritten: → `.error("Roboter nicht erreichbar nach Update")`

**Why:** APPLY-03 — Neustart darf nicht als Fehler angezeigt werden.

### Background Task
**Decision:** `UIApplication.shared.beginBackgroundTask` um den Apply-Call und das Reboot-Polling zu schützen.

- Wird in UpdateService `startApply()` gestartet
- `endBackgroundTask` nach Rebooting-Polling fertig (egal ob Erfolg oder Timeout)
- Kein BGAppRefreshTask nötig (das wäre für periodische Background-Arbeit — hier geht es um einen laufenden Task)

**Why:** APPLY-04 — iOS darf den API-Call nicht abbrechen wenn User die App kurz in den Hintergrund schiebt.

## Canonical Refs

- `ValetudoApp/ValetudoApp/Services/UpdateService.swift` — alle Änderungen hier
- `ValetudoApp/ValetudoApp/Views/RobotDetailView.swift` — Fullscreen-Lock Overlay

## Deferred Ideas

(keine)
