//
//  SubscriptionManager.swift
//  CreditCardBenefits
//
//  StoreKit 2 subscription state + purchase/restore for Ben's monthly plan.
//

import Foundation
import Combine
import StoreKit
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class SubscriptionManager: ObservableObject {

    /// Auto-renewable subscription configured in App Store Connect
    /// ($4.99/month with a 7-day free introductory offer).
    static let productId = "com.jstick.CreditCardBenefits.monthly"

    @Published private(set) var product: Product?
    @Published private(set) var isSubscribed = false
    /// False until the first entitlement check completes. Gate UI (paywall
    /// covers) should wait for this to avoid flashing over the app at launch.
    @Published private(set) var hasLoadedEntitlements = false
    @Published private(set) var isPurchasing = false

    private var updatesTask: Task<Void, Never>?

    init() {
        // React to renewals, cancellations, refunds, Ask to Buy approvals, and
        // purchases made outside the app (e.g. redeem codes).
        // NOTE: StoreKit.Transaction is fully qualified throughout — the app
        // has its own `Transaction` model (Plaid) that shadows it.
        updatesTask = Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                if let transaction = try? update.payloadValue {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }

        Task {
            await loadProduct()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Product

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productId]).first
            if product == nil {
                benLog("⚠️ StoreKit: product \(Self.productId) not found")
            }
        } catch {
            benLog("❌ StoreKit product load failed: \(error)")
        }
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        var active = false
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == Self.productId,
               transaction.revocationDate == nil {
                active = true
            }
        }
        isSubscribed = active
        hasLoadedEntitlements = true
        benLog("💳 Subscription status: \(active ? "active" : "not subscribed")")
        reportStatusToServer()
    }

    /// Mirrors subscription state onto the user's Firestore doc so the backend
    /// cleanup cron can spare subscribers' Plaid items (non-subscribers'
    /// connections are removed after ~7 days to control Plaid costs).
    private func reportStatusToServer() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(uid).setData([
            "subscriptionActive": isSubscribed,
            "subscriptionUpdatedAt": FieldValue.serverTimestamp(),
        ], merge: true) { error in
            if let error {
                benLog("⚠️ Failed to report subscription status: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Purchase / Restore

    /// Purchases the subscription. Returns true when the user ends up entitled
    /// (false on cancel/pending).
    @discardableResult
    func purchase() async throws -> Bool {
        var product = self.product
        if product == nil {
            await loadProduct()
            product = self.product
        }
        guard let product else { throw SubscriptionError.productUnavailable }

        isPurchasing = true
        defer { isPurchasing = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verification.payloadValue
            await transaction.finish()
            await refreshEntitlements()
            return isSubscribed
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// Restores previous purchases; returns whether an active subscription was found.
    @discardableResult
    func restore() async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        try await AppStore.sync()
        await refreshEntitlements()
        return isSubscribed
    }
}

enum SubscriptionError: LocalizedError {
    case productUnavailable

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "The subscription isn't available right now. Please try again in a moment."
        }
    }
}
