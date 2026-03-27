# Project Research Summary

**Project:** ValetudiOS v1.2.0 — Quality & API Completeness Milestone
**Domain:** iOS native SwiftUI app — Valetudo robot vacuum controller
**Researched:** 2026-03-27
**Confidence:** HIGH

## Executive Summary

ValetudiOS v1.2.0 is a focused quality and API completeness milestone for an existing iOS 17+ SwiftUI app that already implements the majority of the Valetudo REST API. The research establishes a clear picture: the app has strong capability coverage but suffers from three systemic problems — massive views (1500+ lines) with logic mixed into layout, silent failures with no user-facing error feedback, and missing connections to critical Valetudo endpoints that affect real users (SSE streams, Events API, MapSnapshot, mDNS discovery). All additions use Apple-native frameworks only; the zero-external-dependencies constraint is maintained throughout.

The recommended approach is a phased build order that treats infrastructure and foundations first (Keychain, ErrorRouter, logging), then service-layer improvements (SSE via confirmed Valetudo endpoints, mDNS via NWBrowser), then view-layer refactoring (ViewModel extraction from the three massive views), and finally test coverage as a forcing function that verifies the extracted architecture. A key correction from initial STACK.md research: Valetudo DOES expose three SSE endpoints (`/api/v2/robot/state/sse`, `/api/v2/robot/state/attributes/sse`, `/api/v2/robot/state/map/sse`), verified directly against `RobotRouter.js` in the Valetudo source. True SSE replaces adaptive polling as the primary real-time mechanism.

The principal risks are: credential loss during UserDefaults-to-Keychain migration (verify Keychain write before deleting from UserDefaults); SSE Task leaks if the existing polling loop is not explicitly disabled on SSE connect; and mDNS silent failure if `NSBonjourServices` + `NSLocalNetworkUsageDescription` are not added to Info.plist before testing. All three risks have concrete, well-documented prevention strategies.

---

## Key Findings

### Recommended Stack

The existing stack (Swift 5.9, SwiftUI, iOS 17+, URLSession, Foundation, zero external dependencies) requires only five Apple-native additions. No minimum version bumps are needed since all additions have been available since iOS 14 or earlier. The most architecturally significant addition is `URLSession.AsyncBytes` for SSE streaming — it enables replacing the 5-second polling loop with event-driven updates from confirmed Valetudo SSE endpoints.

**Core technologies:**
- `Security.framework` (Keychain): Secure credential storage — platform standard, survives app uninstall, excluded from iCloud backup by default
- `Network.framework` NWBrowser: mDNS/Bonjour discovery of `_valetudo._tcp` — already imported in the project, replaces 254-IP brute-force scan
- `URLSession.AsyncBytes`: SSE stream consumption from Valetudo's 3 confirmed SSE endpoints — built into Foundation, uses Swift structured concurrency, no new dependency
- `os.Logger`: Structured logging replacing 80+ `print()` calls — integrates with Console.app, has privacy annotations to protect credentials
- `XCTest`: Unit test target — foundational for verifying extracted ViewModels and Keychain wrapper

### Expected Features

**Must have (table stakes for v1.2.0):**
- Robot list row fully tappable — currently only text area responds, feels broken
- Notification action handlers (GO_HOME, LOCATE) — defined but silently do nothing, destroys user trust
- User-visible error feedback — 80+ silent failures across all views; foundational for every other addition
- mDNS/Bonjour robot discovery — brute-force scan is slow; Valetudo advertises `_valetudo._tcp` natively
- SSE real-time state updates — 5-second polling creates noticeable UI lag; 3 SSE endpoints confirmed in source
- MapSnapshot capability — standard Valetudo feature for map backup before edits; not in app
- PendingMapChange handling — robots can be stuck awaiting accept/reject after mapping pass
- Valetudo Events display — `/api/v2/events/` endpoint covers consumable depletion, errors, bin-full; entirely unconsumed
- CleanRouteControl — simple GET/PUT, present in Valetudo web UI, expected in native app

**Should have (differentiators, ship as v1.2.x patches):**
- Keychain credential storage — security differentiator; UserDefaults stores credentials in plaintext
- ObstacleImages browsing — unique to AI-camera robots; inline in cleaning history
- VoicePackManagement — better UX than web UI for non-English users
- AutoEmptyDock/MopDock duration controls — minor dock refinements

**Defer to v2+:**
- Background monitoring via BGAppRefreshTask — quota-limited, requires APNS infrastructure
- WiFi reconfiguration in-app — connection drops mid-request; high brick risk
- Multi-floor map management — Valetudo itself does not support multiple maps

### Architecture Approach

The target architecture introduces a ViewModel layer between views and services, an `SSEConnectionManager` actor that owns SSE lifecycle per robot, a `KeychainStore` service that handles transparent migration from UserDefaults, an `NWBrowserService` that delegates from the existing `NetworkScanner`, and a centralized `ErrorRouter` ViewModifier. The three massive views (MapView, RobotDetailView, RobotSettingsView — each 400-1500 lines) become thin declarative shells; all logic moves to `@MainActor ObservableObject` ViewModels owned via `@StateObject`.

**Major components:**
1. `SSEConnectionManager` (new actor) — owns all URLSession.bytes streams per robot, cancels/restarts on disconnect; RobotManager checks this before each poll cycle
2. `KeychainStore` (new service) — wraps SecItem APIs, handles one-time UserDefaults migration transparently on first access
3. `ErrorRouter` (new helper) — ViewModifier that maps `Error?` binding to SwiftUI `.alert`; installs once per screen-level view
4. `NWBrowserService` (new service) — NWBrowser wrapper; NetworkScanner delegates to it as primary path, retains IP-scan as fallback
5. `MapViewModel` / `RobotDetailViewModel` / `RobotSettingsViewModel` (new ViewModels) — extract all async command logic, loading state, and error state from the three massive views

### Critical Pitfalls

1. **`@StateObject` vs `@ObservedObject` when extracting ViewModels** — Using `@ObservedObject` for a ViewModel created inside a view causes it to be recreated on every parent re-render, destroying in-flight async Tasks and all state. Rule: `@StateObject` for ViewModels created in the view, `@ObservedObject` only when passed in from a parent. Define this rule in CONVENTIONS before the first ViewModel file is created.

2. **Credential loss during Keychain migration** — Code that writes to Keychain then deletes from UserDefaults in the same step will permanently destroy credentials if the Keychain write fails silently. Prevention: read-back verification after `SecItemAdd` before touching UserDefaults; treat `errSecDuplicateItem` as success; keep UserDefaults as fallback for one release cycle.

3. **SSE Task leak with simultaneous polling** — If the existing polling loop is not explicitly disabled when SSE connects, both paths update `@Published` state simultaneously causing flicker, doubled battery drain, and Task accumulation. Define a strict contract: SSE active = polling disabled. Never run both for the same robot.

4. **NWBrowser silent failure without Info.plist keys** — `NWBrowser` starts, reports `.ready`, but finds nothing if `NSBonjourServices` does not include `_valetudo._tcp`. Add both `NSBonjourServices` and `NSLocalNetworkUsageDescription` to `project.yml` Info.plist section before writing any NWBrowser code. Test only on real device.

5. **`os.Logger` credential exposure** — Migrating `print()` calls with `.public` privacy annotation (added while debugging, not reverted) exposes credentials in system logs and sysdiagnose bundles. Audit all existing `print()` calls for sensitivity before migration; never log credential values at any privacy level.

---

## Implications for Roadmap

Based on combined research, a four-phase structure maps cleanly to the dependency graph identified in ARCHITECTURE.md.

### Phase 1: Foundation — Infrastructure & Error Handling

**Rationale:** `KeychainStore` and `ErrorRouter` have no upstream dependencies, unblock all other phases, and address the two highest-risk quality issues (credential security + silent failures). `os.Logger` migration belongs here because it must precede any new logging in Phase 2+.

**Delivers:** Secure credential storage with zero data loss; consistent error presentation across all views; structured logging with credential safety; all `print()` calls replaced.

**Addresses:** Keychain credential storage (P2 from FEATURES.md), error feedback system (P1), logging cleanup

**Avoids:** Credential loss (Pitfall 2), credential exposure via logging (Pitfall 5)

**Research flag:** Standard patterns — well-documented SecItem API and SwiftUI ViewModifier patterns. No deeper research needed.

---

### Phase 2: Network Layer — SSE & mDNS

**Rationale:** `SSEConnectionManager` and `NWBrowserService` are the highest-value user-visible improvements and form a coherent network layer. SSE depends on `ValetudoAPI` modifications (additive only). mDNS is independent but belongs here as the other "network quality" fix. Both require careful state management that must be correct before ViewModels build on top.

**Delivers:** Real-time robot state via Valetudo's confirmed SSE endpoints (replaces 5-second polling); instant robot discovery via Bonjour (replaces 254-IP scan with 5s-timeout fallback); robot row fully tappable (quick UX fix that belongs in this phase's delivery).

**Addresses:** SSE real-time updates (P1), mDNS discovery (P1), robot row tappability (P1)

**Avoids:** SSE Task leak (Pitfall 3), NWBrowser silent failure (Pitfall 4), running SSE and polling simultaneously

**Research flag:** SSE integration has a verified Valetudo-side 5-client connection limit — `SSEConnectionManager` must enforce one shared connection per robot. This is documented but deserves implementation-time validation.

---

### Phase 3: API Completeness — New Capabilities & Events

**Rationale:** With stable infrastructure (Phase 1) and a reliable network layer (Phase 2), new capability endpoints can be added incrementally without risk to existing functionality. Notification action handlers belong here because they require `RobotManager` access from AppDelegate, which is cleaner once the service layer is stable.

**Delivers:** MapSnapshot, PendingMapChange handling, CleanRouteControl, Valetudo Events display, notification action handlers (GO_HOME, LOCATE).

**Addresses:** MapSnapshot (P1), PendingMapChange (P1), CleanRouteControl (P1), Events display (P1), notification handlers (P1)

**Avoids:** PendingMapChange leaving robots stuck; notification actions silently failing (UX pitfall)

**Research flag:** Standard patterns — all endpoints verified against Valetudo source. No research needed. Events API (`/api/v2/events/`) endpoint structure is confirmed.

---

### Phase 4: View Refactoring & Test Coverage

**Rationale:** ViewModel extraction is the highest-risk change (touching the three largest files) and should happen after new features are stable. The test target is set up here because it creates the forcing function for clean ViewModel interfaces and validates Keychain migration, SSE state updates, and map decompression logic.

**Delivers:** Three ViewModels extracted from massive views; XCTest target with tests for pure logic (timer conversion, consumable percentage, map RLE decompression, Keychain round-trip); map pixel cache moved from computed property to pre-computed reference in RobotManager.

**Addresses:** Tech debt (massive views), map cache performance (Pitfall 8), `@StateObject` ownership correctness (Pitfall 1)

**Avoids:** `@ObservedObject` ownership error (Pitfall 1), `@MainActor` XCTest isolation conflicts (Pitfall 6), map cache on value-type struct (Pitfall 8)

**Research flag:** `@MainActor` test isolation pattern must be established in the first test file — annotate individual test methods, not the class. Standard pattern but easy to get wrong.

---

### Phase Ordering Rationale

- Phase 1 before everything: credential loss is unrecoverable; error routing is needed by all subsequent ViewModels
- Phase 2 before Phase 3: SSE/mDNS establish the network layer contracts that capability additions depend on
- Phase 3 before Phase 4: new capabilities must exist and be working before ViewModels are extracted around them; extracting from moving targets increases conflict risk
- Phase 4 last: ViewModel extraction touches the largest files; doing it last means tests can immediately validate the extracted interfaces

### Research Flags

Phases needing deeper research during planning:
- **Phase 2 (SSE):** Validate Valetudo's 5-client SSE limit behavior under reconnect conditions. The `SSEConnectionManager` design assumes one shared connection per robot is sufficient — confirm this holds when both attributes SSE and map SSE are used concurrently.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Foundation):** SecItem API, SwiftUI ViewModifier, os.Logger — all well-documented Apple-native APIs
- **Phase 3 (API Completeness):** All endpoints verified against Valetudo source; implementation follows existing capability pattern in the codebase
- **Phase 4 (Tests):** XcodeGen test target setup confirmed; `@MainActor` XCTest pattern documented

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All additions are Apple-native frameworks, available since iOS 14 or earlier. Zero-dependency constraint maintained. |
| Features | HIGH | SSE endpoints, capability routes, and Events API verified directly against Valetudo source on GitHub. mDNS service type confirmed from `NetworkAdvertisementManager.js`. |
| Architecture | HIGH | Patterns sourced from Apple documentation, Swift by Sundell, SwiftLee — established MVVM and actor patterns for iOS 17. |
| Pitfalls | HIGH | Each pitfall sourced from official Apple documentation, Swift Forums, or documented community issues. Recovery strategies included. |

**Overall confidence:** HIGH

### Gaps to Address

- **SSE concurrent connection behavior:** Research confirms the 5-client limit but does not cover behavior when attributes SSE and map SSE are both open for the same robot. Implementation should start with attributes SSE only and add map SSE in MapView conditionally.
- **Keychain behavior after first device unlock:** The `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` class requires device to be unlocked at least once after restart. The "Looks Done But Isn't" checklist in PITFALLS.md flags this — must be on the manual test checklist, not just automated tests.
- **Valetudo version range for SSE:** The SSE endpoints were confirmed in the current master branch. Users running older Valetudo versions may not have these endpoints. The app should gracefully fall back to polling if the SSE endpoint returns a non-200 response.

---

## Sources

### Primary (HIGH confidence)
- Valetudo `RobotRouter.js` — SSE endpoint verification: https://github.com/Hypfer/Valetudo/blob/master/backend/lib/webserver/RobotRouter.js
- Valetudo `NetworkAdvertisementManager.js` — mDNS service type `_valetudo._tcp`: https://github.com/Hypfer/Valetudo/blob/master/backend/lib/NetworkAdvertisementManager.js
- Valetudo `capabilityRouters/index.js` — complete capability router list: https://github.com/Hypfer/Valetudo/blob/master/backend/lib/webserver/capabilityRouters/index.js
- Valetudo `valetudo_events/events/` — event type files: https://github.com/Hypfer/Valetudo/tree/master/backend/lib/valetudo_events/events
- Apple Developer Documentation: Keychain Services, NWBrowser, URLSession.AsyncBytes, os.Logger, XCTest
- Apple WWDC21 "Use async/await with URLSession" — URLSession.AsyncBytes iOS 15+
- XcodeGen test target fixtures — `bundle.unit-test` target type confirmed

### Secondary (MEDIUM confidence)
- Valetudo Newcomer Guide — https://valetudo.cloud/pages/general/newcomer-guide.html
- Valetudo DeepWiki — SSE endpoints and polling fallback need
- SwiftLee: OSLog and Unified Logging — verified against Apple WWDC2020 content
- TN3179: Understanding local network privacy — Apple Developer Documentation
- Valetudo Discussion #968 — OpenAPI spec added in 2021.06.0

### Tertiary (informational)
- ValetudiOS codebase analysis: `.planning/codebase/CONCERNS.md` (2026-03-27)

---
*Research completed: 2026-03-27*
*Ready for roadmap: yes*
