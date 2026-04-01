# Phase 13: State Consolidation — Context

## Domain Boundary

Doppelte Update-Properties und parallele Check-Pfade eliminieren. Nach dieser Phase gibt es genau eine Code-Stelle die Update-Logik besitzt — UpdateService aus Phase 12.

**Nicht in Scope:** UI-Verbesserungen (Phase 15), Fullscreen-Lock (Phase 14).

## Decisions

### Property-Entfernung
**Decision:** Alle redundanten Update-Properties aus RobotDetailViewModel entfernen.

Zu entfernen:
- `@Published var currentVersion: String?` → aus `updateService.currentVersion` lesen
- `@Published var latestVersion: String?` → aus `updateService.latestVersion` lesen  
- `@Published var updateUrl: String?` → aus `updateService.updateUrl` lesen
- `@Published var updaterState: UpdaterState?` → aus `updateService.phase` ableiten
- `@Published var isUpdating = false` → bereits computed property auf updateService
- `@Published var showUpdateWarning = false` → bleibt als UI-State in View (Alert-Binding)

**Why:** CLEAN-01 verlangt, dass `isUpdating` und `showUpdateWarning` nicht mehr im ViewModel existieren. Die View leitet Darstellungsentscheidungen aus `updateService.phase` ab.

### ValetudoInfoView Konsolidierung
**Decision:** `ValetudoInfoView.checkForUpdate()` (GitHub-API-Call) komplett entfernen.

- Die View nutzt jetzt `updateService.latestVersion` und `updateService.currentVersion`
- Kein eigener URLSession-Call mehr zu GitHub API
- `loadInfo()` ruft nur noch `api.getValetudoVersion()` und `api.getSystemHostInfo()` auf

**Why:** CLEAN-02 — keine doppelte Update-Check-Logik mehr.

### RobotDetailView Update-Sektion
**Decision:** Die Update-Sektion in RobotDetailView liest direkt aus `viewModel.updateService?.phase` statt aus den alten Properties.

- `updaterState` Referenzen → `updateService.phase` Pattern-Matching
- `currentVersion` → `updateService.currentVersion`
- `latestVersion` → `updateService.latestVersion`
- `updateUrl` → `updateService.updateUrl`
- `showUpdateWarning` bleibt als `@State` in der View (reines UI-State für Alert-Binding)

## Canonical Refs

- `ValetudoApp/ValetudoApp/Services/UpdateService.swift` — Phase-12-Output, Source of Truth
- `ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift:35-40` — zu entfernende Properties
- `ValetudoApp/ValetudoApp/Views/RobotDetailView.swift:7,34-115,226` — Update-UI die umgestellt werden muss
- `ValetudoApp/ValetudoApp/Views/RobotSettingsSections.swift:774+` — ValetudoInfoView

## Deferred Ideas

(keine)
