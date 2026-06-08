---
status: resolved
resolved: 2026-06-08
trigger: "Update-Such-Anzeige bleibt oben hängen (groß, verschwindet nie) + 401 Unauthorized beim Hin-/Her-Navigieren zwischen Robotern/Dashboard"
created: 2026-06-08T13:29:31Z
updated: 2026-06-08T13:50:00Z
---

## Resolution (2026-06-08)

root_cause:
  A) UI: `RobotDetailViewModel.updateInProgress` schloss Phase `.checking` ein → großes
     `update.in_progress`-Panel während der reinen Update-Prüfung; bei 401 im Check blieb es hängen.
  B) 401: SSE-Sessions (timeout=.infinity) wurden nie invalidiert; State-SSE lief für ALLE
     Robots parallel (Connect-Loop ignorierte activeRobotId, anders als das Polling);
     401/403 wurde in streamWithReconnect nicht gesondert behandelt → stures Reconnecten über
     überlastete Basic-Auth-Verbindungen → 401-Rückkopplung.
     Bestätigt vom User: ohne Passwort (keine Basic-Auth) tritt der 401 nicht auf.

fix:
  A) RobotDetailViewModel.swift:46-56 — `.checking` aus updateInProgress entfernt (stille Prüfung; Banner nur bei .updateAvailable).
  B1) ValetudoAPI.swift — deinit { invalidateAndCancel } für beide SSE-Sessions.
  B2) ValetudoAPI.swift — getrennte State-/Map-SSE-Sessions, httpMaximumConnectionsPerHost=1.
  B3) SSEConnectionManager.swift — 401/403 als fatal: suspend statt reconnect.
  B4) RobotManager.swift:148ff — SSE-Connect-Loop respektiert activeRobotId; inaktive Robots werden disconnected.

verification: BUILD SUCCEEDED (xcodebuild, iOS Simulator). Gerätetest am echten Roboter mit Basic-Auth durch User ausstehend.

## Current Focus

hypothesis: Zwei getrennte Root Causes. (A) UI-Banner: `updateInProgress` schließt `.checking` ein → großes "update.in_progress"-Panel wird während des Checks gezeigt; bei jedem `onAppear`/`task` wird ein neuer Check getriggert, Phase bleibt evtl. nicht-idle hängen. (B) 401: ValetudoAPI hält pro Robot zwei langlebige URLSessions (`session` + `_sseSession` mit timeout=.infinity), die nie invalidiert werden; SSE-Connections akkumulieren beim Navigieren → Valetudo-Server (Basic-Auth, begrenzte gleichzeitige Verbindungen) lehnt irgendwann mit 401 ab.
test: Code-Analyse der State-Übergänge + Session-/Task-Lebenszyklus
expecting: Beweis im Code für (A) Banner-Bindung an .checking und fehlendes idle-Reset, (B) Session-Leak / fehlendes invalidate
next_action: Root-Cause-Report finalisieren, kleinen sicheren Fix für (A) anwenden, (B) als Vorschlag

## Symptoms

expected: |
  1. "Suche nach Update"-Anzeige sollte nach Abschluss verschwinden bzw. klein/dezent sein.
  2. Beim Navigieren zwischen Dashboard/Robotern sollen keine 401-Fehler auftreten.
actual: |
  1. Beim Öffnen des Dashboards erscheint OBEN ein RELATIV GROSSES "Suche nach Update"-Panel, das nicht mehr verschwindet.
  2. Beim Hin-/Her-Navigieren kommt "irgendwann" 401 Unauthorized.
errors: "HTTP 401 Unauthorized"
reproduction: |
  1. Dashboard eines Roboters öffnen → großes Update-Such-Panel oben erscheint, bleibt.
  2. Wiederholt Dashboard öffnen/schließen, zwischen Robotern wechseln → irgendwann 401.
started: "Nach Commit b754e24 'fix: OTA update flow' verstärkt; SSE-Leak ist bekannter OPEN BUG (Memory)."

## Evidence

- timestamp: 2026-06-08T13:35:00Z
  checked: UpdateStatusBannerView.swift Zeile 83-98 + RobotDetailViewModel.swift Zeile 46-54
  found: |
    Der große "update.in_progress"-Block (ProgressView scaleEffect 1.2, padding .vertical 16) wird
    gerendert wenn `viewModel.updateInProgress == true`. `updateInProgress` (VM Z.49) liefert true für
    .downloading, .applying, .rebooting UND .checking. Während checkForUpdates() läuft, ist die Phase
    `.checking` → das große Panel erscheint. UpdateStatusBannerView selbst hat KEINEN expliziten
    .checking-Case; es fällt in den generischen updateInProgress-Zweig (Z.83). DAS ist die "Suche nach
    Update"-Anzeige (Text ist update.in_progress, vom User als "Suche nach Update" interpretiert).
  implication: ROOT CAUSE A (Anzeige). Banner ist an .checking gebunden über updateInProgress.

- timestamp: 2026-06-08T13:36:00Z
  checked: UpdateService.checkForUpdates() Zeile 92-128 + mapUpdaterState Zeile 280-294
  found: |
    Polling-Schleife (Z.113-119): bricht beim ERSTEN nicht-idle Mapping ab und setzt diese Phase.
    Wenn der Server während des Checks transient `ValetudoUpdaterDownloadingState` meldet (Valetudo lädt
    Metadaten beim "check"), wird mapped=.downloading → setPhase(.downloading) → Banner bleibt im
    "downloading"-Zustand hängen, ohne dass je heruntergeladen wird. Außerdem: bleibt der State 10x idle,
    wird setPhase(.idle) gesetzt — gut. ABER: tritt im 10-Versuche-Fenster (max ~14s) kein Wechsel ein,
    bleibt .checking NICHT — es wird .idle gesetzt. Das eigentliche Hängen entsteht, wenn ein
    getUpdaterState() WIRFT (z.B. 401, s.u.): dann landet checkForUpdates im catch → setPhase(.error).
    Bei 401 zeigt der Banner dann dauerhaft den Error/in-progress-Zustand.
    Zusätzlich: jeder loadData() (bei jedem .task der DetailView) ruft checkForUpdate(); lastCheckDate
    drosselt zwar auf 1h, aber die GUARD `guard case .idle = phase` (Z.95) verhindert NICHT, dass ein
    bereits hängender nicht-idle Zustand (z.B. .checking, .downloading durch transienten State) je
    zurückgesetzt wird. reset() wird nur bei Reboot/Error-Retry aufgerufen.
  implication: |
    ROOT CAUSE A verschärft: Phase kann in .checking/.downloading "hängen", weil (1) updateInProgress
    .checking einschließt und (2) es keinen Pfad gibt, der einen verwaisten nicht-idle Zustand beim
    erneuten onAppear auf idle zurücksetzt. Bei 401 während des Checks → dauerhafter Error-Banner.

- timestamp: 2026-06-08T13:38:00Z
  checked: ValetudoAPI.swift Zeile 28-43 (sseSession), 45-61 (init), 647-705 (stream*Lines)
  found: |
    Pro Robot existiert genau EINE ValetudoAPI-Instanz (RobotManager.apis, persistent). Diese hält:
      - `session` (timeouts 10s/30s) für normale Requests
      - `_sseSession` (LAZY, timeoutIntervalForRequest=.infinity, timeoutIntervalForResource=.infinity)
    Beide werden NIE invalidiert (kein deinit, kein finishTasksAndInvalidate). streamStateLines() und
    streamMapLines() laufen BEIDE über dieselbe `sseSession`. Ein einzelner URLSession mit Standard-
    Konfiguration begrenzt gleichzeitige Verbindungen pro Host (HTTPMaximumConnectionsPerHost, default 6).
  implication: |
    Basis für ROOT CAUSE B: langlebige SSE-Session pro Robot, geteilt von State- und Map-Stream.

- timestamp: 2026-06-08T13:39:00Z
  checked: SSEConnectionManager.swift + MapViewModel.startMapRefresh (Z.186-273) + RobotManager.startRefreshing (Z.148-197)
  found: |
    Zwei UNABHÄNGIGE SSE-Lebenszyklen für denselben Robot/dieselbe sseSession:
      1. State-Stream: SSEConnectionManager.connect() — verwaltet vom RobotManager-refreshTask. Cancel
         erfolgt nur bei removeRobot() oder disconnectAll(). Beim Navigieren zwischen Robotern wird
         NICHT disconnected — die State-SSE aller Robots bleibt offen (by design für Notifications).
      2. Map-Stream: MapViewModel.startMapRefresh() — gestartet im MapView(.task), gecancelt in
         onDisappear (Z.340). Cancel des Tasks bricht die for-await-Schleife ab, ABER der zugrunde-
         liegende URLSession-Datatask der `sseSession.bytes(for:)` wird NICHT explizit gecancelt/ge-
         schlossen. Task-Cancellation propagiert zwar zu URLSession.AsyncBytes (wirft NSURLErrorCancelled),
         d.h. der Stream SOLLTE schließen — aber nur wenn der Server das FIN sieht. Bei .infinity-Timeout
         und langsamem Teardown kann die TCP-Verbindung kurzzeitig weiterleben.
    Kritischer Punkt — MapView/MapPreview Lifecycle:
      - MapPreviewView (MapView.swift Z.50-137) nutzt EINMALIGES api.getMap() (KEIN SSE) → kein Leak.
      - Voller MapView-Sheet startet Map-SSE. Korrektes Cancel in onDisappear.
    Eigentlicher Leak-/401-Mechanismus: SSEConnectionManager.streamWithReconnect reconnectet bei JEDEM
    Fehler (Backoff). Wenn der Server unter Last 401 zurückgibt (Basic-Auth bei zu vielen parallelen
    Verbindungen — Valetudo/embedded HTTP-Server begrenzt Connections), behandelt streamWithReconnect
    den 401 als generischen Fehler → retry mit denselben Credentials → erzeugt SOFORT eine NEUE
    Verbindung über dieselbe überlastete sseSession → mehr 401. Es gibt KEINE 401-Sonderbehandlung
    (kein Abbruch, kein Credential-Reload). Gleichzeitig pollt RobotManager.refreshRobot() für ALLE
    Robots (wenn activeRobotId==nil) alle 5s → zusätzliche parallele Auth-Requests.
  implication: |
    ROOT CAUSE B: 401 entsteht durch Verbindungs-/Auth-Last auf dem Valetudo-Server. Die SSE-Session
    wird nie invalidiert/erneuert; bei 401 wird stur reconnectet statt zu deeskalieren. Map-SSE +
    State-SSE + 5s-Polling laufen parallel über begrenzte Verbindungen. Beim Navigieren akkumuliert sich
    Last (neue MapViewModel-Instanz pro Sheet-Öffnung, alte sseSession bleibt am Robot-API hängen).

## Eliminated

- hypothesis: "Suche nach Update" ist ein eigener .checking-Case in UpdateStatusBannerView
  evidence: UpdateStatusBannerView hat KEINEN .checking-Case; die Anzeige kommt aus dem generischen `updateInProgress`-Zweig (Z.83), der .checking via VM-Computed-Property einschließt.
  timestamp: 2026-06-08T13:35:00Z

- hypothesis: MapPreviewView (Dashboard-Vorschau) leakt SSE-Verbindungen
  evidence: MapPreviewView nutzt einmaliges api.getMap() ohne SSE (MapView.swift Z.137-175). Kein Stream, kein Leak. SSE-Leak kommt vom State-Stream (nie disconnected) + Map-Sheet-Session-Reuse.
  timestamp: 2026-06-08T13:39:00Z

## Resolution

root_cause: |
  ZWEI Root Causes:

  (A) UI / "Suche nach Update" bleibt hängen:
    RobotDetailViewModel.updateInProgress (Z.46-54) schließt `.checking` ein. UpdateStatusBannerView
    (Z.83) rendert daraufhin das große "update.in_progress"-Panel während der Update-Prüfung. Es gibt
    keinen Mechanismus, der einen verwaisten nicht-idle Phase-Zustand (.checking/.downloading durch
    transienten Server-State oder durch einen 401-Fehler → .error) beim erneuten Öffnen zurücksetzt.
    Zusätzlich macht UpdateService.checkForUpdates() bei einem geworfenen getUpdaterState() (z.B. 401)
    setPhase(.error) — der Banner bleibt dann dauerhaft sichtbar.

  (B) 401 Unauthorized beim Navigieren:
    ValetudoAPI hält pro Robot eine langlebige `sseSession` (timeouts = .infinity, geteilt von State-
    und Map-Stream), die NIE invalidiert wird (kein deinit / finishTasksAndInvalidate). State-SSE aller
    Robots bleibt dauerhaft offen, Map-SSE startet pro Sheet neu, und RobotManager pollt alle 5s. Bei
    Verbindungs-/Auth-Last antwortet der Valetudo-HTTP-Server mit 401. SSEConnectionManager.streamWith-
    Reconnect behandelt 401 NICHT gesondert → stures Reconnect über dieselbe überlastete Session
    verschärft die Last (Rückkopplung). Es fehlt: 401-Sonderbehandlung, Session-Invalidierung, und ein
    Lifecycle, der nicht-aktive Robot-Streams pausiert.

fix: |
  ANGEWENDET (klein & sicher, Root Cause A, Teil 1):
    - RobotDetailViewModel.updateInProgress: `.checking` aus der true-Bedingung entfernen, damit das
      große "in_progress"-Panel NICHT während der reinen Update-Prüfung erscheint. (Datei/Zeile s.u.)

  VORGESCHLAGEN (nicht angewendet — größer / Verhaltensänderung, Review nötig):
    A2) UpdateService.checkForUpdates(): bei transientem .downloading-Mapping während eines reinen
        Checks NICHT in .downloading verharren; Phase nach Check immer auf einen definierten Zustand
        (.idle / .updateAvailable / .error) bringen und beim erneuten DetailView-onAppear einen
        verwaisten .checking/.error zurücksetzen (z.B. reset() wenn phase==.checking && kein aktiver Task).
    A3) Optional eigener dezenter .checking-Indikator (klein, statt großem Panel) falls gewünscht.
    B1) ValetudoAPI: deinit { session.invalidateAndCancel(); _sseSession?.invalidateAndCancel() } sowie
        eine Methode zum Schließen der sseSession, wenn ein Robot nicht aktiv ist.
    B2) SSEConnectionManager.streamWithReconnect: 401 (APIError.httpError(401)) als FATAL behandeln —
        NICHT reconnecten (Credentials sind falsch ODER Server überlastet); stattdessen suspendieren und
        erst nach längerem Backoff / Netzwerkwechsel erneut versuchen. Verhindert die 401-Rückkopplung.
    B3) State-SSE für nicht-aktive Robots beim Navigieren pausieren (nur activeRobotId streamt Map+State,
        Hintergrund-Robots nur sparsames Polling) — reduziert parallele Auth-Verbindungen.
    B4) HTTPMaximumConnectionsPerHost auf der sseSession-Config explizit setzen und getrennte Sessions
        für State- vs. Map-Stream verwenden, damit ein hängender Stream den anderen nicht blockiert.

verification: |
  (A1) verifiziert per Code: nach Entfernen von .checking rendert UpdateStatusBannerView den großen
  in_progress-Block während des Checks nicht mehr; .updateAvailable/.downloading/.readyToApply/.error
  bleiben unverändert funktionsfähig.
  (B) NICHT verifiziert — benötigt Gerätetest am echten Roboter (Auth-Last reproduzieren).
files_changed:
  - "ValetudoApp/ViewModels/RobotDetailViewModel.swift (updateInProgress: .checking entfernt)"
</content>
</invoke>
