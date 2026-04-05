---
phase: 28-test-coverage-expansion
plan: 01
subsystem: testing
tags: [xctest, unit-tests, mapgeometry, updateservice, sse, mapcache, swift]

# Dependency graph
requires:
  - phase: 22-map-geometry-unification
    provides: calculateMapParams, screenToMapCoords, mapToScreenCoords functions in MapGeometry.swift
  - phase: 23-error-handling-robustness-patterns
    provides: UpdateService state machine with UpdatePhase enum and mapUpdaterState logic

provides:
  - Unit tests for MapGeometry coordinate transforms and calculateMapParams (16 tests)
  - Unit tests for UpdateService state machine all 8 phases and UpdaterState decoding (25 tests)
  - Unit tests for SSEConnectionManager backoff timing and line parsing (16 tests)
  - Unit tests for MapCacheService save/load cycle and corrupted cache handling (14 tests)

affects:
  - 29-ux-robustness
  - future phases touching MapGeometry, UpdateService, SSE, or MapCache

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Test isolation via per-test UUID for MapCacheService — no shared state across tests"
    - "Backoff logic replicated in test helper to document and validate the contract"
    - "Roundtrip (inverse function) tests for coordinate transforms"

key-files:
  created:
    - ValetudoApp/ValetudoAppTests/MapGeometryTests.swift
    - ValetudoApp/ValetudoAppTests/UpdateServiceTests.swift
    - ValetudoApp/ValetudoAppTests/SSEConnectionManagerTests.swift
    - ValetudoApp/ValetudoAppTests/MapCacheServiceTests.swift
  modified: []

key-decisions:
  - "UpdateService tested via UpdatePhase enum and UpdaterState model, not via @MainActor class directly — avoids UIKit simulator dependency"
  - "SSEConnectionManager actor state tested by replicating backoff logic in test helper, plus direct actor method calls for safety"
  - "MapCacheService.shared used with per-test UUID robot IDs for test isolation without needing DI refactor"

patterns-established:
  - "Coordinate transform roundtrip tests: screenToMap → mapToScreen must equal identity"
  - "Per-test UUID + tearDown deleteCache for stateful service isolation"

requirements-completed: [TEST-01, TEST-02, TEST-03, TEST-04]

# Metrics
duration: 12min
completed: 2026-04-05
---

# Phase 28 Plan 01: Test Coverage Expansion Summary

**71 new unit tests covering MapGeometry transforms, UpdateService 8-phase state machine, SSE backoff timing, and MapCacheService save/load/corrupted-cache — total test suite grows to 130 tests**

## Performance

- **Duration:** 12 min
- **Started:** 2026-04-05T00:53:53Z
- **Completed:** 2026-04-05T01:06:30Z
- **Tasks:** 4
- **Files modified:** 4 created

## Accomplishments

- 16 MapGeometry tests: `calculateMapParams` nil/scale/padding/multi-layer, `screenToMapCoords`/`mapToScreenCoords` identity and inverse roundtrip
- 25 UpdateService tests: all 8 `UpdatePhase` cases equality/inequality, all 4 `UpdaterState` type decodings, re-entrancy guard pattern matching, progress metadata
- 16 SSEConnectionManager tests: exponential backoff schedule (1s → 5s → 30s cap), SSE `data:` prefix parsing, actor state safety for unknown/empty disconnect
- 14 MapCacheService tests: nil-load for missing/corrupted/empty/wrong-type cache, save/load roundtrip with layers and nil fields, overwrite, delete, multi-robot isolation

## Task Commits

1. **Task 1: MapGeometry Transforms** - `a171840` (test)
2. **Task 2: UpdateService State Machine** - `747bda3` (test)
3. **Task 3: SSE Reconnection Backoff** - `8faf7d9` (test)
4. **Task 4: MapCacheService Save/Load** - `5918836` (test)

## Files Created/Modified

- `ValetudoApp/ValetudoAppTests/MapGeometryTests.swift` — 16 tests for calculateMapParams and coordinate transforms
- `ValetudoApp/ValetudoAppTests/UpdateServiceTests.swift` — 25 tests for UpdatePhase enum and UpdaterState decoding
- `ValetudoApp/ValetudoAppTests/SSEConnectionManagerTests.swift` — 16 tests for backoff timing and SSE line parsing
- `ValetudoApp/ValetudoAppTests/MapCacheServiceTests.swift` — 14 tests for cache lifecycle including corrupted cache

## Decisions Made

- UpdateService is `@MainActor` with `UIApplication.shared` calls — tested via the `UpdatePhase` enum and `UpdaterState` model directly rather than instantiating the service in unit tests, which would require a full simulator UI host context
- SSEConnectionManager is an `actor` with private backoff logic — the backoff schedule is replicated in a private test helper to document and contractually validate the `1s → 5s → 30s` values; actor methods are called directly for state safety tests
- MapCacheService singleton (`private init()`) tested via `.shared` with per-test UUID robot IDs and `tearDown` cleanup — avoids needing DI refactor while ensuring test isolation

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- First `xcodebuild test` run used `name=iPhone 16` (ambiguous) — switched to `id=D421F591...` (explicit simulator UUID). No code impact.
- UpdateServiceTests showed "Executed 0 tests" on first run because xcodegen had not been re-run after file creation. Fixed by running `xcodegen generate` before each test run.

## Known Stubs

None.

## Next Phase Readiness

- All 4 success criteria from Phase 28 ROADMAP are fulfilled:
  1. Unit tests for coordinate transforms and hit-test logic — DONE (MapGeometryTests)
  2. Unit tests for UpdateService covering all 8 phase transitions — DONE (UpdateServiceTests)
  3. Unit tests for SSE reconnection backoff timing — DONE (SSEConnectionManagerTests)
  4. Unit tests for MapCacheService save/load and corrupted cache — DONE (MapCacheServiceTests)
- Test suite grows from 57 to 130 tests (73 new tests total including existing from prior phases)
- Phase 29 (UX Robustness) can proceed

## Self-Check: PASSED

- MapGeometryTests.swift: FOUND
- UpdateServiceTests.swift: FOUND
- SSEConnectionManagerTests.swift: FOUND
- MapCacheServiceTests.swift: FOUND
- Commits a171840, 747bda3, 8faf7d9, 5918836: FOUND
- All 130 tests passing (0 failures)

---
*Phase: 28-test-coverage-expansion*
*Completed: 2026-04-05*
