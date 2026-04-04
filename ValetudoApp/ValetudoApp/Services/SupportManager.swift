import Foundation
import os
import StoreKit
import SwiftUI
import Observation

@MainActor
@Observable
class SupportManager {
    static let shared = SupportManager()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ValetudiOS", category: "SupportManager")

    var products: [Product] = []
    var isLoading = false
    var purchaseError: String?
    var showThankYou = false

    // Support reminder tracking
    @ObservationIgnored
    @AppStorage("supportReminderShown") private var reminderShown = false
    @ObservationIgnored
    @AppStorage("hasSupported") private var hasSupported = false
    @ObservationIgnored
    @AppStorage("appLaunchCount") private var launchCount = 0

    private init() {}

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let loaded = try await Product.products(for: Constants.supportProductIds)
                .sorted { $0.price < $1.price }
            products = loaded

            // DEBT-07: Validiere dass alle konfigurierten Product IDs geladen wurden
            let loadedIds = Set(loaded.map { $0.id })
            let missingIds = Constants.supportProductIds.subtracting(loadedIds)
            if !missingIds.isEmpty {
                logger.error("StoreKit Product IDs not found in App Store: \(missingIds.sorted().joined(separator: ", "), privacy: .public)")
            }
            let unexpectedIds = loadedIds.subtracting(Constants.supportProductIds)
            if !unexpectedIds.isEmpty {
                logger.warning("StoreKit returned unexpected Product IDs: \(unexpectedIds.sorted().joined(separator: ", "), privacy: .public)")
            }
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription, privacy: .public)")
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
        case Constants.supportSmallId: return "cup.and.saucer.fill"
        case Constants.supportMediumId: return "gift.fill"
        case Constants.supportLargeId: return "sparkles"
        default: return "heart.fill"
        }
    }

    var tierColor: Color {
        switch id {
        case Constants.supportSmallId: return .blue
        case Constants.supportMediumId: return .purple
        case Constants.supportLargeId: return .orange
        default: return .accentColor
        }
    }

    var supportName: String {
        switch id {
        case Constants.supportSmallId:
            return String(localized: "support.small")
        case Constants.supportMediumId:
            return String(localized: "support.medium")
        case Constants.supportLargeId:
            return String(localized: "support.large")
        default:
            return displayName
        }
    }
}
