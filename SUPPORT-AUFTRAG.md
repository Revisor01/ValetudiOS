# Auftrag: Support & Branding für ValetudiOS

Implementiere die gleiche Support/Spenden-Funktion und das Branding wie in PrivacyFlow (InsightFlow).
Das Design muss identisch sein — nur die App-spezifischen Texte und Product-IDs ändern sich.

## Was zu tun ist

### 1. SupportManager.swift erstellen

Erstelle einen `SupportManager` als `@MainActor ObservableObject` mit `static let shared`.

**Funktionen:**
- `loadProducts()` — lädt StoreKit 2 Products
- `purchase(_ product: Product)` — kauft ein Produkt
- `incrementLaunchCount()` — zählt App-Starts
- `shouldShowReminder` — true nach 5 Starts, wenn noch nicht gezeigt/unterstützt
- `markReminderShown()` / `markAlreadySupported()`

**Product IDs anpassen** (NICHT die PrivacyFlow-IDs verwenden!):
```swift
private let productIds = [
    "de.godsapp.valetudoapp.support.small",   // 0,99€
    "de.godsapp.valetudoapp.support.medium",  // 2,99€
    "de.godsapp.valetudoapp.support.large"    // 5,99€
]
```

**Product Extension** — SF Symbols statt Emojis:
```swift
extension Product {
    var symbolName: String {
        switch id {
        case "de.godsapp.valetudoapp.support.small": return "cup.and.saucer.fill"
        case "de.godsapp.valetudoapp.support.medium": return "gift.fill"
        case "de.godsapp.valetudoapp.support.large": return "sparkles"
        default: return "heart.fill"
        }
    }

    var tierColor: Color {
        switch id {
        case "de.godsapp.valetudoapp.support.small": return .blue
        case "de.godsapp.valetudoapp.support.medium": return .purple
        case "de.godsapp.valetudoapp.support.large": return .orange
        default: return .accentColor
        }
    }

    var supportName: String {
        switch id {
        case "de.godsapp.valetudoapp.support.small":
            return String(localized: "support.small")
        case "de.godsapp.valetudoapp.support.medium":
            return String(localized: "support.medium")
        case "de.godsapp.valetudoapp.support.large":
            return String(localized: "support.large")
        default:
            return displayName
        }
    }
}
```

### 2. SupportView.swift erstellen

Clean Design mit SF Symbols in farbigen Circles. Kein Emoji.

```swift
struct SupportButton: View {
    let product: Product
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(product.tierColor)
                        .frame(width: 44, height: 44)
                    Image(systemName: product.symbolName)
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(product.supportName)
                        .font(.headline)
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
```

Die SupportView zeigt:
- Herz-Icon (50pt, pink)
- Header + Message Text
- 3 SupportButtons (ForEach über products)
- Footer "Alle Käufe sind einmalig."
- NavigationStack mit "Fertig"-Button
- `.task { await supportManager.loadProducts() }`
- Error-Alert und ThankYou-Alert

### 3. SupportReminderView.swift erstellen

Overlay das nach 5 App-Starts erscheint:
- Herz-Circle-Icon (60pt, pink)
- Titel + Message
- 3 Buttons: "Gerne unterstützen" (pink, öffnet SupportView), "Hab ich schon", "Gerade nicht"
- ViewModifier `SupportReminderOverlay` mit `.onAppear { incrementLaunchCount() }`
- `extension View { func supportReminder() -> some View }`

### 4. In der App integrieren

- `.supportReminder()` Modifier auf den Haupt-Content anwenden (wie MainTabView oder ähnlich)
- In den Settings einen "Unterstützen"-Link zur SupportView hinzufügen

### 5. Settings-Footer Branding

Im Footer der Settings-View (oder About-Bereich) einfügen:

```swift
// Bestehend oder neu:
HStack(spacing: 4) {
    Text("Made with")
    Image(systemName: "heart.fill")
        .foregroundStyle(.pink)
    Text("in Hennstedt")
}
.font(.caption)
.foregroundStyle(.secondary)
```

### 6. Lokalisierungs-Strings

**Deutsch (de.lproj/Localizable.strings):**
```
"button.done" = "Fertig";
"support.title" = "Unterstützen";
"support.header" = "Unterstütze ValetudiOS";
"support.message" = "Software sollte frei sein.\n\nWenn du es dir gerade leisten kannst, freue ich mich über deine Unterstützung. Ansonsten nutze die App einfach gerne – das ist völlig in Ordnung.";
"support.small" = "Kleine Geste";
"support.medium" = "Nette Geste";
"support.large" = "Große Geste";
"support.thankyou.title" = "Vielen Dank!";
"support.thankyou.message" = "Deine Unterstützung bedeutet mir sehr viel und hilft dabei, diese App weiterzuentwickeln. Danke!";
"support.footer" = "Alle Käufe sind einmalig.";
"support.unavailable" = "Nicht verfügbar";
"support.unavailable.description" = "Unterstützungs-Optionen konnten nicht geladen werden";
"support.error" = "Fehler";
"support.error.unverified" = "Kauf konnte nicht verifiziert werden";
"support.error.pending" = "Kauf wird bearbeitet";
"support.reminder.title" = "Dir gefällt ValetudiOS?";
"support.reminder.message" = "Diese App ist kostenlos und werbefrei. Sie wurde mit viel Liebe entwickelt.\n\nSoftware sollte frei sein. Wenn du es dir leisten kannst, unterstütze die Entwicklung gerne. Ansonsten nutze die App einfach weiter – das ist völlig okay!";
"support.reminder.support" = "Gerne unterstützen";
"support.reminder.already" = "Hab ich schon";
"support.reminder.later" = "Gerade nicht";
```

**Englisch (en.lproj/Localizable.strings):**
```
"button.done" = "Done";
"support.title" = "Support";
"support.header" = "Support ValetudiOS";
"support.message" = "Software should be free.\n\nIf you can afford it right now, I'd appreciate your support. Otherwise, just enjoy using the app – that's totally fine.";
"support.small" = "Small Gesture";
"support.medium" = "Nice Gesture";
"support.large" = "Big Gesture";
"support.thankyou.title" = "Thank You!";
"support.thankyou.message" = "Your support means a lot to me and helps keep this app going. Thank you!";
"support.footer" = "All purchases are one-time.";
"support.unavailable" = "Unavailable";
"support.unavailable.description" = "Support options could not be loaded";
"support.error" = "Error";
"support.error.unverified" = "Purchase could not be verified";
"support.error.pending" = "Purchase is being processed";
"support.reminder.title" = "Enjoying ValetudiOS?";
"support.reminder.message" = "This app is free and ad-free. It was built with love.\n\nSoftware should be free. If you can afford it, please consider supporting the development. Otherwise, just keep using the app – that's totally okay!";
"support.reminder.support" = "Happy to Support";
"support.reminder.already" = "Already Did";
"support.reminder.later" = "Not Now";
```

## Wichtig

- **Bundle ID Prefix:** `de.godsapp.valetudoapp` (NICHT insightflow!)
- **App-Name in Texten:** "ValetudiOS" (NICHT PrivacyFlow)
- **Design identisch:** Gleiche SF Symbols, gleiche Farben, gleiches Layout
- **StoreKit 2:** Kein StoreKit 1 — direkt `Product.products(for:)` und `product.purchase()`
- **Keine externen Dependencies**
- **iOS 18+ / Swift 6.0 / SwiftUI**

## Referenz-Dateien

Die vollständige Implementierung in PrivacyFlow liegt hier:
- `/Users/simonluthe/Documents/umami/InsightFlow/Services/SupportManager.swift`
- `/Users/simonluthe/Documents/umami/InsightFlow/Views/Settings/SupportView.swift`
- `/Users/simonluthe/Documents/umami/InsightFlow/Views/Settings/SupportReminderView.swift`
