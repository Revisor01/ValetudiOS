---
phase: 07-bugfixes-robustness
plan: "03"
subsystem: SSEConnectionManager
tags: [sse, reconnect, backoff, robustness]
dependency_graph:
  requires: []
  provides: [exponential-backoff-reconnect]
  affects: [SSEConnectionManager.streamWithReconnect]
tech_stack:
  added: []
  patterns: [exponential-backoff, retry-count]
key_files:
  created: []
  modified:
    - ValetudoApp/ValetudoApp/Services/SSEConnectionManager.swift
decisions:
  - "[Phase 07-bugfixes-robustness]: SSE backoff uses retryCount-based switch (1s/5s/30s) — retryCount reset to 0 after successful connect; each retry attempt logged with count and delay"
metrics:
  duration: "2min"
  completed: "2026-03-28"
  tasks: 1
  files: 1
requirements:
  - FIX-03
---

# Phase 07 Plan 03: SSE Exponential Backoff Summary

**One-liner:** SSE reconnect replaced fixed 30s sleep with 1s/5s/30s exponential backoff using retryCount variable.

## What Was Built

`streamWithReconnect()` in `SSEConnectionManager.swift` now uses a `retryCount` variable to calculate the reconnect delay:

- First error: 1 second wait
- Second error: 5 second wait
- Third and beyond: 30 second wait (capped)
- After successful connection: retryCount reset to 0

Each retry logs both the retry number and the wait duration for debugging visibility.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Exponential backoff in streamWithReconnect() | af1c1a0 | SSEConnectionManager.swift |

## Decisions Made

- `retryCount`-based switch statement chosen over formula-based backoff — three discrete tiers map exactly to the spec (1s/5s/30s) without floating-point edge cases
- `retryCount = 0` placed immediately after `streamStateLines()` succeeds (before the for-await loop) — ensures any prior backoff state is cleared the moment connection is established

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check

- [x] `ValetudoApp/ValetudoApp/Services/SSEConnectionManager.swift` modified
- [x] `retryCount` variable added before while loop
- [x] `retryCount = 0` on successful connect
- [x] Backoff switch: case 1 = 1s, case 2 = 5s, default = 30s
- [x] Each retry logs count and delay
- [x] `seconds(30)` no longer appears as a direct sleep argument
- [x] Build compiles without errors
- [x] Commit af1c1a0 exists

## Self-Check: PASSED
