---
phase: 03-api-completeness
plan: 01
subsystem: API Layer / Data Models
tags: [api, models, swift, codable, capabilities]
dependency_graph:
  requires: []
  provides: [MapSnapshot, PendingMapChangeState, CleanRouteState, ValetudoEvent, getMapSnapshots, restoreMapSnapshot, getPendingMapChange, handlePendingMapChange, getCleanRoute, setCleanRoute, getEvents, getObstacleImage]
  affects: [ValetudoAPI.swift, RobotState.swift, RobotMap.swift]
tech_stack:
  added: []
  patterns: [Codable structs, actor-based API methods, raw binary fetch for image data, defensive dict/array decode]
key_files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/Models/RobotState.swift
    - ValetudoApp/ValetudoApp/Models/RobotMap.swift
    - ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift
decisions:
  - "ValetudoEvent.getEvents() uses dict-first then array fallback — API spec is ambiguous, defensive decoding avoids runtime crashes"
  - "getObstacleImage uses direct URLSession.data instead of request<T: Decodable> — binary image data cannot be JSON-decoded"
  - "EntityMetaData extended with id and label as optional — backward compatible, existing angle property preserved"
metrics:
  duration: "~8 min"
  completed: "2026-03-27T22:39:22Z"
  tasks: 2
  files_modified: 3
requirements: [API-01, API-02, API-03, API-04, UX-04]
---

# Phase 03 Plan 01: API Contracts and Model Structs Summary

**One-liner:** 4 neue Codable-Structs und 8 API-Methoden fuer MapSnapshots, PendingMapChange, CleanRoute, Events und ObstacleImages als Contracts fuer Phase-3-Capabilities.

## What Was Built

### Task 1: Model-Structs (RobotState.swift + RobotMap.swift)

Vier neue Structs am Ende von `RobotState.swift` hinzugefuegt:

- **MapSnapshot** — `Codable, Identifiable` mit `id: String` fuer MapSnapshotCapability-Array-Response
- **PendingMapChangeState** — `Codable` mit `enabled: Bool` fuer PendingMapChangeHandlingCapability
- **CleanRouteState** — `Codable` mit `route: String` fuer CleanRouteControlCapability
- **ValetudoEvent** — `Codable, Identifiable` mit `__class`, `id`, `timestamp`, `processed`, `type`, `subType`, `message`, plus computed properties `displayName` (lokalisiert) und `iconName` (SF Symbols)

`EntityMetaData` in `RobotMap.swift` um zwei optionale Properties erweitert:
- `id: String?` — UUID fuer Obstacle-Image-URL `/ObstacleImagesCapability/img/{id}`
- `label: String?` — lesbares Label z.B. "Pedestal (89%)"

### Task 2: API-Methoden (ValetudoAPI.swift)

8 neue Methoden in `extension ValetudoAPI` eingefuegt:

| Methode | Endpoint | Pattern |
|---------|----------|---------|
| `getMapSnapshots()` | GET MapSnapshotCapability | `request<[MapSnapshot]>` |
| `restoreMapSnapshot(id:)` | PUT MapSnapshotCapability | `requestVoid` mit `{action: restore, id}` |
| `getPendingMapChange()` | GET PendingMapChangeHandlingCapability | `request<PendingMapChangeState>` |
| `handlePendingMapChange(action:)` | PUT PendingMapChangeHandlingCapability | `requestVoid` mit `{action}` |
| `getCleanRoute()` | GET CleanRouteControlCapability | `request<CleanRouteState>` |
| `setCleanRoute(route:)` | PUT CleanRouteControlCapability | `requestVoid` mit `{route}` |
| `getEvents()` | GET /valetudo/events | Dict-first dann Array-Fallback |
| `getObstacleImage(id:)` | GET ObstacleImagesCapability/img/{id} | Raw `URLSession.data` → `Data` |

## Decisions Made

1. **getEvents() dict/array defensiv** — Valetudo-Spec beschreibt Events nicht eindeutig. Dict-first mit Array-Fallback verhindert Laufzeit-Abbrueche bei unterschiedlichen Valetudo-Versionen.

2. **getObstacleImage als raw binary fetch** — Bild-Daten koennen nicht via `request<T: Decodable>` verarbeitet werden. Eigene URLSession.data-Implementierung mit Auth-Header analog zu SSE-Methoden.

3. **EntityMetaData rueckwaertskompatibel** — `angle: Int?` beibehalten, neue Properties als Optional hinzugefuegt. Kein CodingKeys-Enum noetig da Swift-Compiler Property-Namen 1:1 auf JSON-Keys mappt.

## Deviations from Plan

None — Plan executed exactly as written.

## Known Stubs

None — alle Methoden sind vollstaendig implementiert. Lokalisierungs-Keys fuer `ValetudoEvent.displayName` (z.B. `event.dustbin_full`) werden in Plan 03 beim UI-Bau in `Localizable.xcstrings` eingetragen.

## Commits

| Task | Commit | Files |
|------|--------|-------|
| Task 1: Model-Structs | 22f62af | RobotState.swift, RobotMap.swift |
| Task 2: API-Methoden | ab97fb5 | ValetudoAPI.swift |

## Self-Check: PASSED
