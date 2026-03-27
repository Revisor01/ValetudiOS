---
phase: 02-network-layer
plan: "02"
subsystem: network
tags: [nwbrowser, mdns, bonjour, network-framework, swift-concurrency]

requires:
  - phase: 01-foundation
    provides: os.Logger, ErrorRouter patterns used in NWBrowserService

provides:
  - NWBrowserService: NWBrowser wrapper for _valetudo._tcp Bonjour discovery with TXT-Record parsing
  - NetworkScanner mDNS-parallel strategy: mDNS immediate + IP scan 3s fallback with deduplication
  - AddRobotView: mDNS results with Bonjour badge, model subtitle, sorted before IP-scan results

affects:
  - future test phases (NWBrowserService has clear @MainActor isolation)
  - 02-03 (map caching plan — no overlap but same phase)

tech-stack:
  added: []
  patterns:
    - MainActor.assumeIsolated for NWBrowser callbacks on .main queue
    - DiscoveredRobot.Hashable by host (not UUID) for deduplication
    - mDNS-preferred merge: mDNS results replace IP-scan entries with same host

key-files:
  created:
    - ValetudoApp/ValetudoApp/Services/NWBrowserService.swift
  modified:
    - ValetudoApp/ValetudoApp/Services/NetworkScanner.swift
    - ValetudoApp/ValetudoApp/Views/AddRobotView.swift
    - ValetudoApp/ValetudoApp.xcodeproj/project.pbxproj

key-decisions:
  - "MainActor.assumeIsolated used for NWBrowser callbacks instead of Task/DispatchQueue — browser started on .main, so isolation is guaranteed at runtime"
  - "DiscoveredRobot Hashable based on host not UUID — enables Set-based deduplication in merge logic"
  - "IP scan always runs after mDNS (not only when mDNS empty) — ensures full coverage even when some devices dont broadcast Bonjour"

patterns-established:
  - "NWBrowserService pattern: @MainActor ObservableObject + MainActor.assumeIsolated in callbacks"
  - "Parallel discovery merge: prefer higher-metadata source (mDNS) when same host appears in both"

requirements-completed: [NET-02]

duration: 8min
completed: 2026-03-27
---

# Phase 02 Plan 02: mDNS/Bonjour Roboter-Erkennung Summary

**NWBrowserService mit _valetudo._tcp Bonjour-Discovery, TXT-Record-Parsing (friendlyName/model), NetworkScanner-Parallelstrategie (mDNS sofort + IP-Fallback nach 3s), und AddRobotView mit Bonjour-Badge und Sortierung**

## Performance

- **Duration:** 8 min
- **Started:** 2026-03-27T19:07:00Z
- **Completed:** 2026-03-27T19:15:36Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- NWBrowserService browst _valetudo._tcp und extrahiert friendlyName/model aus TXT-Records
- NetworkScanner startet mDNS sofort, IP-Scan nach 3s als Fallback; Ergebnisse werden dedupliciert (mDNS bevorzugt)
- AddRobotView zeigt mDNS-Ergebnisse mit Bonjour-Badge (Antennensymbol), model-Subtitle, und sortiert sie vor IP-Scan-Ergebnissen

## Task Commits

1. **Task 1: NWBrowserService + NetworkScanner mDNS-Integration** - `5e8ab34` (feat)
2. **Task 2: AddRobotView mDNS-Ergebnisse anzeigen** - `9bcb353` (feat)

## Files Created/Modified

- `ValetudoApp/ValetudoApp/Services/NWBrowserService.swift` (NEU) - @MainActor NWBrowser wrapper fuer _valetudo._tcp
- `ValetudoApp/ValetudoApp/Services/NetworkScanner.swift` - DiscoveredRobot mit DiscoveryMethod, mDNS-Integration
- `ValetudoApp/ValetudoApp/Views/AddRobotView.swift` - Bonjour-Badge, model-Subtitle, mDNS-Sortierung
- `ValetudoApp/ValetudoApp.xcodeproj/project.pbxproj` - NWBrowserService.swift eingetragen via xcodegen

## Decisions Made

- `MainActor.assumeIsolated` statt `DispatchQueue.main.async` in NWBrowser-Callbacks, da Browser auf `.main` gestartet wird — korrekte Isolation ohne zusatzlichen Dispatch-Overhead
- `DiscoveredRobot` Hashable-Implementierung nach `host` (nicht UUID) — ermoeglicht Deduplizierung per Set-Logik im Merge
- IP-Scan laeuft immer nach mDNS (nicht nur als Fallback wenn mDNS leer) — vollstaendige Abdeckung auch wenn Geraet kein Bonjour sendet

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Swift Concurrency: NWBrowser-Callback-Isolation**
- **Found during:** Task 1 (NWBrowserService erstellen)
- **Issue:** `@Published` Eigenschaften koennen in Sendable-Closures nicht mutiert werden; Compiler-Fehler `main actor-isolated property can not be mutated from a Sendable closure`
- **Fix:** `MainActor.assumeIsolated { }` in `browseResultsChangedHandler` und `stateUpdateHandler` — korrekt weil Browser auf `queue: .main` laeuft
- **Files modified:** ValetudoApp/ValetudoApp/Services/NWBrowserService.swift
- **Verification:** Build succeeded nach Fix
- **Committed in:** 5e8ab34

---

**Total deviations:** 1 auto-fixed (Rule 1 — Bug)
**Impact on plan:** Fix notwendig fuer korrekte Swift Concurrency-Konformitaet. Kein Scope-Creep.

## Issues Encountered

- xcodebuild build-lock (`database is locked`) durch parallele Agenten — nach kurzem Warten (15s) behoben
- Simulator `iPhone 16` nicht verfuegbar — auf `iPhone 17` (iOS 26.4) umgestellt

## Next Phase Readiness

- mDNS-Discovery vollstaendig implementiert und kompiliert
- NET-02 Requirement erfuellt
- Plan 02-03 (Map-Pixel-Caching) ist unabhaengig und kann direkt starten

---
*Phase: 02-network-layer*
*Completed: 2026-03-27*
