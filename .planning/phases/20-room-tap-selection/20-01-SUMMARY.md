---
phase: 20-room-tap-selection
plan: "01"
status: complete
started: "2026-04-04"
completed: "2026-04-04"
---

# Plan 20-01: SpatialTapGesture auf Canvas — Summary

## What Was Built

SpatialTapGesture auf dem Canvas in InteractiveMapView, sodass Räume durch Tap auf ihre farbige Fläche ausgewählt werden können — unabhängig von Room-Labels.

## Key Changes

### MapInteractiveView.swift
- **handleCanvasTap(at:size:)** — Neue Methode: Rücktransformation der Tap-Koordinaten in Pixel-Space, linearer Lookup in `decompressedPixels` der Segment-Layer, erster Treffer gewinnt
- **SpatialTapGesture** — Auf dem Canvas registriert (vor `.overlay`), ruft `handleCanvasTap` auf
- Mode-Guard: Nur in `.none` und `.roomEdit` aktiv
- Exakte Pixel-Toleranz, kein Radius

## key-files

### created
(none — existing file modified)

### modified
- `ValetudoApp/ValetudoApp/Views/MapInteractiveView.swift` — +35 lines (handleCanvasTap + SpatialTapGesture)

## Commits

- `7963693` feat(map): add SpatialTapGesture for room selection by tapping area

## Self-Check: PASSED

All acceptance criteria verified:
- handleCanvasTap contains mode guard, reverse transform, segment pixel lookup
- SpatialTapGesture registered before .overlay
- No radius/tolerance logic
- Build succeeds
- Human verification: all 7 scenarios passed

## Deviations

None — implemented exactly as planned.
