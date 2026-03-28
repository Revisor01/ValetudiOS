# Phase 10: Safety Fixes - Context

**Gathered:** 2026-03-28
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase — discuss skipped)

<domain>
## Phase Boundary

Kein Force-Unwrap gefährdet die App-Stabilität, Keychain-Fehler werden sichtbar geloggt, und alle Magic-Strings sind zentralisiert. Betrifft 3 Dateien: SettingsView (Force-Unwrap), KeychainStore (Fehlerbehandlung), und eine neue Constants-Datei für URLs/ProductIDs.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — pure infrastructure phase.

Specific findings from audit:
- SettingsView.swift:188 has `robot.username!` force-unwrap after nil-check → replace with `!(robot.username?.isEmpty ?? true)`
- KeychainStore.swift:28,46 ignores SecItemDelete return values → check status, log with os.Logger
- Hardcoded GitHub API URL duplicated in RobotDetailViewModel.swift:277 and RobotSettingsView.swift:1455
- StoreKit product IDs hardcoded in SupportManager.swift

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- os.Logger already set up in all ViewModels and Services (completed in Phase 9)
- Pattern: `private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ValetudiOS", category: "TypeName")`

### Established Patterns
- Constants: No existing constants file — this will be new
- KeychainStore: Uses kSecAttrAccessibleWhenUnlockedThisDeviceOnly

### Integration Points
- Constants file needs to be referenced from: RobotDetailViewModel, RobotSettingsView, SupportManager
- KeychainStore already has Logger from Phase 1 foundation

</code_context>

<specifics>
## Specific Ideas

No specific requirements — infrastructure phase. Follow existing patterns.

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
