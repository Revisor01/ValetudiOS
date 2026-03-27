# Pitfalls Research

**Domain:** iOS/SwiftUI app — refactoring + feature additions to ValetudiOS v1.2.0
**Researched:** 2026-03-27
**Confidence:** HIGH (iOS/SwiftUI-specific, verified against official docs and community sources)

---

## Critical Pitfalls

### Pitfall 1: @StateObject vs @State when extracting ViewModels

**What goes wrong:**
When extracting logic from `@State`-heavy views into `ObservableObject` ViewModels, developers reach for `@State var viewModel = MyViewModel()` because `@Observable` encourages this pattern. This is correct for `@Observable` (iOS 17 macro), but with `ObservableObject` (the current pattern in this codebase), the ViewModel must be owned via `@StateObject`, not `@State`. Using `@ObservedObject` instead of `@StateObject` causes the ViewModel to be recreated every time the parent view re-renders, destroying all in-flight state and async Tasks.

**Why it happens:**
MapView, RobotDetailView and RobotSettingsView all have significant `@State` variables. When extracting them into a class, the instinct is to treat the new class like a struct replacement — but ObservableObject ownership semantics differ from value types. `@ObservedObject` signals "I don't own this", `@StateObject` signals "I own this and it persists across re-renders."

**How to avoid:**
- Use `@StateObject` for ViewModels created inside a view (ownership).
- Use `@ObservedObject` only when the ViewModel is passed in from a parent.
- Never use `@State` to hold an `ObservableObject` instance — it does not guarantee lifecycle stability in the same way.
- If migrating to `@Observable` macro later: store all app-level ViewModels in the `App` struct or a parent view that does not get destroyed, not in leaf views.

**Warning signs:**
- ViewModel's `init()` is called more than once during normal navigation.
- Async Task results disappear on parent re-render (e.g., map data vanishes when status bar updates).
- Published properties reset when another part of the UI changes.

**Phase to address:**
ViewModel extraction phase (Tech Debt). Define ownership rule in CONVENTIONS before the first ViewModel is created.

---

### Pitfall 2: Credentials deleted on UserDefaults→Keychain migration without rollback

**What goes wrong:**
Code reads credentials from UserDefaults, writes them to Keychain, then deletes from UserDefaults. If the Keychain write fails silently (device locked, Keychain full, sandbox issue during testing), the credentials are gone permanently. Users must re-enter all robot configurations.

**Why it happens:**
Keychain APIs return OSStatus codes that are easy to ignore. `SecItemAdd` returning `errSecDuplicateItem` (already exists) is treated as an error but is actually harmless — calling code may bail out of the migration early. The delete-from-UserDefaults step running unconditionally after an ignored write error is the killer.

**How to avoid:**
- Read from Keychain first. If a credential is already there, skip migration for that robot.
- Write to Keychain and verify with a read-back before deleting from UserDefaults.
- Treat `errSecDuplicateItem` as success, not failure.
- Keep UserDefaults credentials as a fallback for one app version cycle (v1.2.0 writes to Keychain, v1.3.0 removes UserDefaults read path).
- Store credentials per-robot keyed by `robotId` (UUID), not by hostname — hostnames can change.

**Warning signs:**
- Migration code that calls `try? encoder.encode(...)` on Keychain write — silent failure guaranteed.
- No read-back verification after `SecItemAdd`.
- `UserDefaults.standard.removeObject(forKey:)` called in the same function that writes Keychain.

**Phase to address:**
Security phase (Credentials migration). Do not combine Keychain write and UserDefaults cleanup in the same atomic step.

---

### Pitfall 3: SSE Task leaks when coexisting with the polling loop

**What goes wrong:**
Adding SSE to a codebase that already has a `Timer`-based polling loop creates two overlapping state update paths. Both paths update `@Published` properties on `RobotManager`. The result: duplicate UI updates (harmless but wasteful) or contradictory state — the polling loop sees the robot as idle, SSE fires a cleaning-started event 300ms later, leading to observable flicker. More critically: if the SSE Task is stored in a local variable instead of a cancellable property, the Task is deallocated when its scope exits but the underlying URLSession connection remains open, consuming network resources.

**Why it happens:**
`URLSession` async streaming via `bytes(for:)` keeps the URLSession-level connection alive independently of the Swift `Task` wrapper. The Task being cancelled does not automatically cancel the URLSession data task in all circumstances. This is a known Swift concurrency footgun documented in the Swift Forums.

**How to avoid:**
- Store the SSE `Task` as a `private var sseTask: Task<Void, Never>?` on `RobotManager`.
- On SSE connect: cancel polling timer. On SSE disconnect or error: restart polling timer as fallback.
- Never run both SSE and polling for the same robot simultaneously.
- Explicitly call `sseTask?.cancel()` in `deinit` and whenever a robot is removed.
- Wrap the `AsyncSequence` iteration in a do/catch that handles `CancellationError` — do not swallow it.

**Warning signs:**
- SSE connection count grows over time in network instruments.
- Robot status flickers between two states rapidly.
- Memory usage climbs after repeated robot reconnects.
- `[API DEBUG]` prints fire for a robot after it has been removed from the list.

**Phase to address:**
SSE / Adaptive Polling phase. Define a single source-of-truth contract: SSE is primary, polling is fallback — never both active.

---

### Pitfall 4: NWBrowser mDNS silently fails without the correct Info.plist key

**What goes wrong:**
`NWBrowser` is initialized and started, `stateUpdateHandler` fires with `.ready`, but `browseResultsChangedHandler` never fires — the browser finds nothing. This happens when `NSBonjourServices` in Info.plist does not list the exact service type being browsed (e.g. `_valetudo._tcp`). The system silently suppresses discovery without returning an error.

**Why it happens:**
iOS 14+ requires apps to declare all Bonjour service types they intend to discover in `Info.plist` under `NSBonjourServices` (array of strings). This is separate from the Local Network usage description (`NSLocalNetworkUsageDescription`). Both keys are required. Missing either one causes silent failure on device; the Simulator behavior differs and may not reproduce the failure.

**How to avoid:**
- Add both keys to Info.plist (managed via XcodeGen's `project.yml`):
  - `NSLocalNetworkUsageDescription`: user-facing explanation string (localized)
  - `NSBonjourServices`: `["_valetudo._tcp"]`
- Test on a real device, not Simulator — Simulator's local network permission behavior changed in Xcode 16 and may silently deny or auto-grant.
- The first `stateUpdateHandler` callback is always `.ready` regardless of permission status — do not interpret this as "discovery working."
- The Local Network permission prompt only fires when actual network traffic is attempted, not when `NWBrowser` is created. Make sure the first scan attempt triggers visible UI so users see the permission dialog in context.

**Warning signs:**
- `NWBrowser` state is `.ready` but zero results after 5+ seconds.
- Works in Simulator, fails on device.
- No Local Network permission prompt appears on first scan.

**Phase to address:**
mDNS / Network Scanner phase. Add Info.plist keys before writing any `NWBrowser` code — failures are silent otherwise.

---

### Pitfall 5: os.Logger logs sensitive credentials in default privacy level

**What goes wrong:**
Migrating from `print("[API DEBUG] Authorization: \(authHeader)")` to `logger.debug("Authorization: \(authHeader)")` without privacy annotations makes the string appear redacted in Console.app on non-attached devices (`<private>`), but if the developer adds `.public` visibility to "make logs readable" during debugging and forgets to revert, credentials appear in plaintext in system logs. System logs on iOS are accessible to other apps with the `com.apple.diagnosticd.diagnostic` entitlement and are included in sysdiagnose bundles shared with Apple Support.

**Why it happens:**
`os.Logger` defaults dynamic strings to `.private`. Developers debugging SSE or authentication issues add `.public` to see values, then forget to remove or narrow the annotation before shipping. The existing codebase already has 80+ `print()` calls with sensitive values — a find-and-replace migration without reviewing each call is dangerous.

**How to avoid:**
- Never log credentials (username, password, Authorization header value) at any level. Log presence/absence only: `logger.debug("Auth header present: \(authHeader != nil)")`
- For hostnames and robot names: `.private` (default) is correct — these are personally identifying.
- For error codes and HTTP status codes: `.public` is safe.
- For request paths (no query params): `.public` is safe.
- Review all existing `print()` calls before migration. Flag each with a category: SAFE / SENSITIVE / INTERNAL.
- Use subsystem/category to separate API logs, map logs, scan logs — enables filtering without enabling `.public` globally.

**Warning signs:**
- `logger.debug("url: \(url, privacy: .public)")` for a URL that includes credentials.
- Logger subsystem is `"com.app"` for everything — no way to filter by domain without seeing all logs.
- Authorization header value logged anywhere.

**Phase to address:**
Logging refactor phase. Audit all `print()` calls for sensitivity BEFORE migration, not after.

---

## Moderate Pitfalls

### Pitfall 6: @MainActor isolation conflicts in XCTest with ObservableObject ViewModels

**What goes wrong:**
The new ViewModels will be `@MainActor`-isolated `ObservableObject` classes (consistent with `RobotManager`). Writing unit tests for them requires the test to also run on the main actor. In Xcode 15, annotating the entire `XCTestCase` subclass with `@MainActor` generates a warning about mismatched actor isolation from the non-isolated `XCTestCase` superclass. The test compiles but the warning indicates potential runtime issues. In Xcode 16 this is resolved, but the project targets Xcode 15+.

**How to avoid:**
- Annotate individual test methods with `@MainActor` rather than the entire class.
- For async test methods: `@MainActor func testSomething() async throws { ... }`.
- For `setUp` and `tearDown`: also annotate with `@MainActor` if they touch ViewModel state.
- Test the ViewModel's pure logic (coordinate transforms, time calculations, percentage math) in non-isolated unit tests — extract pure functions to static methods or free functions.
- Do not test `@Published` observation directly in unit tests — test state changes by calling methods and asserting final state, not by subscribing to publishers in tests.

**Warning signs:**
- Test file has `@MainActor class MyViewModelTests: XCTestCase` at the class level.
- Tests use `XCTExpectation` and `wait(for:timeout:)` to observe `@Published` changes — fragile, timing-dependent.

**Phase to address:**
Test coverage phase. Establish the `@MainActor` test pattern in the first test file — it sets the pattern for all subsequent tests.

---

### Pitfall 7: NavigationLink vs Button confusion makes only part of the row tappable

**What goes wrong:**
In the robot list, if the row is structured as a `NavigationLink` containing a custom `HStack`, only the area occupied by the HStack's content is tappable — not the full row width. Empty space in the row does not respond to taps. This is a common SwiftUI `List` + `NavigationLink` interaction issue.

The fix of wrapping in a `Button` with `.buttonStyle(.plain)` inside a `List` introduces a different problem: SwiftUI's `List` automatically makes a `Button` fill the entire row, but if `NavigationLink` and `Button` compete in the same row, tap handling becomes non-deterministic in some iOS versions.

**How to avoid:**
- Use `NavigationLink(value:)` with `navigationDestination(for:)` (iOS 16+ pattern, available since the project targets iOS 17).
- Do not mix `NavigationLink` and `Button` in the same row.
- If the row needs secondary actions (swipe-to-delete, context menu), use `.swipeActions` and `.contextMenu` modifiers, not embedded buttons.
- For the robot list specifically: `NavigationLink(value: robot) { RobotRowView(robot: robot) }` makes the entire row tappable including empty space.

**Warning signs:**
- Row tap only works when touching text, not the leading or trailing whitespace.
- Using `NavigationLink` with a `label:` closure containing a `Button`.
- `buttonStyle(.borderless)` added as a workaround hint — indicates competing tap recognizers.

**Phase to address:**
UX phase (Robot list tappability). Simple fix but test on multiple row content configurations.

---

### Pitfall 8: Map pixel cache invalidated every poll cycle

**What goes wrong:**
The current `decompressedPixels` computed property recalculates on every access. The fix is to cache the result — but if the cache is stored on the `MapLayer` struct (a value type), the cache is copied with every struct copy. In SwiftUI, model structs are copied frequently when passed through view hierarchies. The cache becomes useless because each copy recomputes from scratch.

Additionally, if the cache is not invalidated when new map data arrives (new `MapLayer` instance from polling or SSE), the app displays stale pixels until the cache key is checked.

**How to avoid:**
- Cache decompressed pixels at the `RobotMap` level (not `MapLayer` level), keyed by the map's data hash or a version counter.
- Better: pre-compute `decompressedPixels` once when a new map arrives in `RobotManager.updateRobotMap()`, store the result as a separate `[UInt32]` array alongside the raw map data.
- Use `lazy var` only if `MapLayer` is refactored to a `class` (reference type) — `lazy` on a struct requires `mutating` access which SwiftUI does not allow on `let` bindings.
- Clear the cache by replacing the cached object entirely when new map data arrives, not by mutating in place.

**Warning signs:**
- `decompressedPixels` appears in Instruments Time Profiler on every map redraw.
- `lazy var decompressedPixels` on a struct — this will not compile or will behave unexpectedly.
- Cache stored as a `@State` variable in the view instead of in the model layer.

**Phase to address:**
Performance phase (Map caching). Extract the cache to a reference type or pre-compute in RobotManager before map rendering begins.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Leaving polling loop active alongside SSE for "safety" | Easier rollout, fallback available | Duplicate state updates, race conditions, doubled battery drain | Never — define explicit SSE-primary contract |
| Migrating only new robots to Keychain (leaving old ones in UserDefaults) | No migration risk | Two credential storage paths to maintain indefinitely | Only as a transitional step for one release cycle |
| Using `print()` for debug logging during ViewModel extraction | Faster iteration | Debug output ships to production, credentials may leak | Never in any file that handles auth data |
| `@ObservedObject` instead of `@StateObject` "just to be safe" | No apparent change in simple tests | ViewModel recreated on parent re-render, all state lost | Never for ViewModels created inside the view |
| Caching `decompressedPixels` in the view as `@State` | Works, simple | Cache tied to view lifecycle, invalidated on navigation | Never — cache belongs in the model layer |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Valetudo SSE endpoint | Opening a new `URLSession.bytes` stream without cancelling the previous one | Store Task in a property, cancel before reconnecting |
| Keychain + existing UserDefaults robots | Writing Keychain items with a key that collides with system or other app items | Use reverse-DNS prefixed service name: `"com.valetudo.robot.\(robotId)"` |
| NWBrowser + XcodeGen project.yml | Adding `NSBonjourServices` to the wrong target's Info.plist (test target instead of app target) | Verify Info.plist path in `project.yml` maps to the app target |
| os.Logger + actor-isolated code | Creating Logger inside an actor method — fine, but subsystem/category must be static strings, not computed | Declare `private let logger = Logger(subsystem: "...", category: "...")` as stored property |
| XCTest + async actor code | Using `DispatchQueue.main.async` in tests to wait for `@Published` changes | Use `await Task.yield()` or `fulfillment(of:timeout:)` with async expectations |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `decompressedPixels` recomputed per render | Dropped frames during map pan/zoom; Instruments shows hot path in map drawing | Pre-compute once on map arrival, cache as `[UInt32]` property | Every frame when map is visible |
| SSE + polling running simultaneously | Battery drain doubles; status flickers; network requests double | Strict SSE-primary state machine, disable polling on SSE connect | Immediately on first SSE connection |
| `Task` created inside `refreshRobot` without storing reference | Tasks accumulate if refresh fires faster than API responds | Store Task reference, cancel previous before creating new | When polling interval < API round-trip time (~5s on slow LAN) |
| All 254 IP scan still running alongside mDNS | 30-second scan blocks LAN segment, robot already found via mDNS | mDNS result cancels IP scan immediately | Every time user taps "Scan" |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Keychain item with `kSecAttrAccessibleAlways` | Credentials readable while device is locked | Use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for robot credentials |
| Keychain item without `ThisDeviceOnly` suffix | Credentials sync to iCloud, appear on other devices | Use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — robot hostnames are LAN-local, useless on other devices |
| Logging Authorization header with `privacy: .public` | Credentials in system log, included in sysdiagnose bundles | Never log credential values; log presence only |
| Migrating credentials without verifying Keychain write succeeded | Silent data loss, user locked out of all robots | Read-back verification before UserDefaults deletion |
| Using `kSecMatchLimit: kSecMatchLimitAll` without `kSecAttrService` filter | Reads credentials from unrelated apps sharing the same Keychain group | Always scope queries with `kSecAttrService` and `kSecAttrAccount` |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No migration progress indicator during Keychain migration | User opens app, robots appear gone, no explanation | Show one-time migration banner or progress state during first launch after update |
| Local Network permission dialog appears with no explanation | User dismisses the dialog, mDNS never works again (no re-prompt) | Trigger NWBrowser only after showing an in-app explanation screen; `NSLocalNetworkUsageDescription` must be specific |
| SSE connection loss with no visible feedback | Status stops updating silently; user thinks robot is working when it isn't | Show a subtle "reconnecting..." indicator when SSE drops; restart polling immediately as fallback |
| Notification actions (GO_HOME, LOCATE) silently do nothing | User taps action, nothing happens, trust eroded | Implement `UNUserNotificationCenterDelegate` before adding notification action UI |
| Robot row only partially tappable | Users tap empty space, nothing happens, row feels broken | Full-row `NavigationLink(value:)` with iOS 17 `navigationDestination` |

---

## "Looks Done But Isn't" Checklist

- [ ] **Keychain migration:** Verify credentials are readable after cold launch (app killed, device restarted) — Keychain accessibility class `WhenUnlockedThisDeviceOnly` requires device to be unlocked at least once after restart.
- [ ] **SSE connection:** Verify SSE Task is cancelled and polling resumes when app enters background — background URLSession streaming is restricted.
- [ ] **mDNS discovery:** Test on a real device with Location Services and Local Network permission in various states (never asked, denied, granted) — Simulator does not reproduce all states.
- [ ] **os.Logger migration:** Run a production build (not Debug) attached to Console.app and verify no credential values appear in any log entry.
- [ ] **ViewModel extraction:** Verify previews still compile — `#Preview` blocks that use `.environmentObject(RobotManager())` will break if a child view now requires a new `@StateObject` ViewModel that is not provided.
- [ ] **NavigationLink row:** Test tap response on rows with very short labels (tap target is the text width, not the row) and very long lists (dequeuing).
- [ ] **Map cache:** Profile with Instruments after 10 poll cycles — verify `decompressedPixels` appears zero times in Time Profiler if map data has not changed.
- [ ] **XCTest target:** Verify test target compiles against the app module (not a separate module) — `@testable import ValetudoApp` requires the app to compile cleanly first.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Credentials lost during Keychain migration | HIGH | No automated recovery. Ship hotfix that re-prompts credentials entry for all robots. Consider including a one-time export button before migration ships. |
| SSE Task leak causing connection accumulation | MEDIUM | Close and reopen app clears all Tasks. Fix: add explicit `sseTask?.cancel()` to RobotManager.removeRobot() and deinit. |
| mDNS silently failing (missing Info.plist key) | LOW | Add missing plist key, rebuild. No data loss. Requires App Store update. |
| @ObservedObject ViewModel recreated on re-render | MEDIUM | Change to @StateObject. If ViewModel holds async state (SSE connection), this requires reconnect logic on init. |
| Logger privacy annotation exposing credentials | HIGH | Ship new build with `privacy: .private` or remove log statement. Assess whether any sysdiagnose bundles were shared externally. |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| @StateObject vs @ObservedObject ownership | ViewModel extraction (Phase 1) | Code review checklist: every ViewModel created inside a view uses @StateObject |
| Credentials lost in Keychain migration | Security / Credentials phase | Manual test: migrate on device, kill app, restart device, verify robots still load |
| SSE Task leak + polling coexistence | SSE / Adaptive Polling phase | Instruments Network profiler: one active connection per robot during SSE, zero during background |
| NWBrowser silent failure (Info.plist) | mDNS / Network Scanner phase | Real device test with permission denied, then granted — discovery works after grant |
| os.Logger credential exposure | Logging refactor phase | Console.app review of production build; grep codebase for `privacy: .public` after migration |
| @MainActor XCTest isolation conflicts | Test coverage phase | All tests pass without actor-isolation warnings in Xcode 16 strict concurrency mode |
| NavigationLink partial tap target | UX / Robot list phase | Manual test: tap empty whitespace in robot row — navigates correctly |
| Map cache invalidated on struct copy | Performance / Map caching phase | Instruments Time Profiler: `decompressedPixels` not in hot path during 60-second map observation |

---

## Sources

- [SwiftUI's Observable macro is not a drop-in replacement for ObservableObject — Jesse Squires (2024)](https://www.jessesquires.com/blog/2024/09/09/swift-observable-macro/)
- [Migrating from ObservableObject to Observable macro — Apple Developer Documentation](https://developer.apple.com/documentation/SwiftUI/Migrating-from-the-observable-object-protocol-to-the-observable-macro)
- [TN3179: Understanding local network privacy — Apple Developer Documentation](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)
- [Request and check local network permission on iOS and visionOS — Nonstrict (2024)](https://nonstrict.eu/blog/2024/request-and-check-for-local-network-permission/)
- [iOS mDNS IP resolving issue iOS 17 — Apple Developer Forums](https://developer.apple.com/forums/thread/742545)
- [OSLogPrivacy — Apple Developer Documentation](https://developer.apple.com/documentation/os/oslogprivacy)
- [Modern logging with the OSLog framework in Swift — Donny Wals](https://www.donnywals.com/modern-logging-with-the-oslog-framework-in-swift/)
- [XCTest Meets @MainActor: How to Fix Strict Concurrency Warnings — Quality Coding](https://qualitycoding.org/xctest-mainactor/)
- [URLSession implicit cancellation — Swift Forums](https://forums.swift.org/t/urlsession-implicit-cancellation-using-async-await-helper/69230)
- [Beware UserDefaults: a tale of hard to find bugs and lost data — Christian Selig (2024)](https://christianselig.com/2024/10/beware-userdefaults/)
- [iOS and Keychain Migration and Data Protection — Use Your Loaf](https://useyourloaf.com/blog/ios-and-keychain-migration-and-data-protection-part-3/)
- [Multiple buttons in SwiftUI List rows — Nil Coalescing](https://nilcoalescing.com/blog/MultipleButtonsInListRows/)
- [Reducing Memory Footprint When Using UIImage — Swift Senpai](https://swiftsenpai.com/development/reduce-uiimage-memory-footprint/)
- ValetudiOS codebase analysis: `.planning/codebase/CONCERNS.md` (2026-03-27)

---
*Pitfalls research for: ValetudiOS v1.2.0 — iOS/SwiftUI refactoring + feature additions*
*Researched: 2026-03-27*
