---
phase: 2
slug: network-layer
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-27
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (no test target yet — Phase 4) |
| **Config file** | none |
| **Quick run command** | `xcodebuild build -scheme ValetudoApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` |
| **Full suite command** | same as quick (no test target yet) |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Build succeeds
- **After every plan wave:** Build succeeds + manual smoke test
- **Before `/gsd:verify-work`:** Build succeeds + all manual verifications pass
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | NET-01 | manual | SSE connection active | N/A | pending |
| TBD | TBD | TBD | NET-02 | manual | mDNS finds robot | N/A | pending |
| TBD | TBD | TBD | DEBT-03 | build | grep decompressedPixels cache | N/A | pending |

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| SSE real-time updates | NET-01 | Requires running Valetudo instance | 1. Connect to robot 2. Start cleaning 3. Verify status updates without 5s delay |
| mDNS discovery | NET-02 | Requires robot on LAN with mDNS | 1. Open AddRobotView 2. Verify robot appears via Bonjour 3. Verify IP fallback after 3s |
| Map rendering performance | DEBT-03 | Visual/perceptual check | 1. Open MapView 2. Pan/zoom 3. Verify smoother rendering |

---

## Validation Sign-Off

- [ ] All tasks have build-verify
- [ ] Sampling continuity: build check after every commit
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
