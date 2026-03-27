---
phase: 03
slug: api-completeness
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-27
---

# Phase 03 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | xcodebuild (no XCTest target yet — deferred to Phase 4) |
| **Config file** | ValetudoApp/ValetudoApp.xcodeproj |
| **Quick run command** | `xcodebuild build -project ValetudoApp/ValetudoApp.xcodeproj -target ValetudoApp -quiet 2>&1 \| tail -5` |
| **Full suite command** | `xcodebuild build -project ValetudoApp/ValetudoApp.xcodeproj -target ValetudoApp 2>&1 \| grep -E "error:\|BUILD"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick build command
- **After every plan wave:** Run full build command
- **Before `/gsd:verify-work`:** Full build must succeed
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | API-01, API-02 | build | xcodebuild build | ✅ | ⬜ pending |
| 03-01-02 | 01 | 1 | API-03 | build+grep | xcodebuild build + grep acceptance | ✅ | ⬜ pending |
| 03-02-01 | 02 | 1 | API-04, UX-04 | build | xcodebuild build | ✅ | ⬜ pending |
| 03-02-02 | 02 | 1 | UX-03 | build+grep | xcodebuild build + grep acceptance | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No test framework setup needed (XCTest deferred to Phase 4).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Map snapshot restore works on real robot | API-01 | Requires Valetudo API on real device | 1. Open Settings, 2. Tap "Snapshots", 3. Select snapshot, 4. Tap Restore |
| Map reset accept/reject triggers robot action | API-02 | Requires actual pending map change | 1. Run mapping, 2. Open Settings, 3. Tap Accept/Reject |
| Notification GO_HOME sends robot home | UX-03 | Requires push notification interaction | 1. Trigger error notification, 2. Tap GO_HOME action |
| Notification LOCATE makes robot beep | UX-03 | Requires push notification interaction | 1. Trigger error notification, 2. Tap LOCATE action |
| Obstacle photos display from AI camera | API-04 | Requires robot with AI obstacle detection | 1. Open Events, 2. Tap event with obstacle, 3. View photo |
| Events show real DustBinFull/MopReminder | UX-04 | Requires robot to generate events | 1. Trigger event on robot, 2. Check Events view |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
