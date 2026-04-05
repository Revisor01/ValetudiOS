---
phase: 1
slug: foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-27
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (no test target exists yet — created in Phase 4) |
| **Config file** | none — no test target in current project |
| **Quick run command** | `xcodebuild test -scheme ValetudoApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` |
| **Full suite command** | same as quick (no test target yet) |
| **Estimated runtime** | N/A (no tests in Phase 1) |

---

## Sampling Rate

- **After every task commit:** Build succeeds (`xcodebuild build`)
- **After every plan wave:** Build succeeds + manual smoke test
- **Before `/gsd:verify-work`:** Build succeeds + all manual verifications pass
- **Max feedback latency:** ~30 seconds (build time)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | NET-03 | manual | Keychain migration verify | N/A | ⬜ pending |
| TBD | TBD | TBD | UX-02 | manual | Trigger error, verify alert | N/A | ⬜ pending |
| TBD | TBD | TBD | UX-01 | manual | Tap robot row edge | N/A | ⬜ pending |
| TBD | TBD | TBD | DEBT-01 | build | `grep -r "print(" ValetudoApp/` | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- Existing infrastructure covers all phase requirements — no test framework needed for Phase 1.
- Phase 4 (DEBT-04) establishes XCTest target.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Keychain migration preserves credentials | NET-03 | Requires device/simulator with existing UserDefaults data | 1. Add robot with credentials 2. Rebuild with Keychain code 3. Verify robot still connects |
| Error alert shown on API failure | UX-02 | Requires network failure simulation | 1. Disconnect robot from network 2. Trigger action 3. Verify alert appears |
| Full robot row tappable | UX-01 | UI interaction test | 1. Tap far-right edge of robot row 2. Verify navigation to detail view |
| No print() in production code | DEBT-01 | Grep-verifiable | `grep -rn "print(" ValetudoApp/ValetudoApp/ --include="*.swift"` returns 0 matches |

---

## Validation Sign-Off

- [ ] All tasks have build-verify or manual verification steps
- [ ] Sampling continuity: build check after every commit
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (build time)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
