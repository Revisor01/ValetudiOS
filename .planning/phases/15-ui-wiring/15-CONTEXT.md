# Phase 15: UI Wiring — Context

## Domain Boundary

Update-UI vervollständigen: Download-Fortschrittsanzeige, Error-Banner mit Retry, und Throttling des Update-Checks auf max. 1x/Stunde.

**Nicht in Scope:** State Machine (Phase 12), Property-Cleanup (Phase 13), Apply-Hardening (Phase 14) — alles erledigt.

## Decisions

### Download-Fortschrittsanzeige
**Decision:** Native SwiftUI `ProgressView` mit prozentualer Angabe in der Update-Sektion.

- Quelle: `updateService.downloadProgress` (0.0 bis 1.0) aus `UpdaterState.metaData.progress`
- Anzeige: `ProgressView(value: progress)` + Text "\(Int(progress * 100))%"
- Nur sichtbar wenn `updateService.phase == .downloading`
- Polling alle 2 Sekunden aktualisiert den Fortschrittswert (bereits implementiert in UpdateService)

**Why:** UI-01 — User muss den Download-Fortschritt sehen.

### Error-Banner
**Decision:** Inline-Section in RobotDetailView statt Alert oder Toast.

- Sichtbar wenn `updateService.phase == .error(let message)`
- Rotes Banner mit Fehlermeldung + "Erneut versuchen" Button
- Retry ruft `updateService.reset()` auf, dann kann User den Update-Prozess neu starten
- Kein automatischer Retry — User entscheidet

**Why:** UI-02 — Fehler müssen sichtbar sein. Inline-Banner ist besser als Alert weil der User den Kontext (Update-Sektion) sieht.

### Update-Check Throttling
**Decision:** `lastCheckDate` Property in UpdateService, `checkForUpdates()` gibt sofort zurück wenn weniger als 1 Stunde seit letztem Check.

- `private var lastCheckDate: Date?`
- Guard: `if let last = lastCheckDate, Date().timeIntervalSince(last) < 3600 { return }`
- Reset bei `reset()` (damit nach Error ein erneuter Check möglich ist)
- Kein UserDefaults nötig — In-Memory reicht (App-Neustart erlaubt neuen Check)

**Why:** UI-03 — mehrfaches Öffnen/Schließen der View soll nicht jedes Mal einen Check triggern.

## Canonical Refs

- `ValetudoApp/ValetudoApp/Services/UpdateService.swift` — Throttling + downloadProgress
- `ValetudoApp/ValetudoApp/Views/RobotDetailView.swift` — Progress + Error UI
- `ValetudoApp/ValetudoApp/Models/RobotState.swift:720-726` — UpdaterMetaData.progress

## Deferred Ideas

(keine)
