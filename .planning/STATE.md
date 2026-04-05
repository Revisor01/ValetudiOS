---
gsd_state_version: 1.0
milestone: v1.2.0
milestone_name: Quality & API Completeness
status: executing
last_updated: "2026-04-05T00:52:49.116Z"
last_activity: 2026-04-05 -- Phase 28 execution started
progress:
  total_phases: 30
  completed_phases: 26
  total_plans: 65
  completed_plans: 62
  percent: 95
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-04)

**Core value:** Zuverlässige, native iOS-Steuerung von Valetudo-Robotern ohne Cloud-Abhängigkeit
**Current focus:** Phase 28 — test-coverage-expansion

## Current Position

Phase: 28 (test-coverage-expansion) — EXECUTING
Plan: 1 of 2
Status: Executing Phase 28
Last activity: 2026-04-05 -- Phase 28 execution started

Progress: [........] 0/8 phases complete

## Accumulated Context

### Decisions

- v2.2.0 completed: Room Interaction & Cleaning Order (Phases 20-21)
- v3.0.0 created from CONCERNS.md audit — all 7 concern categories mapped to 8 phases
- Phase 22 (Map Geometry Unification) is foundation — dedup und State-Zentralisierung first
- Phases 23-26 können nach Phase 22 parallel laufen
- Phase 27 (Accessibility) braucht Phase 25 (View Architecture) — Labels auf dekomponierte Views
- Phase 28 (Tests) braucht Phase 22 (extrahierte Transforms) + Phase 23 (UpdateService patterns)
- Phase 29 (UX Robustness) braucht Phase 23 (ErrorRouter)
- [Phase 22-map-geometry-unification]: didSet sync pattern chosen for room selection — @Binding requires stored property; RobotManager is now single source of truth for all per-robot session state
- [Phase 24-map-performance]: data.hashValue used for cache dedup in MapCacheService — avoids CryptoKit, acceptable collision risk
- [Phase 24-map-performance]: SSE stream replaces 2s polling in MapViewModel — exponential backoff 2s/5s/30s, HTTP fallback on failure
- [Phase 24-map-performance]: segmentPixelSets is @ObservationIgnored (hit-testing only), cachedSegmentInfos is observable (overlays re-render on change); SegmentInfo defined top-level in MapViewModel for public accessibility
- [Phase 24-map-performance]: staticLayerImage CGImage pre-rendered on background thread via UIGraphicsImageRenderer, Canvas draws only dynamic elements per frame
- [Phase 26-security-hardening]: Warning-Banner als eigene Section statt Footer-Text fuer visuelle Prominenz und Konsistenz
- [Phase 26-security-hardening]: ignoreCertificateErrors wird auf false zurueckgesetzt wenn useSSL=false
- [Phase 27-accessibility]: children: .ignore auf Canvas statt .combine - Canvas hat keine sinnvollen VoiceOver-Kinder
- [Phase 27-accessibility]: accessibilityHint mit Auswahl-Kontext auf Room-Buttons - VoiceOver liest aktuellen Status vor

### Pending Todos

None.

### Blockers/Concerns

None.
