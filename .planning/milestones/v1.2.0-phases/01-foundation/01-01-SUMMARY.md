---
phase: 01-foundation
plan: 01
subsystem: security/credentials
tags: [keychain, security, migration, credentials, swift]
dependency_graph:
  requires: []
  provides: [KeychainStore, RobotConfig-CodingKeys-Exclusion, Keychain-Migration]
  affects: [ValetudoAPI, RobotManager, SettingsView]
tech_stack:
  added: [Security framework (SecItem API)]
  patterns: [Keychain CRUD wrapper, lazy migration with read-back verification]
key_files:
  created:
    - ValetudoApp/ValetudoApp/Services/KeychainStore.swift
  modified:
    - ValetudoApp/ValetudoApp/Models/RobotConfig.swift
    - ValetudoApp/ValetudoApp/Services/RobotManager.swift
    - ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift
    - ValetudoApp/ValetudoApp/Views/SettingsView.swift
    - ValetudoApp/ValetudoApp.xcodeproj/project.pbxproj
decisions:
  - "KeychainStore uses kSecAttrAccessibleWhenUnlockedThisDeviceOnly for device-only credential storage"
  - "RobotConfig.CodingKeys excludes password so it is never serialized to UserDefaults JSON"
  - "Migration uses read-back verification before clearing password from UserDefaults blob"
  - "ValetudoAPI reads password from KeychainStore at request time, not from config struct"
  - "EditRobotView loads password from Keychain on init so users can see/edit existing passwords"
metrics:
  duration: ~15 minutes
  completed: 2026-03-27
  tasks_completed: 2
  files_modified: 6
---

# Phase 01 Plan 01: Keychain-Migration Summary

**One-liner:** SecItem-based KeychainStore with lazy UserDefaults-to-Keychain migration using read-back verification, password excluded from RobotConfig Codable encoding.

## What Was Built

Implemented secure credential storage for Valetudo robot passwords using the iOS Keychain, migrating away from plaintext storage in UserDefaults JSON.

### KeychainStore Service (`KeychainStore.swift`)
Static utility struct wrapping `SecItemCopyMatching`, `SecItemAdd`, `SecItemDelete` with:
- Service identifier: `com.valetudio.robot.password`
- Accessibility: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- Account key: robot UUID string
- Three operations: `password(for:)`, `save(password:for:)`, `delete(for:)`

### RobotConfig CodingKeys Exclusion
Added `private enum CodingKeys` listing all properties except `password`. Updated `init(from decoder:)` to set `password = nil` — passwords are never decoded from UserDefaults JSON. The regular `init(...)` still accepts password in memory for form submission flows.

### Lazy Migration in RobotManager.loadRobots()
On first load after app update:
1. Decode robots from UserDefaults (password field will be nil due to new CodingKeys)
2. For each robot, check if Keychain already has password (skip if migrated)
3. If legacy password exists in decoded config, save to Keychain
4. Read-back verification: only clear password from blob if Keychain confirms it was saved
5. Re-save robots to UserDefaults without passwords if any migration occurred

### ValetudoAPI Credential Reads
Both `request<T>()` and `requestVoid()` now call `KeychainStore.password(for: config.id)` instead of reading `config.password`. Auth header is only set when both username is non-empty AND Keychain has a password.

### View Updates
- `EditRobotView.init(robot:)` loads password from Keychain for display in the secure field
- `addRobot` and `updateRobot` in RobotManager save password to Keychain when provided
- `removeRobot` deletes the Keychain entry before removing the robot

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| kSecAttrAccessibleWhenUnlockedThisDeviceOnly | Maximum security: no iCloud sync, only accessible when device unlocked |
| CodingKeys exclusion over encode(to:) override | Simpler, prevents accidental password serialization in both encode AND decode |
| Read-back verification before clearing UserDefaults | Prevents data loss if Keychain write fails silently |
| ValetudoAPI reads from Keychain at request time | No need to thread password through config struct after initial add/edit |
| Project.pbxproj manual update | XcodeGen not available at runtime; added KeychainStore.swift entries manually |

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | 387274e | KeychainStore service + RobotConfig CodingKeys exclusion |
| Task 2 | cb2429d | Migration, API/views credential update, pbxproj registration |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added KeychainStore.swift to project.pbxproj manually**
- **Found during:** Task 2 build verification
- **Issue:** XcodeGen auto-discovery applies during `xcodegen generate` run, not at xcodebuild time. The existing project.pbxproj did not include KeychainStore.swift, causing `cannot find 'KeychainStore' in scope` errors.
- **Fix:** Added PBXFileReference, PBXBuildFile, PBXGroup child, and PBXSourcesBuildPhase entry for KeychainStore.swift in project.pbxproj.
- **Files modified:** `ValetudoApp/ValetudoApp.xcodeproj/project.pbxproj`
- **Commit:** cb2429d

## Known Stubs

None — all credential paths are fully wired to the Keychain.

## Self-Check: PASSED

Files verified:
- `ValetudoApp/ValetudoApp/Services/KeychainStore.swift` — FOUND
- `ValetudoApp/ValetudoApp/Models/RobotConfig.swift` — FOUND (contains CodingKeys)
- `ValetudoApp/ValetudoApp/Services/RobotManager.swift` — FOUND (contains migration)
- `ValetudoApp/ValetudoApp/Services/ValetudoAPI.swift` — FOUND (uses KeychainStore)
- `ValetudoApp/ValetudoApp/Views/SettingsView.swift` — FOUND (loads from Keychain)

Commits verified:
- 387274e — FOUND
- cb2429d — FOUND

Build: SUCCEEDED
