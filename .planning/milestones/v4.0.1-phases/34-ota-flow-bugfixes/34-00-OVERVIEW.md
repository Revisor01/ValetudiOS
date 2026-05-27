---
phase: 34
slug: ota-flow-bugfixes
status: completed
created: 2026-05-27
completed: 2026-05-27
milestone: v4.0.1
commit: b754e24
---

# Phase 34: OTA Update Flow Bugfixes

## Goal

Den Firmware-Update-Flow real benutzbar machen — Install-Button erscheint zuverlässig, GitHub-Link und Install-Button reagieren getrennt, Banner refresht sich nach erfolgreichem Reboot automatisch, Wegnavigieren während Update wird abgesichert.

## Context

Live-Test gegen `oben.eulogie.de` (2026.02.0 → 2026.05.0) und `unten.eulogie.de` deckte vier zusammenhängende Bugs auf:

1. **HTTP 400 beim `check`-Action**: Valetudo akzeptiert `PUT /api/v2/updater {"action":"check"}` nur wenn der Updater-State `Idle` oder `Error` ist. Die App schickte den Check immer — bei einem bereits erkannten Update (`ApprovalPendingState`) führte das zu `setPhase(.error)` und einem Error-Banner statt eines Install-Buttons.

2. **DeviceInfoView ohne Install-Button**: Die Geräteinfo-Unterseite (`RobotDetailSections.swift`) prüfte zwar `hasUpdate`, rendert aber nur einen `Link` zur GitHub-Release-Seite — kein OTA-Trigger. Der Banner sah aus wie ein Button, war aber funktional ein passiver Link.

3. **Tap-Target-Konflikt in List-Section**: Innerhalb einer SwiftUI-`List`-Section wurde der ganze Row-Bereich tap-aktiv. Der GitHub-`Link` schluckte Taps des Install-`Button`s → User klickte auf "Installieren" und landete auf GitHub.

4. **Kein Auto-Refresh nach Reboot**: `onRebootComplete` invalidierte nur Capabilities-Cache. `currentVersion`/`latestVersion` blieben veraltet → Banner "Update verfügbar" blieb stehen, obwohl die neue Firmware lief.

Zusätzlich entfernt: nutzlose `0%`-Progress-Bar während Download (Valetudo liefert kein Progress-Update für Downloads).

## Changes

### UpdateService.swift
- `checkForUpdates()`: Erst State holen — wenn nicht `Idle`, direkt setzen ohne `check`-PUT. Wenn `Idle`, `check` senden und State pollen bis er wechselt (max 10× mit 500ms initial + 1.5s Backoff).

### RobotDetailViewModel.swift
- `setupUpdateService()`: `onRebootComplete` ruft jetzt zusätzlich `updateService.reset()` + `loadVersionInfo()` + `checkForUpdates()` auf, damit Banner verschwindet sobald neue Firmware aktiv ist.

### RobotDetailSections.swift (DeviceInfoView)
- Banner unterscheidet jetzt zwischen `phase == .updateAvailable` (orangener Install-Button mit Confirm-Alert → `startDownload` → `startApply`) und Fallback (GitHub-Link).
- `loadInfo()` triggert auch `updateService.checkForUpdates()`.
- Lokale `startUpdate()` für den Confirm-Alert-Handler.

### UpdateStatusBannerView.swift
- Install-Button und GitHub-Link bekommen `.buttonStyle(.borderless)` + `.contentShape(Rectangle())` damit Taps separat verarbeitet werden.
- Download-Banner zeigt nur noch Spinner + Hinweis statt 0%-Progress-Bar.

### RobotDetailView.swift
- Während `.downloading`, `.applying`, `.rebooting`: `navigationBarBackButtonHidden(true)` + `interactiveDismissDisabled(true)`.
- Eigener Toolbar-Back-Button öffnet Confirm-Alert ("Trotzdem verlassen") → `dismiss()`.

### Localizable.xcstrings
- Neue Keys (DE/EN/FR): `update.leave_warning_title`, `update.leave_warning_message`, `update.leave_confirm`, `common.back`.

## Verification

- Live-Test gegen zwei Roboter (`oben.eulogie.de` und `unten.eulogie.de`): Update 2026.02.0 → 2026.05.0 erfolgreich, beide Roboter danach automatisch im neuen `ValetudoUpdaterIdleState`.
- `xcodebuild -scheme ValetudoApp build` → `** BUILD SUCCEEDED **`
- Banner verschwindet nach Reboot ohne manuelles Refreshen.
- Tap-Tests: Install-Button öffnet Confirm-Alert, Link-Icon öffnet GitHub-Release.

## Files Changed

- `ValetudoApp/ValetudoApp/Services/UpdateService.swift`
- `ValetudoApp/ValetudoApp/ViewModels/RobotDetailViewModel.swift`
- `ValetudoApp/ValetudoApp/Views/Detail/UpdateStatusBannerView.swift`
- `ValetudoApp/ValetudoApp/Views/RobotDetailSections.swift`
- `ValetudoApp/ValetudoApp/Views/RobotDetailView.swift`
- `ValetudoApp/ValetudoApp/Resources/Localizable.xcstrings`

## Open Items (out of scope)

- Manuelle Steuerung hat weiterhin offene UX-Issues — separater Folge-Fix geplant.
- App-Kill während `.applying` (iOS Background-Limit ~30s, Reboot dauert 60-120s) verliert weiterhin den Status; akzeptiert.
