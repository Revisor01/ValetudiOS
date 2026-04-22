---
status: investigating
trigger: "Manuelle Steuerung (Joystick/Richtungssteuerung) ist unfunktional — Modus wird aktiviert, aber Roboter fährt in keine Richtung."
created: 2026-04-12T00:00:00Z
updated: 2026-04-12T03:00:00Z
---

## Current Focus

hypothesis: RUNDE 3 — Drei Kandidaten: (A) privacy: .private im Log verhindert dass wir sehen was gesendet wird. (B) isEnabled Race Condition: User tippt während enable noch läuft. (C) S5 Max nutzt tatsächlich HighRes-Pfad, aber HighRes-Pfad hat eigenen Bug — kein Heartbeat-Interval sendet velocity:0 wenn Finger stillhält, und highResManualControl() sendet bei velocity=0/angle=0 nichts. (D) Response-Body bei Fehlern wird nie geloggt — wir wissen nicht ob 400/500 zurückkommt.
test: Code-Analyse ManualControlView.swift + ValetudoAPI.swift vollständig gelesen. Logging-Lücken und isEnabled-Guard entdeckt.
expecting: Fix: (1) Logging auf .public + Response-Body loggen. (2) isEnabled Guard aus sendMovement() in heartbeat-Schleife isoliert prüfen. (3) Capability klar loggen. (4) Auch den HighRes-Pfad mit Heartbeat-Semantik prüfen (nicht angenommen korrekt).
next_action: Fixes implementieren: Logging verbessern + isEnabled-Race-Condition-Absicherung + capability-Log

## Symptoms

expected: Beim Starten der manuellen Steuerung wechselt der Roboter in den Manual-Control-Modus und fährt in die Richtung, die der User über die UI vorgibt.
actual: Manual-Control-Modus wird aktiviert (Roboter reagiert), aber bei Richtungseingaben fährt der Roboter nicht.
errors: Keine Crashes/Error-Meldungen. Stille Fehlfunktion.
reproduction: 1) App öffnen → Roboter auswählen. 2) Manuelle Steuerung öffnen. 3) Richtung eingeben. Roboter bleibt stehen.
started: Feature frisch implementiert, hat vermutlich noch nie funktioniert.

## Eliminated

- hypothesis: HighRes-Pfad ist betroffen
  evidence: HighRes-Pfad war korrekt implementiert (enable/disable/move mit vector). Bug lag nur im Standard-ManualControl-Pfad.
  timestamp: 2026-04-12

## Evidence

- timestamp: 2026-04-12
  checked: ManualControlView.swift enableManualControl()
  found: Für Standard-ManualControlCapability (useHighRes == false) wurde kein Enable-Befehl gesendet — isEnabled wurde auf true gesetzt ohne API-Call
  implication: Valetudo wusste nicht dass Manual-Control aktiv sein soll; Move-Commands kamen ohne vorheriges Enable an

- timestamp: 2026-04-12
  checked: ManualControlView.swift sendMovement() + ManualControlRequest struct
  found: sendMovement() rief api.manualControl(action: "forward") auf. Die Valetudo-API erwartet aber {"action": "move", "movementCommand": "forward"} — action muss immer "move" sein, die Richtung geht in das separate movementCommand-Feld. ManualControlRequest hatte kein movementCommand-Feld.
  implication: Jeder Move-Befehl sendete ein semantisch falsches Payload, das Valetudo ignorierte oder ablehnte.

- timestamp: 2026-04-12
  checked: Build nach Fix (Runde 1 — Payload-Format)
  found: BUILD SUCCEEDED, keine neuen Errors
  implication: Änderungen kompilieren fehlerfrei

- timestamp: 2026-04-12
  checked: ManualControlView.swift DragGesture.onChanged — gibt es einen repeating Timer/Task während isTouching==true?
  found: NEIN. onChanged feuert nur bei Fingerbewegung. Bei stehendem Finger (aber noch Kontakt) kommen keine weiteren Move-Commands. Kein Timer vorhanden.
  implication: Valetudo Heartbeat-Watchdog (~1-2s) löst aus sobald Finger stillhält. Roboter stoppt, Valetudo deaktiviert intern ManualControl. App weiß davon nichts (isEnabled bleibt true). Alle Folge-Befehle werden von Valetudo ignoriert.

- timestamp: 2026-04-12
  checked: Build nach Heartbeat-Fix
  found: BUILD SUCCEEDED
  implication: Heartbeat-Task-Implementierung kompiliert fehlerfrei

- timestamp: 2026-04-12T02:00Z
  checked: Valetudo GitHub — ManualControlCapability.js (Basisklasse), RoborockManualControlCapability.js, ManualControl.tsx (Frontend-Referenz), ManualControlCapabilityRouter.js, OpenAPI Docs
  found: |
    1. Gültige movementCommands: FORWARD, BACKWARD, ROTATE_CLOCKWISE, ROTATE_COUNTERCLOCKWISE — "stop" existiert NICHT.
    2. RoborockManualControlCapability.manualControl() hat default-case: throw new Error("Invalid movementCommand.") → resultiert in 500 vom Server.
    3. ManualControlCapabilityRouter gibt 400 wenn action=="move" ohne movementCommand.
    4. Das Referenz-Frontend (ManualControl.tsx) verwendet BUTTONS für Standard-ManualControl — onClick sendet EINMAL einen Befehl. Kein Interval, kein Stop-Befehl.
    5. HighRes-Frontend verwendet setInterval(250ms) und stoppt mit {velocity:0, angle:0} — das ist korrekt für HighRes.
    6. Standard-ManualControl ist DISKRETER Mechanismus: ein Befehl = eine kurze Bewegung. Zum kontinuierlichen Fahren muss man Befehle wiederholen (Heartbeat ist also richtig), aber es gibt keinen "stop"-Befehl.
  implication: |
    - stopMovement() mit movementCommand:"stop" → 500er Fehler von Valetudo (oder gar kein Effekt je nach HTTP-Error-Handling).
    - Der 500-Fehler wird in ManualControlView gecatcht, isEnabled bleibt true, aber der Modus könnte durch den fehlgeschlagenen Request in einen inkonsistenten Zustand gebracht werden.
    - Fix: stopMovement() im Standard-Pfad darf KEINEN move-Request mit "stop" senden. Beim onEnded einfach den Heartbeat stoppen — der Roboter bleibt von selbst stehen (diskretes System). Optional: disableManualControl() aufrufen.

- timestamp: 2026-04-12T02:00Z
  checked: Heartbeat-Semantik für Standard vs. User-Pushback
  found: User stellte richtig in Frage ob Heartbeat nötig ist (DragGesture feuert ohnehin bei Mikrobewegungen). Aber: Valetudo Standard ManualControl erwartet diskrete Befehle pro gewünschte Bewegungseinheit. Wenn der Benutzer den Finger hält und nicht bewegt, soll der Roboter weiterfahren — dazu MÜSSEN Befehle wiederholt werden. Der Heartbeat ist also sachlich richtig, aber die Frequenz (500ms) und der fehlerhafte Stop-Command waren das eigentliche Problem.
  implication: Heartbeat BEHALTEN. stopMovement() "stop"-Command ENTFERNEN.

## Eliminated

- hypothesis: Heartbeat-Fix (Runde 2) war vollständig korrekt
  evidence: stopMovement() im Standard-Pfad sendet movementCommand:"stop" — das ist kein gültiger Valetudo-Befehl. RoborockManualControlCapability wirft "Invalid movementCommand" → 500. Heartbeat-Logik selbst ist korrekt, Stop-Command ist falsch.
  timestamp: 2026-04-12T02:00Z

## Resolution

root_cause: |
  Noch nicht abschliessend bestätigt. Drei behobene Bugs aus Runden 1+2, plus neue Diagnose-Massnahmen in Runde 3:
  1. enableManualControl() sendete keinen API-Befehl (behoben Runde 1)
  2. Move-Commands hatten falsches Payload-Format (behoben Runde 1)
  3. stopMovement() sendete ungültigen "stop"-movementCommand → HTTP 500 (behoben Runde 2)
  4. (Runde 3) Logging war mit privacy:.private → Request-Body im Xcode Console unsichtbar
  5. (Runde 3) Response-Body bei HTTP-Fehlern wurde nie geloggt
  6. (Runde 3) Capability-Auswahl (useHighRes) wurde nie geloggt — unklar ob S5 Max HighRes oder Standard-Pfad nimmt
  7. (Runde 3) isEnabled-Guard in sendMovement() loggt jetzt wenn Befehle verworfen werden (Race Condition sichtbar machen)

fix: |
  Runde 3: Diagnostisches Logging hinzugefügt um Root Cause zu lokalisieren:
  - ValetudoAPI.swift requestVoid(): privacy:.private → privacy:.public, logger.debug → logger.info, Response-Status + Body loggen
  - ManualControlView.swift checkCapabilities(): useHighRes-Wert + gefundene Capabilities loggen
  - ManualControlView.swift enableManualControl(): Start + Erfolg loggen
  - ManualControlView.swift sendMovement(): Jeden gesendeten Command loggen, Guard-Bedingungen loggen

verification: BUILD SUCCEEDED (Runde 3, xcodebuild -quiet). Menschliche Verifikation mit Xcode Console-Auswertung aussteht.

files_changed:
  - ValetudoApp/ValetudoApp/Models/RobotState.swift
  - ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift
  - ValetudoApp/ValetudoApp/Views/ManualControlView.swift
