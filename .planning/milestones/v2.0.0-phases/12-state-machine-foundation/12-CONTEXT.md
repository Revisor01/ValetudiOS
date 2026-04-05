# Phase 12: State Machine Foundation — Context

## Domain Boundary

Der Update-Prozess bekommt eine einzige autoritative State Machine. Update-Zustände werden als Enum modelliert, Doppelaufrufe type-safe verhindert, Fehler explizit abgebildet. Ein zentraler `UpdateService` wird zur Single Source of Truth.

**Nicht in Scope:** UI-Änderungen (Phase 15), Fullscreen-Lock/Idle Timer (Phase 14), Entfernung doppelter Properties (Phase 13).

## Decisions

### UpdatePhase Enum Design
**Decision:** App-eigene States mit Mapping von Valetudo-API-States.

Das Enum bildet den gesamten Update-Lifecycle ab, nicht nur die Valetudo-API-States:
- `idle` — kein Update aktiv
- `checking` — prüft auf Updates (API: checkForUpdates)
- `updateAvailable` — Update verfügbar, wartet auf User-Aktion (Valetudo: `ValetudoUpdaterApprovalPendingState`)
- `downloading` — Download läuft (Valetudo: `ValetudoUpdaterDownloadingState`)
- `readyToApply` — Download fertig, Apply möglich (Valetudo: `ValetudoUpdaterApplyPendingState`)
- `applying` — Update wird angewendet (App-eigener State — Valetudo hat keinen expliziten Apply-State)
- `rebooting` — Roboter startet neu (App-eigener State — Valetudo ist dann offline)
- `error(String)` — Fehler mit lesbarer Nachricht

**Why:** `Rebooting` und `Error` existieren nicht in der Valetudo API, werden aber für die App-UX gebraucht. Mapping-Funktion konvertiert `UpdaterState.__class` → `UpdatePhase`.

### UpdateService Architektur
**Decision:** `@MainActor class UpdateService: ObservableObject` mit `@Published var phase: UpdatePhase`.

- Konsistent mit allen bestehenden Services/ViewModels (`RobotManager`, `RobotDetailViewModel` etc.)
- `@Published` properties binden direkt an SwiftUI-Views
- Service wird pro Roboter instanziiert oder nimmt Robot-ID als Parameter
- Hält Referenz auf `ValetudoAPI` für die 4 Update-Endpunkte

**Why:** Kein Actor nötig — alle UI-Updates müssen sowieso auf @MainActor. ObservableObject passt zum bestehenden Pattern.

### Error-State Granularität
**Decision:** `case error(String)` — ein einziger Error-Case mit assoziierter Fehlermeldung.

- Kein enum-pro-Fehlerart in Phase 12 (DownloadError, ApplyError etc.)
- Die String-Message kommt aus dem API-Error oder wird für Timeouts/Netzwerkfehler generiert
- Kann in Phase 15 bei Bedarf zu strukturierteren Fehlertypen erweitert werden

**Why:** YAGNI — Phase 12 braucht nur "es gab einen Fehler mit dieser Nachricht". Differenzierung nach Fehlertyp ist erst für Phase 15 (Error-Banner mit Retry) relevant.

### Re-Entrancy-Guard
**Decision:** State-Machine-basiert — Transitionen nur aus erlaubten States.

- Keine separate Bool-Property `isUpdating` oder `guard !busy`
- Stattdessen: `startDownload()` prüft `guard case .updateAvailable = phase` → sonst return
- `startApply()` prüft `guard case .readyToApply = phase` → sonst return
- Ungültige Aufrufe werden geloggt und ignoriert

**Why:** Die State Machine verhindert ungültige Übergänge by design. Kein separater Guard-Mechanismus nötig — das Enum IST der Guard.

## Specifics

### Existing Code to Refactor (Phase 12 scope)
- `RobotDetailViewModel.startUpdate()` (Zeile 450-490) — Logik in UpdateService extrahieren
- `RobotDetailViewModel.checkForUpdate()` (Zeile 265-283) — an UpdateService delegieren
- `RobotDetailViewModel` Properties: `currentVersion`, `latestVersion`, `updateUrl`, `updaterState`, `showUpdateWarning`, `updateInProgress` — in Phase 12 als Proxy auf UpdateService umleiten, in Phase 13 entfernen

### Valetudo API States (Referenz)
- `ValetudoUpdaterIdleState` → `.idle`
- `ValetudoUpdaterApprovalPendingState` → `.updateAvailable`
- `ValetudoUpdaterDownloadingState` → `.downloading`
- `ValetudoUpdaterApplyPendingState` → `.readyToApply`
- Unbekannter State → `.idle` (defensive fallback)

### API Endpunkte (bereits implementiert in ValetudoAPI.swift)
- `GET /updater/state` → `getUpdaterState()`
- `PUT /updater` mit `action: check` → `checkForUpdates()`
- `PUT /updater` mit `action: download` → `downloadUpdate()`
- `PUT /updater` mit `action: apply` → `applyUpdate()`

## Canonical Refs

- `ValetudoApp/ValetudoApp/Models/RobotState.swift:709-748` — bestehende UpdaterState/UpdaterMetaData Structs
- `ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift:34-41` — aktuelle Update-Properties
- `ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift:265-283` — checkForUpdate()
- `ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift:448-490` — startUpdate()
- `ValetudoApp/ValetudoApp/Views/RobotSettingsSections.swift:774-973` — ValetudoInfoView mit eigener Update-Logik
- `ValetudoApp/ValetudoApp/Services/RobotManager.swift:189-197` — checkUpdateForRobot()
- `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift:590-614` — Update API-Methoden

## Deferred Ideas

(keine)
