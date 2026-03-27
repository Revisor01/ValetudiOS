# Phase 1: Foundation - Research

**Researched:** 2026-03-27
**Domain:** iOS Security (Keychain), SwiftUI Error Presentation, os.Logger, NavigationLink
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Error-Feedback (UX-02)**
- D-01: Fehler werden dem Benutzer via SwiftUI `.alert` Modifier angezeigt — nativer iOS-Pattern, konsistent mit System-Dialogen
- D-02: Ein zentraler `ErrorRouter` (ObservableObject) wird als `@EnvironmentObject` in die View-Hierarchie injiziert. Views subscriben und zeigen `.alert` an wenn `ErrorRouter.currentError` gesetzt wird
- D-03: ErrorRouter unterstützt optionale Retry-Action (Closure), damit der Alert einen "Erneut versuchen"-Button anbieten kann

**Keychain-Migration (NET-03)**
- D-04: Migration von UserDefaults zu Keychain erfolgt lazy beim ersten Robot-Zugriff (nicht global beim App-Start)
- D-05: Migrationsstrategie: 1) Credentials aus UserDefaults lesen, 2) In Keychain schreiben, 3) Aus Keychain zurücklesen (Verify-back), 4) Nur bei erfolgreichem Verify aus UserDefaults löschen
- D-06: Keychain-Zugriffsklasse: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — Credentials nur auf diesem Gerät, nur wenn entsperrt
- D-07: Ein `KeychainStore` Service kapselt alle SecItem-Operationen. Key pro Robot: `robotId.uuidString`

**Strukturiertes Logging (DEBT-01)**
- D-08: Alle `print()` werden durch `os.Logger` ersetzt. Logger-Kategorien pro Service-Schicht: `API`, `RobotManager`, `NetworkScanner`, `Notifications`, `Views`
- D-09: Subsystem ist `Bundle.main.bundleIdentifier`. Debug-Level-Nachrichten erscheinen nicht in Production-Logs — kein `#if DEBUG` nötig
- D-10: Sensitivity-Audit vor Migration: Jeder bestehende print()-Aufruf wird auf Credentials/sensitive Daten geprüft. Sensitive Werte verwenden `.private` Privacy-Annotation

**Robot-Zeile klickbar (UX-01)**
- D-11: Robot-Zeile in der Liste wird vollständig klickbar durch NavigationLink wrapping des gesamten Row-Contents (nicht nur Text)

### Claude's Discretion
- Reihenfolge der Implementierung innerhalb der Phase (welche Task zuerst)
- Konkrete os.Logger-Instanziierung (statische Properties vs. lokale Instanzen)
- Exakter ErrorRouter-API-Design (Property-Namen, Methoden-Signaturen)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NET-03 | Credentials werden im iOS Keychain gespeichert (Migration aus UserDefaults) | KeychainStore-Pattern mit SecItem, lazy Migration in `loadRobots()`, Read-back-Verifikation vor UserDefaults-Delete |
| UX-02 | Benutzer sieht Fehlermeldungen bei fehlgeschlagenen Aktionen (statt stiller Fehler) | ErrorRouter als ObservableObject + @EnvironmentObject, `.alert`-Modifier-Pattern, APIError ist bereits `LocalizedError` |
| UX-01 | Robot-Zeile in der Liste ist vollständig klickbar | `NavigationLink(value:)` + `navigationDestination(for:)` iOS 16+ Pattern; bestehende Button/NavigationLink-Mischung durch reines NavigationLink ersetzen |
| DEBT-01 | Alle print()-Aufrufe durch os.Logger ersetzt, Debug-Output nur in DEBUG-Builds | 6 print()-Aufrufe in Service-Layer identifiziert; os.Logger braucht kein `#if DEBUG` da `.debug`-Level in Production-Builds nicht in System Log erscheint |
</phase_requirements>

---

## Summary

Phase 1 liefert vier unabhängige, klar abgegrenzte Verbesserungen: sicheren Credential-Speicher (Keychain), sichtbares Fehler-Feedback (ErrorRouter), strukturiertes Logging (os.Logger) und eine vollständig klickbare Robot-Zeile. Alle vier Bereiche sind gut verstandene iOS-Patterns ohne externe Abhängigkeiten.

Die Keychain-Migration ist der risikoreichste Teil. `RobotConfig` speichert `username` und `password` derzeit direkt als JSON in UserDefaults via Codable-Encoding in `saveRobots()`. Die Migration muss verlustfrei sein: Read-back-Verifikation vor dem Delete aus UserDefaults ist Pflicht. Der ErrorRouter ist konzeptionell einfach — `APIError` ist bereits `LocalizedError` mit `errorDescription`, die Infrastruktur ist fast fertig. Logging ist mechanisch: 6 `print()`-Aufrufe in den Service-Dateien, ein paar weitere in Views — alle können 1:1 durch `logger.debug()` / `logger.error()` ersetzt werden. Die NavigationLink-Änderung ist eine chirurgische Einzeiler-Änderung in `RobotListView`.

**Primary recommendation:** Reihenfolge: 1) KeychainStore + Migration (höchstes Risiko, isolierbar), 2) ErrorRouter (Infrastruktur für alle nachfolgenden Views), 3) os.Logger (mechanisch, keine Abhängigkeiten), 4) NavigationLink Fix (einfachste Änderung).

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Security.framework | System | SecItem Keychain APIs | Apple-eigene Framework, keine Alternative für iOS Keychain |
| os.framework (os.Logger) | System, iOS 14+ | Strukturiertes Logging | Apple-Standard seit WWDC 2020, ersetzt print() und os_log() |
| SwiftUI | System, iOS 17+ | Alert-Presentation via `.alert` Modifier | Nativer iOS-Pattern, konsistent mit System-Dialogen |
| Foundation | System | Codable, UserDefaults, UUID | Basis-Framework |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| AppIntents | System | `RobotIntents.swift` liest UserDefaults direkt — muss auf KeychainStore umgestellt werden | Nach KeychainStore-Implementierung |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SecItem direkt | KeychainAccess (3rd party) | Keine externen Dependencies laut Codebase-Analyse — SecItem direkt ist korrekt |
| os.Logger | print() | print() hat keine Privacy-Kontrolle, erscheint in Production |
| NavigationLink(value:) | Button + programmatic navigation | NavigationLink(value:) ist iOS 16+ Standard, sauberer als State-basierte Navigation |

**Installation:** Keine neuen Packages — alles System-Frameworks.

---

## Architecture Patterns

### Recommended Project Structure (Phase 1 Additions)
```
ValetudoApp/ValetudoApp/
├── Services/
│   ├── KeychainStore.swift        # NEU: SecItem-Wrapper, statische Methoden
│   ├── RobotManager.swift         # MODIFIZIERT: loadRobots() triggert Migration
│   ├── ValetudoAPI.swift          # MODIFIZIERT: print() -> os.Logger
│   ├── NetworkScanner.swift       # MODIFIZIERT: print() -> os.Logger
│   └── NotificationService.swift  # MODIFIZIERT: print() -> os.Logger
├── Helpers/
│   └── ErrorRouter.swift          # NEU: ObservableObject + ViewModifier
├── Views/
│   └── RobotListView.swift        # MODIFIZIERT: Button -> NavigationLink(value:)
├── ValetudoApp.swift              # MODIFIZIERT: ErrorRouter als @EnvironmentObject
└── ContentView.swift              # MODIFIZIERT: ErrorRouter als @EnvironmentObject
```

### Pattern 1: KeychainStore als statischer Service

**Was:** `KeychainStore` ist ein `struct` mit ausschliesslich statischen Methoden. Kein `ObservableObject`, kein Zustand. Lese/Schreib-Operationen via SecItem-APIs.

**Wann verwenden:** Überall wo Credentials gelesen oder geschrieben werden: `RobotManager.loadRobots()`, `ValetudoAPI.request()`, `RobotIntents`.

**Keychain-Namensgebung (KRITISCH):** Jeder Keychain-Eintrag braucht einen `kSecAttrService`-Wert als Namespace. Ohne diesen können Keychain-Queries unbeabsichtigt Einträge anderer Apps oder des Systems treffen.

```swift
// Services/KeychainStore.swift
import Foundation
import Security

struct KeychainStore {
    private static let service = "com.valetudio.robot.password"

    /// Liest Passwort aus Keychain. Migriert von UserDefaults bei erstem Zugriff.
    static func password(for robotId: UUID) -> String? {
        // 1. Keychain prüfen
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: robotId.uuidString,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }

        // 2. Legacy: Migration aus UserDefaults
        // WICHTIG: Alter UserDefaults-Key muss dem tatsächlichen Speicherschlüssel in saveRobots() entsprechen.
        // Aktuell speichert saveRobots() ALLE RobotConfig-Felder via JSONEncoder (Codable).
        // Der Passwort-Key existiert nicht isoliert — Passwort steckt im Robot-JSON-Blob.
        // Daher: Migration liest password aus RobotConfig-Decoded-Object, nicht direkt.
        // Siehe "Migration Strategy Note" unten.
        return nil
    }

    /// Speichert Passwort in Keychain.
    @discardableResult
    static func save(password: String, for robotId: UUID) -> Bool {
        let data = Data(password.utf8)
        // Delete first to handle update case
        let deleteQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: robotId.uuidString
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: robotId.uuidString,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    /// Löscht Credentials für einen Robot (z.B. bei Robot-Entfernung).
    static func delete(for robotId: UUID) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: robotId.uuidString
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

**Migration Strategy Note — WICHTIG:**

Das aktuelle `saveRobots()` in `RobotManager` speichert das gesamte `[RobotConfig]`-Array als einen einzigen JSON-Blob unter dem Key `"valetudo_robots"`. Das Password existiert NICHT als isolierter UserDefaults-Key pro Robot. Die Migration muss daher auf dem JSON-Blob operieren:

```swift
// In RobotManager.loadRobots() — Migrations-Hook
private func loadRobots() {
    guard let data = UserDefaults.standard.data(forKey: storageKey),
          let decoded = try? JSONDecoder().decode([RobotConfig].self, from: data) else { return }

    robots = decoded
    var needsSave = false

    for robot in robots {
        // Prüfen ob Keychain bereits Eintrag hat
        if KeychainStore.password(for: robot.id) == nil,
           let legacyPassword = robot.password, !legacyPassword.isEmpty {
            // Schreiben in Keychain
            let saved = KeychainStore.save(password: legacyPassword, for: robot.id)
            // Read-back-Verifikation (D-05)
            if saved, KeychainStore.password(for: robot.id) != nil {
                // Erst NACH erfolgreicher Verifikation: password aus Config entfernen
                // robots[index].password = nil -- nach Index-Lookup
                needsSave = true
            }
        }
        apis[robot.id] = ValetudoAPI(config: robot)
    }

    if needsSave {
        // robots-Array updaten (password = nil) und saveRobots() aufrufen
        // Damit wird der UserDefaults-Blob ohne Passwörter neu geschrieben
        saveRobots()
    }
}
```

**RobotConfig-Anpassung:** Nach Migration kann `password` weiterhin als optionales Feld in `RobotConfig` existieren (für neue Robots während AddRobotView), aber `saveRobots()` / `loadRobots()` dürfen es nicht mehr persistent speichern. Entweder: (a) `password` aus `Codable` herausnehmen via `CodingKeys`-Exclusion, oder (b) `password` beim Speichern auf `nil` setzen. Option (a) ist sicherer — verhindert versehentliches Speichern in Future.

**ValetudoAPI-Anpassung:** `ValetudoAPI` liest `config.password` direkt für den Authorization-Header. Nach Migration muss es `KeychainStore.password(for: config.id)` verwenden. Da `ValetudoAPI` ein `actor` ist, kann es `KeychainStore` (statische Methoden, kein actor) direkt aufrufen.

### Pattern 2: ErrorRouter als @EnvironmentObject

**Was:** `ErrorRouter` ist ein `@MainActor final class ErrorRouter: ObservableObject`. Er hält einen optionalen Fehler und eine optionale Retry-Closure. Views bekommen ihn via `@EnvironmentObject` und zeigen `.alert` wenn `currentError != nil`.

**Injection-Punkt:** `ValetudoApp.swift` (WindowGroup) — hier wird der `ErrorRouter` als `StateObject` angelegt und als `EnvironmentObject` injiziert.

**Bestehende Infrastruktur:** `APIError` ist bereits `LocalizedError` mit `errorDescription` — ErrorRouter kann direkt `(error as? LocalizedError)?.errorDescription ?? error.localizedDescription` verwenden.

```swift
// Helpers/ErrorRouter.swift
import SwiftUI

@MainActor
final class ErrorRouter: ObservableObject {
    @Published var currentError: Error?
    var retryAction: (() async -> Void)?

    func show(_ error: Error, retry: (() async -> Void)? = nil) {
        currentError = error
        retryAction = retry
    }

    func dismiss() {
        currentError = nil
        retryAction = nil
    }
}

extension View {
    func withErrorAlert(router: ErrorRouter) -> some View {
        self.alert(
            "Fehler",
            isPresented: Binding(
                get: { router.currentError != nil },
                set: { if !$0 { router.dismiss() } }
            ),
            presenting: router.currentError
        ) { _ in
            if router.retryAction != nil {
                Button("Erneut versuchen") {
                    Task { await router.retryAction?() }
                    router.dismiss()
                }
            }
            Button("OK", role: .cancel) { router.dismiss() }
        } message: { error in
            Text((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
```

**Injection in ValetudoApp.swift:**
```swift
@main
struct ValetudoApp: App {
    @StateObject private var robotManager = RobotManager()
    @StateObject private var errorRouter = ErrorRouter()  // NEU

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(robotManager)
                    .environmentObject(errorRouter)       // NEU
                    .withErrorAlert(router: errorRouter)  // NEU
            } else {
                OnboardingView()
                    .environmentObject(robotManager)
                    .environmentObject(errorRouter)       // NEU
            }
        }
    }
}
```

**ACHTUNG — ContentView.swift:** `ContentView` hat ein `#Preview` das `RobotManager()` injiziert. Nach ErrorRouter-Hinzufügung muss das Preview auch `errorRouter` bekommen — sonst Compile-Fehler in Preview.

### Pattern 3: os.Logger — Instanziierung und Privacy

**Was:** `os.Logger` als stored property, einmal pro Service-Klasse/Struct. Subsystem = `Bundle.main.bundleIdentifier`, Category = Service-Name.

**WICHTIG — Logger in Actor-Kontext:** `ValetudoAPI` ist ein `actor`. Logger als gespeicherte Eigenschaft im actor ist korrekt und thread-safe (Logger ist Sendable). Subsystem/Category müssen String-Literale oder Konstanten sein — keine computed properties.

```swift
// In ValetudoAPI (actor):
private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "API")

// Verwendung — SENSITIVITY RULES:
// URL-Pfad (kein Query-Param): .public sicher
logger.debug("Request: \(request.httpMethod ?? "GET", privacy: .public) \(url.path, privacy: .public)")
// Credentials: NIEMALS loggen, nur Presence
logger.debug("Auth header set: \(config.username != nil, privacy: .public)")
// Fehler-Codes: .public sicher
logger.error("HTTP Error: \(httpResponse.statusCode, privacy: .public)")
// Body-Inhalte: .private (könnte sensitive Daten enthalten)
logger.debug("Request body present: \(body != nil, privacy: .public)")
```

**Aktuell vorhandene print()-Aufrufe (identifiziert durch Codebase-Analyse):**

| Datei | Zeile | Inhalt | Sensitivity | Empfohlenes Level |
|-------|-------|--------|-------------|-------------------|
| ValetudoAPI.swift:111 | `[API DEBUG] \(method) \(url.absoluteString)` | URL enthält KEINEN Auth-Header — Pfad ist safe | SAFE | `.debug`, URL `.public` |
| ValetudoAPI.swift:113 | `[API DEBUG] Body: \(bodyString)` | Body könnte sensitive Werte enthalten | INTERNAL | `.debug`, body summary `.private` |
| NetworkScanner.swift:44 | `Could not determine local IP address` | Keine sensitiven Daten | SAFE | `.warning` |
| NetworkScanner.swift:49 | `Scanning subnet: \(subnet).x` | LAN-Subnet — lokal, aber identifying | SAFE/LOW | `.debug`, subnet `.private` |
| NotificationService.swift:31 | `Notification authorization failed: \(error)` | Fehlertext — kein credential | SAFE | `.error` |
| NotificationService.swift:119 | `Failed to schedule notification: \(error)` | Fehlertext — kein credential | SAFE | `.error` |

**Hinweis:** Views (MapView, RobotDetailView, RobotSettingsView) haben laut CONCERNS.md 80+ weitere print()-Aufrufe. Phase 1 ist auf Service-Layer beschränkt (D-08 spezifiziert Kategorien: API, RobotManager, NetworkScanner, Notifications, Views — jedoch zeigt die Codebase-Analyse keinen print() in RobotManager und Views-Aufruf ist Teil der Phase). Empfehlung: Service-Layer in Phase 1 vollständig; Views pauschal via Logger-Category "Views" abdecken, aber Vollständigkeit nicht voraussetzen.

**Logger-Instanziierung (Claude's Discretion):** Stored property empfohlen (nicht statisch, nicht lokal). Reasoning: stored property ist in Swift actors/classes korrekt isoliert, subsystem/category sind dann Teil des Objekts und leicht auffindbar.

### Pattern 4: NavigationLink(value:) für vollständige Zeile

**Was:** Die bestehende Implementierung in `RobotListView` verwendet `Button { ... } label: { RobotRowView(...) }` mit `.buttonStyle(.plain)` und einer State-basierten `navigateToRobot`-Variable für die `navigationDestination(item:)`. Das ist bereits ein valider Ansatz — `navigationDestination(item:)` ist vorhanden.

**Tatsächliche Situation:** Der Code verwendet bereits `navigationDestination(item: $navigateToRobot)`. Das Problem (D-11) ist, dass ein `Button` mit `.buttonStyle(.plain)` in einem `List` nicht immer die gesamte Zeile als Tap-Target hat, und der Ansatz ist nicht iOS-idiomatisch wenn `NavigationLink(value:)` verfügbar ist.

**Empfohlene Änderung:**
```swift
// Vorher (aktuell):
ForEach(robotManager.robots) { robot in
    Button {
        selectedRobotId = robot.id
        navigateToRobot = robot
    } label: {
        RobotRowView(robot: robot, ...)
    }
    .buttonStyle(.plain)
}
.navigationDestination(item: $navigateToRobot) { robot in
    RobotDetailView(robot: robot)
}

// Nachher (D-11):
ForEach(robotManager.robots) { robot in
    NavigationLink(value: robot) {
        RobotRowView(robot: robot, ...)
    }
}
.navigationDestination(for: RobotConfig.self) { robot in
    selectedRobotId = robot.id  // Nur wenn selectedRobotId noch benötigt
    return RobotDetailView(robot: robot)
}
```

**ACHTUNG — selectedRobotId:** `RobotListView` nimmt `@Binding var selectedRobotId: UUID?` entgegen. `ContentView` verwendet diese ID um den Map-Tab einzublenden. Mit `NavigationLink(value:)` muss `selectedRobotId` weiterhin gesetzt werden — entweder in `navigationDestination` oder via `.onChange(of: navigateToRobot)`. Die bestehende `onChange`-Logik kann erhalten bleiben.

**`RobotConfig` braucht `Hashable`:** `NavigationLink(value:)` mit `navigationDestination(for: RobotConfig.self)` erfordert, dass `RobotConfig` dem `Hashable`-Protokoll entspricht. `RobotConfig` ist bereits `Hashable` (Zeile 3 in RobotConfig.swift: `struct RobotConfig: Codable, Identifiable, Equatable, Hashable`). Kein Problem.

### Anti-Patterns to Avoid

- **SecItem ohne kSecAttrService:** Ohne Service-Namespace können Keychain-Queries unbeabsichtigt andere Apps oder Systemeinträge treffen. Immer `kSecAttrService: "com.valetudio.robot.password"` setzen.
- **Keychain-Delete vor Write:** `SecItemDelete` vor `SecItemAdd` ist korrekt (Update-Semantik). Aber: `errSecItemNotFound` beim Delete ist kein Fehler — ignorieren.
- **ErrorRouter via @StateObject in Views:** ErrorRouter soll eine einzige Instanz sein. Niemals `@StateObject var errorRouter = ErrorRouter()` in einer View anlegen — immer `@EnvironmentObject`.
- **print() mit privacy: .public für Passwörter:** Auch nach Migration nicht: `logger.debug("Password: \(password, privacy: .public)")`. Credentials werden grundsätzlich nicht geloggt.
- **`try?` bei Keychain-Write:** `SecItemAdd` kann fehlschlagen; das Ergebnis muss geprüft werden. `@discardableResult` ist für externe Aufrufer okay, aber intern immer den Rückgabewert prüfen.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Keychain-Zugriff | Eigene Verschlüsselung in UserDefaults | `Security.framework` SecItem API | Keychain ist OS-managed encryption, FIPS-konform, biometrisch gesichert |
| Logging mit Privacy-Control | Eigenes `debugPrint()` mit `#if DEBUG` | `os.Logger` | os.Logger ist in system log integriert, hat eingebaute Privacy-Typen, kein Code nötig für Release-Unterdrückung |
| Alert-Presentation | Eigenes Overlay-System | SwiftUI `.alert` Modifier | Nativer iOS-Pattern, accessibility-konform, keyboard-aware |

**Key insight:** Alle drei Problembereiche haben vollständige System-Lösungen — kein Code der "eigentlich trivial" wirkt ist wirklich trivial wenn man Privacy, Threading und Accessibility korrekt implementiert.

---

## Common Pitfalls

### Pitfall 1: Credentials gelöscht wenn Keychain-Write still fehlschlägt (KRITISCH)
**What goes wrong:** `SecItemAdd` gibt `errSecDuplicateItem` zurück (Robot war schon migriert), Code interpretiert das als Fehler, bricht ab ohne Read-back — und löscht dann trotzdem aus UserDefaults.
**Why it happens:** `errSecDuplicateItem` ist kein echter Fehler für Migration — der Eintrag ist bereits da. Aber wenn der Code bei nicht-erfolgreichen Status abbricht und das Delete danach trotzdem passiert, sind Credentials weg.
**How to avoid:** `errSecDuplicateItem` als Success behandeln (Eintrag existiert bereits, Read-back wird klappen). Read-back IMMER vor UserDefaults-Delete. Delete nur wenn `KeychainStore.password(for:) != nil`.
**Warning signs:** Migration-Code mit `guard status == errSecSuccess else { return }` vor dem Read-back.

### Pitfall 2: RobotConfig.password bleibt im UserDefaults-Blob (Post-Migration)
**What goes wrong:** Migration schreibt in Keychain, aber `saveRobots()` kodiert weiterhin `RobotConfig` mit `password`-Field. Beim nächsten App-Start liest `loadRobots()` das Passwort wieder aus UserDefaults (da es noch im Blob steht) und Migration läuft erneut — aber es gibt nun einen Keychain-Eintrag, also `errSecDuplicateItem`. Kein echter Bug, aber Passwörter bleiben in UserDefaults.
**How to avoid:** Nach Migration `password`-Field in `RobotConfig` aus `CodingKeys` für Encoding herausnehmen (exclude from serialization). Oder: nach Migration `robots[i].password = nil` setzen und `saveRobots()` aufrufen.
**Empfehlung:** `CodingKeys`-Exclusion-Ansatz — verhindert dauerhaft versehentliches Speichern.

### Pitfall 3: NavigationLink(value:) bricht selectedRobotId-Binding
**What goes wrong:** `selectedRobotId` in `ContentView` steuert ob der Map-Tab sichtbar ist. Wenn die Navigation auf `NavigationLink(value:)` umgestellt wird und `selectedRobotId` nicht mehr gesetzt wird, verschwindet der Map-Tab.
**How to avoid:** In `navigationDestination(for: RobotConfig.self)` auch `selectedRobotId` setzen. Die bestehende `onChange(of: navigateToRobot)`-Logik kann bleiben, aber muss möglicherweise angepasst werden wenn `navigateToRobot` wegfällt.

### Pitfall 4: Logger in Actor wird mit computed subsystem/category erstellt
**What goes wrong:** `Logger(subsystem: someComputedValue, category: "API")` — wenn `someComputedValue` zur Laufzeit berechnet wird (z.B. `self.name`), kann das in Swift actors Isolation-Probleme verursachen. `Bundle.main.bundleIdentifier` ist ein optionaler String — der `?? ""` Fallback muss vorhanden sein.
**How to avoid:** `private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "API")` — immer statisch/konstant, nie computed.

### Pitfall 5: ErrorRouter-Alert-Titel ist nicht lokalisiert
**What goes wrong:** Alert-Titel hardcoded als `"Fehler"` oder `"Error"` — nicht in String-Catalog.
**How to avoid:** `String(localized: "error.title")` im Alert-Titel verwenden. Key im String-Catalog anlegen.

---

## Code Examples

### KeychainStore — vollständige Implementierung
```swift
// Services/KeychainStore.swift
import Foundation
import Security

struct KeychainStore {
    private static let service = "com.valetudio.robot.password"

    static func password(for robotId: UUID) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: robotId.uuidString,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func save(password: String, for robotId: UUID) -> Bool {
        let deleteQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: robotId.uuidString
        ]
        SecItemDelete(deleteQuery as CFDictionary) // errSecItemNotFound is OK

        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: robotId.uuidString,
            kSecValueData: Data(password.utf8),
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    static func delete(for robotId: UUID) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: robotId.uuidString
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

### RobotManager.loadRobots() — Migration Hook
```swift
// In RobotManager.swift
private func loadRobots() {
    guard let data = UserDefaults.standard.data(forKey: storageKey),
          let decoded = try? JSONDecoder().decode([RobotConfig].self, from: data) else { return }

    var migratedRobots = decoded
    var migrationOccurred = false

    for (index, robot) in decoded.enumerated() {
        // Skip if already in Keychain
        guard KeychainStore.password(for: robot.id) == nil else { continue }

        // Migrate if UserDefaults (embedded in JSON) has a password
        if let legacyPassword = robot.password, !legacyPassword.isEmpty {
            let saved = KeychainStore.save(password: legacyPassword, for: robot.id)
            // Read-back verification (D-05) — only delete from blob if verified
            if saved, KeychainStore.password(for: robot.id) != nil {
                migratedRobots[index] = RobotConfig(
                    id: robot.id, name: robot.name, host: robot.host,
                    username: robot.username, password: nil, // cleared
                    useSSL: robot.useSSL, ignoreCertificateErrors: robot.ignoreCertificateErrors
                )
                migrationOccurred = true
            }
        }
        apis[robot.id] = ValetudoAPI(config: migratedRobots[index])
    }

    robots = migratedRobots
    if migrationOccurred { saveRobots() } // Re-save without passwords
}
```

### ValetudoAPI — Logger statt print()
```swift
// In ValetudoAPI (actor):
private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.valetudio", category: "API")

// Vorher:
print("[API DEBUG] \(method) \(url.absoluteString)")
// Nachher:
logger.debug("Request: \(method, privacy: .public) \(url.path, privacy: .public)")

// Credential-Zugriff nach Migration:
// Vorher: config.password
// Nachher: KeychainStore.password(for: config.id)
```

---

## Runtime State Inventory

> Keine Rename/Refactor-Phase — dieser Abschnitt gilt für Credential-Migration.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | UserDefaults Key `"valetudo_robots"`: JSON-Array mit `password`-Field in jedem RobotConfig | Code-Edit: Migrationslogik in `loadRobots()`, Post-Migration `saveRobots()` ohne Passwörter |
| Live service config | Keychain (leer — kein Valetudo-Eintrag vorhanden) | Neuer Keychain-Eintrag pro Robot wird angelegt |
| OS-registered state | Keine Task-Scheduler-Registrierungen für Phase 1 | None |
| Secrets/env vars | Keine separaten Env-Vars; credentials nur in UserDefaults JSON-Blob | Code-Migration |
| Build artifacts | Keine relevanten Artefakte | None |

**Post-Migration UserDefaults-Zustand:** Nach erfolgreicher Migration enthält der UserDefaults-Blob weiterhin alle RobotConfig-Felder **ausser** `password`. Das ist korrekt. `username` kann im Blob bleiben (kein Credential im sicherheitsrelevanten Sinne — nur für Anzeige/Basic-Auth-Lookup nötig). Falls `username` auch sensitive ist: analog zu `password` migrieren.

---

## Validation Architecture

> nyquist_validation nicht explizit auf false gesetzt — Abschnitt einbeziehen.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Kein Test-Target vorhanden (bestätigt durch Codebase-Analyse) |
| Config file | none — kein Test-Target in Xcode-Projekt |
| Quick run command | n/a — Wave 0 muss Test-Target anlegen (Phase 4 scope) |
| Full suite command | n/a |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| NET-03 | KeychainStore.save() + read-back gibt korrekten Wert zurück | unit | `xcodebuild test -scheme ValetudoApp -only-testing:ValetudoAppTests/KeychainStoreTests` | ❌ Wave 0 |
| NET-03 | Migration löscht password aus RobotConfig-Blob nur nach erfolgreichem Read-back | unit | `xcodebuild test -scheme ValetudoApp -only-testing:ValetudoAppTests/KeychainMigrationTests` | ❌ Wave 0 |
| UX-02 | ErrorRouter.show() setzt currentError und retryAction | unit | `xcodebuild test -scheme ValetudoApp -only-testing:ValetudoAppTests/ErrorRouterTests` | ❌ Wave 0 |
| UX-01 | Robot-Zeile navigiert auch bei Tap auf Leeraum (Whitespace) | manual | n/a — Simulator/Device-Test | — |
| DEBT-01 | Keine print()-Aufrufe mehr in Service-Dateien | static (grep) | `grep -r "print(" ValetudoApp/ValetudoApp/Services/` | — |

**Hinweis:** Da kein Test-Target existiert und Test-Target-Anlage in Phase 4 liegt, sind alle automatisierten Tests Wave-0-Gaps. Die statische DEBT-01-Prüfung kann als Grep-Kommando in der Verifikation verwendet werden.

### Sampling Rate
- **Per task commit:** Xcode Build (kein Test-Target) — Compile-Fehler als Minimum-Gate
- **Per wave merge:** Kein Test-Target in Phase 1 — manuelles Smoke-Testing auf Device
- **Phase gate:** Compile-Fehler-frei + manuelle Verifikation der 4 Anforderungen vor `/gsd:verify-work`

### Wave 0 Gaps
Da Phase 4 das Test-Target einführt, sind Test-Files in Phase 1 bewusst Out-of-Scope. Stattdessen manuelle Verifikation:
- [ ] Keychain-Migration auf Device testen: App installieren, Robots mit Credentials anlegen, Update installieren, verifizieren dass Robots noch funktionieren
- [ ] ErrorRouter: absichtlich ungültige Host-Adresse eingeben → Alert erscheint
- [ ] NavigationLink: auf Leeraum in Robot-Zeile tippen → Navigation erfolgt
- [ ] os.Logger: Console.app anschliessen, Production-Build ausführen → keine Credentials in Logs

*(Wenn Test-Target früher benötigt: Minimal-Setup mit `ValetudoAppTests`-Target in Xcode, `@testable import ValetudoApp`)*

---

## Environment Availability

> Nur Xcode und iOS-Simulator/Device relevant. Keine externen Tools.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build & Test | ✓ | Project targets iOS 17+ | — |
| Security.framework | KeychainStore | ✓ | System (alle iOS-Versionen) | — |
| os.framework | os.Logger | ✓ | iOS 14+ (Projekt-Minimum ist iOS 17) | — |
| SwiftUI .alert modifier mit presenting: | ErrorRouter | ✓ | iOS 15+ | — |
| NavigationLink(value:) + navigationDestination(for:) | UX-01 | ✓ | iOS 16+ | — |

Alle Dependencies sind System-Frameworks ohne Installationsaufwand.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `print()` für Debug-Output | `os.Logger` | WWDC 2020, iOS 14 | Privacy-Kontrolle, Subsystem-Filterung, kein Code nötig für Release-Unterdrückung |
| `os_log()` C-style | `os.Logger` Swift-Type | iOS 14 | Typ-sichere Interpolation mit Privacy-Attributen |
| `NavigationLink { destination } label: { ... }` | `NavigationLink(value:)` + `navigationDestination(for:)` | iOS 16 | Lazy destination, bessere Tap-Target-Semantik in Lists |
| Credentials in UserDefaults | iOS Keychain | Best Practice seit iOS 3 | Verschlüsselt, biometrisch gesichert, nicht in Backups |

**Deprecated/outdated:**
- `navigationDestination(item:)` mit `@Binding<Optional>`: funktioniert, aber `navigationDestination(for:)` mit `NavigationLink(value:)` ist der modernere Ansatz für iOS 16+.
- Direkte `SecItemUpdate`-Calls ohne vorheriges Delete: Delete-then-Add ist robuster als Update.

---

## Open Questions

1. **`username` im UserDefaults-Blob nach Migration**
   - What we know: Nur `password` ist als sicherheitskritisch identifiziert. `username` bleibt im Blob.
   - What's unclear: Soll `username` ebenfalls in den Keychain? (Wäre konsistenter, aber nicht von Requirements verlangt)
   - Recommendation: `username` im UserDefaults-Blob belassen für v1.2.0. Basic-Auth braucht username häufig für Anzeige. Nur `password` migrieren.

2. **`RobotConfig.password` im Speicher-Zustand nach Migration**
   - What we know: `ValetudoAPI` liest `config.password` für den Authorization-Header. Nach Migration soll es `KeychainStore.password(for:)` verwenden.
   - What's unclear: Gibt es andere Stellen in der App die `robot.password` direkt lesen? (z.B. `RobotIntents.swift`)
   - Recommendation: Vor Implementation `robot.password` in der Codebase suchen. `RobotIntents.swift` liest Robots via `UserDefaults` direkt — muss ebenfalls auf `KeychainStore` umgestellt werden.

3. **ErrorRouter: Level der Alert-Texte**
   - What we know: `APIError.errorDescription` liefert technische Strings wie "HTTP Error: 404". Für Users wenig hilfreich.
   - What's unclear: Sollen die Messages in Phase 1 verbessert werden oder reicht die bestehende `errorDescription`?
   - Recommendation: Phase 1 verwendet `errorDescription` as-is. User-freundliche Texte sind ein separates UX-Concern ausserhalb des Phase-1-Scope.

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: Keychain Services — SecItemAdd, SecItemCopyMatching, kSecAttrAccessibleWhenUnlockedThisDeviceOnly
- Apple Developer Documentation: os.Logger, OSLogPrivacy — subsystem/category pattern, privacy annotations
- Apple Developer Documentation: NavigationLink(value:), navigationDestination(for:) — iOS 16+
- `.planning/research/PITFALLS.md` — Pitfall 2 (Credentials Migration), Pitfall 5 (os.Logger Privacy), Pitfall 7 (NavigationLink)
- `.planning/research/ARCHITECTURE.md` — Pattern 3 (Keychain Migration), Pattern 4 (ErrorRouter)
- Direkter Codebase-Befund: 6 print()-Aufrufe in Service-Layer identifiziert

### Secondary (MEDIUM confidence)
- `.planning/codebase/CONCERNS.md` — Security-Section (UserDefaults Credentials), Error-Handling-Section
- ValetudiOS Codebase: `RobotManager.swift`, `ValetudoAPI.swift`, `RobotListView.swift`, `RobotConfig.swift`

### Tertiary (LOW confidence)
- Keine LOW-confidence Findings in diesem Phase-Scope.

---

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — System-Frameworks, keine Versions-Unsicherheit
- Architecture: HIGH — Patterns direkt aus Codebase-Analyse und gesicherter Prior-Research
- Pitfalls: HIGH — Aus dediziertem Pitfalls-Research + direkter Codebase-Verifikation

**Research date:** 2026-03-27
**Valid until:** 2026-06-27 (stabile iOS-System-APIs, keine Ablaufdaten)
