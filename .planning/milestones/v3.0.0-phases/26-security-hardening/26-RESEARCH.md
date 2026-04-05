# Phase 26: Security Hardening - Research

**Researched:** 2026-04-04
**Domain:** iOS SwiftUI — Security Indicators, Keychain Storage, UserDefaults Migration
**Confidence:** HIGH

## Summary

Phase 26 hat drei klar abgegrenzte Aufgaben: (1) einen Security-Indikator in der RobotDetailView bei HTTP-Verbindungen, (2) eine deutlichere Warnung bei aktiviertem `ignoreCertificateErrors` in der Robot-Konfiguration (AddRobotView und EditRobotView), und (3) die Migration der RobotConfig aus UserDefaults in den Keychain.

Die Codebasis ist gut vorbereitet: `KeychainStore` existiert bereits und funktioniert (Passwörter werden bereits darin gespeichert). `RobotConfig` hat `useSSL` und `ignoreCertificateErrors` als Felder, und `baseURL` leitet das HTTP/HTTPS-Schema direkt aus `useSSL` ab — damit ist der URL-Schema-Check trivial. Die größte Aufgabe ist SEC-03: das vollständige Encoding der RobotConfig muss aus UserDefaults heraus in den Keychain, wobei eine Migrationsstrategie für bestehende Installs erforderlich ist.

**Primäre Empfehlung:** KeychainStore um eine `robotConfig(for:)` / `saveRobotConfig(_:for:)` API erweitern, die JSON-serialisierte RobotConfig-Blobs (ohne Passwort) speichert. UserDefaults wird nach erfolgreicher Migration als Fallback-Lesepfad beibehalten und dann geleert.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SEC-01 | Bei HTTP-Verbindung zeigt die Robot-Detail-View einen Security-Indikator | `robot.useSSL == false` ist der direkte Check; passend in `RobotStatusHeaderView` oder als Section-Banner in `RobotDetailView` |
| SEC-02 | Wenn `ignoreCertificateErrors` aktiviert ist, zeigt die Robot-Konfiguration eine deutliche Warnung | `AddRobotView` hat bereits ein `.warning`-Footer; `EditRobotView` hat `ignoreCertificateErrors`-Feld noch gar nicht — muss ergänzt werden |
| SEC-03 | Robot-Config wird in Keychain oder verschlüsseltem Storage gespeichert — nicht in unverschlüsseltem UserDefaults | `saveRobots()` / `loadRobots()` in `RobotManager` ist der einzige Persistenz-Pfad |
</phase_requirements>

---

## Codebase Findings (Projektspezifisch)

### RobotConfig — Felder und aktueller Speicherort

**Datei:** `ValetudoApp/Models/RobotConfig.swift`

Felder:
- `id: UUID`
- `name: String`
- `host: String`
- `username: String?`
- `password: String?` — **bereits aus CodingKeys ausgeschlossen**, wird NICHT in UserDefaults gespeichert
- `useSSL: Bool`
- `ignoreCertificateErrors: Bool`

**Aktueller Speicherort:** UserDefaults, Key `"valetudo_robots"`, JSON-Blob via `JSONEncoder`. Passwort wurde bereits in Keychain migriert (Migration-Logik in `loadRobots()`). Host, Name, Username, useSSL, ignoreCertificateErrors liegen noch in UserDefaults.

**Computed property für URL-Schema:**
```swift
var baseURL: URL? {
    let scheme = useSSL ? "https" : "http"
    return URL(string: "\(scheme)://\(host)")
}
```

HTTP-Check: `robot.useSSL == false`

### RobotManager — Persistenz

**Datei:** `ValetudoApp/Services/RobotManager.swift`

Relevante Methoden:
- `loadRobots()` — liest von `UserDefaults.standard.data(forKey: storageKey)`, enthält bereits Passwort-Migration-Logik
- `saveRobots()` — schreibt zu `UserDefaults.standard.set(encoded, forKey: storageKey)`
- `private let storageKey = "valetudo_robots"`

Der Migrations-Pfad ist bereits etabliert: `loadRobots()` iteriert über decoded robots, prüft Keychain-Existenz und migriert bei Bedarf. Dieses Pattern kann für SEC-03 wiederverwendet werden.

### RobotDetailView — Wo Security-Indikator hinkommt

**Datei:** `ValetudoApp/Views/RobotDetailView.swift`

Die `RobotDetailView` ist eine `List` mit Sections. Die erste Section enthält `RobotStatusHeaderView`. Der Security-Indikator passt als:
- **Option A:** Direkt in `RobotStatusHeaderView` (Zeile 7–79) — bereits ein HStack mit Status-Dot, Status-Text, Model-Name, Consumable-Warning, Locate-Button, Battery-Pill
- **Option B:** Eigene Section direkt unter der Status-Header-Section, als Banner (wie `UpdateStatusBannerView`)

**Empfehlung Option A:** Ein Lock-Icon mit `.orange`-Farbe in `RobotStatusHeaderView` einfügen, direkt neben dem Consumable-Warning — konsistent mit dem bestehenden Muster.

### Robot-Konfigurationsansichten — Wo SEC-02-Warnung hinkommt

**AddRobotView** (`ValetudoApp/Views/AddRobotView.swift`):
- Zeilen 62–75: SSL-Section mit Toggle für `useSSL` und bedingtem Toggle für `ignoreCertificateErrors`
- Zeile 71–74: Bereits ein `.orange` Footer-Text bei `useSSL && ignoreCertificateErrors`
- **Bestehende Warnung ist subtil** (nur Footer-Text, keine visuelle Hervorhebung)
- Verbesserung: Prominenteres Warning-Banner (gelb/orange Box mit Icon)

**EditRobotView** (`ValetudoApp/Views/SettingsView.swift`, Zeile 176–297):
- Enthält: Name, Host, useAuthentication-Toggle, Username, Password
- **Fehlt vollständig:** `useSSL`-Toggle, `ignoreCertificateErrors`-Toggle — und damit auch keine Warnung
- `saveRobot()` erstellt `RobotConfig` ohne `useSSL`/`ignoreCertificateErrors` — überschreibt bestehende Werte auf `false`!
- SEC-02 erfordert, dass EditRobotView diese Felder ebenfalls anzeigt und die Warnung anzeigt

### KeychainStore — Aktueller Stand und Erweiterbarkeit

**Datei:** `ValetudoApp/Services/KeychainStore.swift`

Aktuelle API (nur für Passwörter):
```swift
static func password(for robotId: UUID) -> String?
static func save(password: String, for robotId: UUID) -> Bool
static func delete(for robotId: UUID)
```

Service-Key: `"com.valetudio.robot.password"`
Accessibility: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`

**Erweiterungsstrategie für SEC-03:** Neuer Service-Key `"com.valetudio.robot.config"` für JSON-serialisierte RobotConfig-Blobs (ohne Passwort). Gleiche Security-Attribute (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`). Pattern ist identisch zum bestehenden Passwort-Code.

---

## Standard Stack

### Core (relevant für diese Phase)

| Technologie | Version | Zweck | Warum Standard |
|------------|---------|-------|----------------|
| Security.framework | iOS 17+ | Keychain-Zugriff via SecItem* API | Native Apple, kein Extern-Dep |
| SwiftUI | iOS 17+ | Warning-UI-Komponenten | Bestehendes Stack |
| Foundation | Swift 5.9 | JSONEncoder/Decoder für Keychain-Blob | Bereits im Einsatz |

### Alternativen — Nicht verwenden

| Statt | Nicht verwenden | Grund |
|-------|----------------|-------|
| Direkter Keychain via Security.framework | KeychainAccess-Library (SPM) | Projekt hat zero external dependencies |
| Keychain für Config-Blob | CryptoKit / FileManager + Verschlüsselung | Unnötige Komplexität; Keychain ist der iOS-Standard |
| UserDefaults + NSDataProtection | — | Keychain ist besser für sensible Konfigurationsdaten |

---

## Architecture Patterns

### SEC-01: HTTP Security-Indikator in RobotStatusHeaderView

**Pattern:** Bedingtes Icon im bestehenden HStack

```swift
// In RobotStatusHeaderView.swift — im HStack nach Consumable-Warning
if !viewModel.robot.useSSL {
    Image(systemName: "lock.open.fill")
        .font(.caption)
        .foregroundStyle(.orange)
}
```

**Placement:** Nach `hasConsumableWarning`-Check, vor dem Locate-Button. Konsistent mit bestehenden Icons.

**Accessibility:** `.accessibilityLabel(String(localized: "security.http_connection"))` hinzufügen.

### SEC-02: Prominente Warnung bei ignoreCertificateErrors

**Pattern:** Inline-Warning-View statt Footer-Text

```swift
// Ersetze bestehenden Footer-Text in AddRobotView durch:
if useSSL && ignoreCertificateErrors {
    HStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.white)
        Text(String(localized: "settings.ignore_certificate_errors.warning"))
            .font(.footnote)
            .foregroundStyle(.white)
    }
    .padding(12)
    .background(Color.orange)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .listRowBackground(Color.orange.opacity(0.1))
}
```

**EditRobotView:** SSL-Felder fehlen komplett. Muss `useSSL` und `ignoreCertificateErrors` aus dem Robot laden und als State speichern; `saveRobot()` muss diese beim Update übergeben.

### SEC-03: Keychain-Storage für RobotConfig

**Neuer KeychainStore-API:**

```swift
// KeychainStore.swift — neuer Abschnitt
private static let configService = "com.valetudio.robot.config"

static func robotConfig(for robotId: UUID) -> RobotConfig? {
    let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: configService,
        kSecAttrAccount: robotId.uuidString,
        kSecReturnData: true,
        kSecMatchLimit: kSecMatchLimitOne
    ]
    var result: AnyObject?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
          let data = result as? Data else { return nil }
    return try? JSONDecoder().decode(RobotConfig.self, from: data)
}

@discardableResult
static func saveRobotConfig(_ config: RobotConfig, for robotId: UUID) -> Bool {
    let deleteQuery: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: configService,
        kSecAttrAccount: robotId.uuidString
    ]
    SecItemDelete(deleteQuery as CFDictionary)

    guard let data = try? JSONEncoder().encode(config) else { return false }
    let addQuery: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: configService,
        kSecAttrAccount: robotId.uuidString,
        kSecValueData: data,
        kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]
    return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
}

static func deleteRobotConfig(for robotId: UUID) {
    let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: configService,
        kSecAttrAccount: robotId.uuidString
    ]
    SecItemDelete(query as CFDictionary)
}
```

**RobotManager — Migration in loadRobots():**

```swift
private func loadRobots() {
    // 1. Versuche aus Keychain zu laden (neuer Pfad)
    // 2. Fallback: UserDefaults (bestehende Installs)
    // 3. Nach erfolgreichem Keychain-Load: UserDefaults leeren

    var loadedRobots: [RobotConfig]? = nil

    // Prüfe ob Keychain-Daten vorhanden (Migration schon erfolgt)
    // Heuristik: Wenn für den ersten gespeicherten Robot ein Keychain-Config-Eintrag existiert,
    // nehme an dass alle migriert wurden
    if let keychainIds = loadRobotIds(),
       let firstId = keychainIds.first,
       KeychainStore.robotConfig(for: firstId) != nil {
        loadedRobots = keychainIds.compactMap { KeychainStore.robotConfig(for: $0) }
    }

    // Fallback: UserDefaults
    if loadedRobots == nil,
       let data = UserDefaults.standard.data(forKey: storageKey),
       let decoded = try? JSONDecoder().decode([RobotConfig].self, from: data) {
        loadedRobots = decoded
        // Migriere in Keychain
        for robot in decoded {
            KeychainStore.saveRobotConfig(robot, for: robot.id)
        }
        saveRobotIds(decoded.map { $0.id })
        // UserDefaults leeren nach Migration
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    robots = loadedRobots ?? []
    for robot in robots {
        apis[robot.id] = ValetudoAPI(config: robot)
    }
}
```

**Hinweis zu Robot-ID-Liste:** Da Keychain-Items nicht effizient auflistbar sind, muss eine geordnete ID-Liste irgendwo gespeichert werden. Optionen:
- **Option A (einfacher):** ID-Liste weiterhin in UserDefaults (nicht sensibel — nur UUIDs)
- **Option B:** Separate Keychain-Eintrag mit ID-Array als JSON

**Empfehlung Option A:** UUID-Liste in UserDefaults ist nicht sensibel. Nur Konfigurationsdaten (host, username, useSSL) gehen in den Keychain.

---

## Don't Hand-Roll

| Problem | Nicht bauen | Verwenden |
|---------|-------------|-----------|
| Keychain-Wrapper | Eigene Abstraktion mit CryptoKit | Bestehender `KeychainStore` erweitern |
| Verschlüsselte Datei-Storage | FileManager + AES | Keychain (iOS-Standard für sensible Konfigurationsdaten) |
| UserDefaults-Encryption | NSDataProtection | Keychain |

---

## Common Pitfalls

### Pitfall 1: EditRobotView verliert useSSL/ignoreCertificateErrors beim Speichern
**Was passiert:** `saveRobot()` in `EditRobotView` erstellt `RobotConfig` ohne `useSSL` und `ignoreCertificateErrors`. Beide werden auf `false` gesetzt, auch wenn der User sie ursprünglich aktiviert hatte.
**Warum:** Die State-Variablen für diese Felder fehlen in `EditRobotView` komplett.
**Vermeiden:** Beim `init(robot:)` State für `useSSL` und `ignoreCertificateErrors` aus dem Robot-Objekt laden. In `saveRobot()` übergeben.

### Pitfall 2: Keychain-Eintrag nicht findbar nach Reinstall oder App-Gruppe-Wechsel
**Was passiert:** Bei App-Reinstall ohne iCloud-Keychain-Sync sind Keychain-Items nicht wiederherstellbar.
**Warum:** `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` erlaubt kein iCloud-Backup.
**Vermeiden:** Für Phase 26 akzeptabel — bestehender KeychainStore hat das gleiche Verhalten für Passwörter. Kein Scope-Change.

### Pitfall 3: Keychain-Items bleiben nach App-Löschung bestehen
**Was passiert:** Keychain-Items auf iOS 17 persisitieren app-delete/reinstall (außer mit `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — bei dem ist das Verhalten implementierungsabhängig in Simulatoren).
**Vermeiden:** Beim ersten App-Start prüfen ob robots leer sind aber Keychain-Einträge vorhanden; gegebenenfalls bereinigen. Für Phase 26 nicht kritisch.

### Pitfall 4: Keychain-Blob enthält `password`-Feld
**Was passiert:** Wenn RobotConfig mit Passwort-Feld (nicht nil) in Keychain gespeichert wird, doppelt sich das Passwort.
**Warum:** `RobotConfig.CodingKeys` schließt `password` schon aus — aber das Passwort-Feld (`var password: String?`) ist im Struct vorhanden.
**Vermeiden:** Vor dem `KeychainStore.saveRobotConfig()` sicherstellen, dass `config.password` nil ist (es ist bereits durch `CodingKeys` aus dem Encoder ausgeschlossen — kein Problem).

### Pitfall 5: Warning-Banner in AddRobotView vs. EditRobotView inkonsistent
**Was passiert:** SEC-02-Warnung in AddRobotView wird verbessert, aber EditRobotView hat weiterhin keine Warnung (und `ignoreCertificateErrors` ist dort komplett unsichtbar).
**Vermeiden:** Beide Views gleichzeitig behandeln.

---

## Code Examples

### HTTP-Check (SEC-01)
```swift
// Source: RobotConfig.swift (Codebase)
// Direkte Property-Prüfung — kein baseURL-Parsing nötig
let isHTTP = !robot.useSSL
```

### Bestehende Warnung in AddRobotView (zu verbessern)
```swift
// Source: AddRobotView.swift Zeile 71-74
} footer: {
    if useSSL && ignoreCertificateErrors {
        Text(String(localized: "settings.ignore_certificate_errors.warning"))
            .foregroundStyle(.orange)
    }
}
```

### Bestehender Keychain-Save (Pattern für Erweiterung)
```swift
// Source: KeychainStore.swift Zeile 24-43
@discardableResult
static func save(password: String, for robotId: UUID) -> Bool {
    // delete-then-add Pattern
    let deleteQuery: [CFString: Any] = [...]
    SecItemDelete(deleteQuery as CFDictionary)
    let addQuery: [CFString: Any] = [
        kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]
    return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
}
```

---

## Open Questions

1. **UUID-Listen-Persistenz für Keychain-Lookup**
   - Was wir wissen: Keychain hat keine `list all items for service`-Funktion die zuverlässig auf allen iOS-Versionen funktioniert (`kSecMatchLimitAll` ist möglich aber komplex)
   - Unklar: Ob eine separate `robot_ids`-Liste in UserDefaults akzeptabel ist oder ob ein anderer Ansatz besser ist
   - Empfehlung: `robot_ids`-Array in UserDefaults speichern (nur UUIDs, nicht sensibel). Alternativ: Gesamte ID-Liste als einzelner Keychain-Blob.

2. **EditRobotView scope**
   - Was wir wissen: EditRobotView fehlen useSSL und ignoreCertificateErrors vollständig
   - Unklar: Ob SEC-02 nur AddRobotView betrifft oder auch EditRobotView gefordert ist
   - Empfehlung: Beide Views für Konsistenz behandeln — REQUIREMENTS.md sagt "Robot-Konfiguration" ohne View-Einschränkung

---

## Sources

### Primary (HIGH confidence)
- Codebase direkt gelesen: `RobotConfig.swift`, `KeychainStore.swift`, `RobotManager.swift`, `RobotDetailView.swift`, `RobotStatusHeaderView.swift`, `AddRobotView.swift`, `SettingsView.swift` (EditRobotView)
- `.planning/REQUIREMENTS.md` — SEC-01, SEC-02, SEC-03 Definitionen

### Secondary (MEDIUM confidence)
- Apple Security.framework Keychain API — bekannte stabile API seit iOS 2.0, keine Änderungen seit iOS 17

---

## Metadata

**Confidence breakdown:**
- SEC-01 Implementation: HIGH — `useSSL`-Flag ist direkt verfügbar, Placement-Stelle klar
- SEC-02 Implementation: HIGH — Bestehende Warnung in AddRobotView nachvollziehbar; EditRobotView-Gap identifiziert
- SEC-03 Implementation: HIGH — KeychainStore-Muster ist bereits etabliert; Migrations-Pattern bereits vorhanden in loadRobots()
- Migrations-Strategie ID-Liste: MEDIUM — Pragmatischer Ansatz (UserDefaults für IDs) ist sicher, aber nicht die reinste Lösung

**Research date:** 2026-04-04
**Valid until:** 2026-05-04 (stabile Codebase, keine externen Deps)
