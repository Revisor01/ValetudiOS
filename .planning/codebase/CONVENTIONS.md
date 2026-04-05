# Coding Conventions

**Analysis Date:** 2026-04-04

## Naming Patterns

**Files:**
- PascalCase for all Swift files matching their primary type/class name
  - Example: `RobotDetailViewModel.swift`, `MapGeometry.swift`, `ValetudoAPI.swift`
- Subdirectories organized by layer (Views, ViewModels, Models, Services, Utilities, Helpers, Intents)
- Test files match source files with "Tests" suffix
  - Example: `MapGeometryTests.swift` tests `MapGeometry.swift`

**Functions:**
- camelCase for function and method names
- Descriptive names capturing intent and return type
- Private helper functions prefixed with `private func`
  - Example: `makeRobotConfig()`, `makeConsumable(type:subType:value:unit:)` in tests
- Async functions with clear operation names (e.g., `checkForUpdates()`, `startDownload()`, `loadRobots()`)

**Variables:**
- camelCase for properties and local variables
- Clear semantic names avoiding abbreviations
  - Example: `selectedSegments`, `fanSpeedPresets`, `isLoading`, `hasManualControl`
- Private properties prefixed with underscore when needed for implementation details
  - Example: `_sseSession`, `_sessionDelegate`, `_retryCount`
- Observable properties marked with `@MainActor` when managing UI state
- Ignore non-observable internal state with `@ObservationIgnored`

**Types:**
- PascalCase for structs, classes, enums, protocols
  - Example: `RobotConfig`, `MapLayer`, `UpdateService`, `ErrorRouter`
- Enum cases follow type convention for wrapper types, lowercase for status values
  - Example: `enum StatusValue: String { case idle, cleaning, paused }`
  - Example: `enum BasicAction: String, Codable { case start, stop, pause, home }`
- Extension naming uses extended type + purpose
  - Example: `extension Consumable { var displayName: String }`
  - Example: `extension String { var localizedConsumableType: String }`

## Code Style

**Formatting:**
- No explicit formatter configuration found; follows Xcode conventions
- 4-space indentation (standard Swift)
- Opening braces on same line for functions/classes
- Trailing closures for single argument functions
- Explicit newlines before new logical sections

**Linting:**
- No `.swiftlint.yml` or linting configuration detected
- Code relies on Xcode warnings and manual review
- Project uses Swift 5.9 (set in `project.yml`)
- Deployment target: iOS 17.0

## Import Organization

**Order:**
1. Foundation (system frameworks)
2. SwiftUI and UI frameworks
3. Observation/concurrency frameworks
4. Logging (os)
5. Custom types and services (no explicit imports, same module)

**Examples:**
```swift
import BackgroundTasks  // System frameworks first
import SwiftUI          // UI frameworks
import UserNotifications  // Additional system
import os              // Logging
import Observation     // State management

import Foundation      // Codable support
import Foundation
import SwiftUI
import os
import Observation
```

**Path Aliases:**
- No path aliases configured in project
- Relative imports within module using `@testable import ValetudoApp`

## Error Handling

**Patterns:**
- Typed error enums extending `LocalizedError` for user-facing errors
  - Example: `enum APIError: LocalizedError` with `errorDescription` property
- Throws syntax for functions that may fail
  - Example: `func request<T: Decodable>(...) async throws -> T`
- Try-catch for recovery or fallback behavior
- Guard statements with early returns for preconditions
  - Example: `guard let baseURL = config.baseURL, let url = URL(...) else { throw APIError.invalidURL }`
- Error routing through `ErrorRouter` for UI display in `ValetudoApp.swift`
- Task wrapping with error suppression for non-critical background tasks
  - Example: `Task { await refreshRobot(config.id) }` without try-catch

**HTTP Error Handling:**
```swift
guard (200...299).contains(httpResponse.statusCode) else {
    throw APIError.httpError(httpResponse.statusCode)
}
```

**Decoding Error Handling:**
```swift
do {
    let result = try decoder.decode(T.self, from: data)
    return result
} catch {
    throw APIError.decodingError(error)
}
```

## Logging

**Framework:** `os.Logger` (Apple's unified logging system)

**Pattern:**
```swift
private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "ComponentName")
```

**Usage:**
- Debug logs for request details and state changes
- logger.debug("Request: \(method) \(url.path, privacy: .public)")
- Privacy levels: `.public` for URLs, `.private` for sensitive data
- Logs in:
  - `ValetudoAPI.swift` - request/response logging
  - `RobotDetailViewModel.swift` - state changes
  - View files - lifecycle and user actions
  - Services (RobotManager, UpdateService) - operational events

## Comments

**When to Comment:**
- Explain WHY, not WHAT (code shows what, comments explain intent)
- Algorithm decisions that aren't obvious
- Workarounds or hacks with justification
- Complex coordinate transforms or calculations
- State machine transitions

**Examples from codebase:**
```swift
// BGTask-Handler registrieren — MUSS in didFinishLaunchingWithOptions passieren
BGTaskScheduler.shared.register(...)

// Initiales Scheduling (fuer frische Installationen die noch nie in den Hintergrund gingen)
BackgroundMonitorService.shared.scheduleBackgroundRefresh()

// completionHandler sofort aufrufen — Task laeuft im Hintergrund
completionHandler()
```

**JSDoc/TSDoc:**
- Not used; Swift prefers doc comments with `///` sparingly
- Function purposes documented through clear naming and parameter names
- Complex functions include one-line summary
  - Example: `/// Converts a screen coordinate (accounting for pinch/pan gesture state) to map canvas coordinates.`

## Function Design

**Size:** 
- Most functions 10-40 lines
- Private helpers kept compact (3-15 lines)
- Async functions may be longer due to state management
- Example: `calculateMapParams()` is 30 lines with clear sections

**Parameters:**
- Named parameters for clarity over positional
- Default values for optional parameters (e.g., `padding: CGFloat = 20`)
- No parameter abbreviations; full descriptive names
- Private helper functions accept minimal parameters
  - Example: `makeConsumable(type:subType:value:unit:)` factory function

**Return Values:**
- Explicit return types for public functions
- Single responsibility: one main output per function
- Optional returns (`-> T?`) for operations that may fail gracefully
- Typed errors for operations that must fail (async throws)
- Void return for state mutations (e.g., `func addRobot(_:)`, `func clearRoomSelection(for:)`)

## Module Design

**Exports:**
- No explicit public/private declarations in main module (single app target)
- Test target uses `@testable import ValetudoApp` for private access
- All public types defined at file scope, no nested types except helpers

**Barrel Files:**
- No barrel files or index patterns found
- Each file exports one primary type plus related helpers
  - Example: `RobotState.swift` exports 60+ related types in MARK sections

**Organization Within Files:**
- MARK comments divide logical sections
- Hierarchical structure: main type first, then helpers, then extensions
- Example structure from `RobotState.swift`:
  ```swift
  // MARK: - Robot Info
  struct RobotInfo: Codable { ... }
  
  // MARK: - Robot State
  struct RobotStateResponse: Codable { ... }
  
  // MARK: - Attributes
  struct RobotAttribute: Codable { ... }
  ```

**Observation Pattern:**
- Classes managing state use `@Observable` macro from Observation framework
- Combine with `@MainActor` for thread-safe UI updates
  - Example: `@MainActor @Observable final class RobotDetailViewModel`
- Observable properties automatically notify SwiftUI of changes
- Non-observable properties marked with `@ObservationIgnored` for implementation details
  - Example: `@ObservationIgnored private var statsPollingTask: Task<Void, Never>?`

## Memory and Resource Management

**Property Observers:**
- Use `didSet` for side effects when properties change
  - Example: `var selectedSegments: [String] = [] { didSet { robotManager.roomSelections[robot.id] = selectedSegments } }`
  - Example: `var activeRobotId: UUID? { didSet { if oldValue != activeRobotId { restartRefreshing() } } }`
- Explicit state synchronization between ViewModels and central RobotManager

**Task Lifecycle:**
- Long-running tasks stored in properties for cancellation
  - Example: `@ObservationIgnored private var refreshTask: Task<Void, Never>?`
- Cleanup in `deinit`: `deinit { refreshTask?.cancel() }`
- Background Tasks managed through AppDelegate with BGTaskScheduler

## String Handling

**Localization:**
- All user-facing strings use `String(localized: "key.name")`
- Localization keys follow dot notation: `status.idle`, `consumable.brush`, `settings.auto_empty_interval`
- No hardcoded English strings in production code

**String Manipulation:**
- `.lowercased()` for case-insensitive comparison
- `.trimmingCharacters(in: .whitespaces)` for input validation
- `.replacingOccurrences(of:with:)` for formatting (e.g., underscore to space)

---

*Convention analysis: 2026-04-04*
