# Coding Conventions

**Analysis Date:** 2026-03-28

## Naming Patterns

**Files:**
- PascalCase for all files: `RobotDetailViewModel.swift`, `ConsumableTests.swift`, `ValetudoAPI.swift`
- Test files suffix with `Tests`: `TimerTests.swift`, `KeychainStoreTests.swift`, `MapViewModelTests.swift`
- Group-related files by feature: Models in `Models/`, ViewModels in `ViewModels/`, Views in `Views/`, Services in `Services/`

**Functions:**
- camelCase for function names: `loadSegments()`, `refreshData()`, `utcToLocal()`, `decompressedPixels()`
- Private functions prefixed with `private func`: `loadSegments()`, `makeConsumable()`
- Async functions explicitly marked `async`: `loadData() async`, `refreshData() async`
- Test functions: `test{Behavior}` pattern: `testLocalToUtcRoundTrip()`, `testRemainingPercentWithPercentUnit()`, `testIconColorGreen()`

**Variables:**
- camelCase for all variables: `segments`, `consumables`, `isLoading`, `fanSpeedPresets`
- Published state properties marked with `@Published`: `@Published var segments: [Segment] = []`
- Private backing fields use underscore prefix: `_sseSession`, `_cache`
- Boolean properties use `is`, `has`, `can` prefixes: `isLoading`, `hasCleanRoute`, `canExecuteAction`
- Constant collection properties are arrays: `segments: [Segment]`, `consumables: [Consumable]`
- Test helper variables track state: `private var testUUIDs: [UUID] = []`

**Types:**
- PascalCase for all types: `RobotDetailViewModel`, `ValetudoAPI`, `Consumable`, `RobotConfig`
- Enums use PascalCase cases: `case invalidURL`, `case networkError`
- Protocol names end in `-able` or `-ible`: `Codable`, `Identifiable`, `Equatable`, `Hashable`

## Code Style

**Formatting:**
- 4-space indentation (implicit, follows Xcode default)
- Blank line between MARK sections: `// MARK: - Identity`, `// MARK: - Data state`
- Trailing closures for single-expression blocks
- Structs preferred over classes (except caching classes like `MapLayerCache`)

**Linting:**
- No external linter detected (SwiftLint/SwiftFormat config absent)
- Follows Swift standard formatting conventions
- Type-safe with explicit type annotations where not inferred

## Import Organization

**Order:**
1. Foundation framework first: `import Foundation`
2. UI frameworks: `import SwiftUI`
3. System frameworks: `import os` (for logging)
4. Test imports: `import XCTest` followed by `@testable import ValetudoApp`

**Path Aliases:**
- No aliased imports detected
- All types accessed by module name: `Logger()`, `URLSession()`, `JSONDecoder()`

## Error Handling

**Patterns:**
- Enum-based error types with `LocalizedError` conformance:
  ```swift
  enum APIError: LocalizedError {
      case invalidURL
      case networkError(Error)
      case httpError(Int)
  }
  ```
- Errors use `throw` in `async` functions: `throw APIError.invalidURL`
- Error handling via `do/catch` blocks in data loading functions
- Logger captures errors with `logger.error()`: `logger.error("Failed to load segments: \(error, privacy: .public)")`

## Logging

**Framework:** `os.Logger` (Apple's native logging via OS log subsystem)

**Patterns:**
- Create logger per class/struct in property: `let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "ViewModelName")`
- Use appropriate log levels:
  - `logger.error()` for failures: `logger.error("Failed to load segments: ...")`
  - `logger.debug()` for detailed info (if needed)
- Always use `privacy: .public` for sanitizing sensitive data in logs: `\(error, privacy: .public)`
- Logger instances per view model/service: `RobotDetailViewModel`, `ValetudoAPI`, `RobotSettingsViewModel`

## Comments

**When to Comment:**
- Complex algorithm explanations use triple-slash `///` docs
- Section grouping uses `// MARK: - SectionName`
- Algorithm intent documented: "Cache is naturally invalidated when new map data arrives"
- Why-focused, not what-focused: explain intent not code behavior

**JSDoc/TSDoc:**
- Use triple-slash `///` for method documentation: `/// Converts UTC time to local time`
- Document assumptions: "Using a class (reference type) allows caching on structs passed as let in SwiftUI Canvas closures"
- Keep docs concise, one or two sentences
- Test assertions documented: `/// Round-trip property: utcToLocal then localToUTC must return the original values.`

## Function Design

**Size:**
- Short functions preferred (visible on one screen)
- Private helper functions for complex logic: `loadSegments()`, `loadConsumables()` called from `loadData()`

**Parameters:**
- Explicit labeled parameters: `makeConsumable(type:subType:value:unit:)`
- Guard early with `guard let` to fail fast
- Use tuples for multiple return values: `(hour: Int, minute: Int)`

**Return Values:**
- Explicit return type annotations
- Void for side-effect operations: `func loadData() async`
- Optional for nullable results: `var status: RobotStatus?`
- Array for collections: `var segments: [Segment] = []`

## Module Design

**Exports:**
- Public by default unless prefixed `private`
- Explicit access control: `private func`, `fileprivate func`, no `internal` keyword
- Nested types (like error enums) defined at top of file

**Barrel Files:**
- No barrel/index files detected
- Direct imports from feature modules: `import ValetudoApp`
- Test target uses `@testable import ValetudoApp` for internal access

**View Model Pattern:**
- `@MainActor` decorator on all ViewModels (UI state isolation): `@MainActor final class RobotDetailViewModel`
- `final` class modifier prevents accidental subclassing
- Published properties for SwiftUI binding: `@Published var segments: [Segment] = []`
- Computed properties for derived state: `var isCleaning: Bool { status?.statusValue?.lowercased() == "cleaning" }`
- Initializer accepts dependencies: `init(robot: RobotConfig, robotManager: RobotManager)`

---

*Convention analysis: 2026-03-28*
