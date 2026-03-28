import Foundation
import StoreKit
import SwiftUI

@MainActor
class SupportManager: ObservableObject {
    static let shared = SupportManager()

    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var purchaseError: String?
    @Published var showThankYou = false

    // Support reminder tracking
    @AppStorage("supportReminderShown") private var reminderShown = false
    @AppStorage("hasSupported") private var hasSupported = false
    @AppStorage("appLaunchCount") private var launchCount = 0

    // Product IDs - diese müssen in App Store Connect erstellt werden
    private let productIds = [
        "de.godsapp.valetudoapp.support.small",   // 0,99€
        "de.godsapp.valetudoapp.support.medium",  // 2,99€
        "de.godsapp.valetudoapp.support.large"    // 5,99€
    ]

    private init() {}

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: productIds)
                .sorted { $0.price < $1.price }
        } catch {
            #if DEBUG
            print("Failed to load products: \(error)")
            #endif
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    hasSupported = true
                    showThankYou = true
                case .unverified:
                    purchaseError = String(localized: "support.error.unverified")
                }
            case .userCancelled:
                break
            case .pending:
                purchaseError = String(localized: "support.error.pending")
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Support Reminder

    func incrementLaunchCount() {
        launchCount += 1
    }

    var shouldShowReminder: Bool {
        // Show after 5 launches, only once, and only if not already supported
        return launchCount >= 5 && !reminderShown && !hasSupported
    }

    func markReminderShown() {
        reminderShown = true
    }

    func markAlreadySupported() {
        hasSupported = true
        reminderShown = true
    }
}

// MARK: - Support Product Extensions

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
