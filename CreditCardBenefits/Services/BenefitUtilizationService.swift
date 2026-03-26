//
//  BenefitUtilizationService.swift
//  CreditCardBenefits
//
//  Tracks and calculates benefit utilization from transactions
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

class BenefitUtilizationService: ObservableObject {
    @Published var utilizations: [BenefitUtilization] = []
    @Published var isLoading = false

    private let db = Firestore.firestore()

    // MARK: - Load Utilizations

    /// Loads all utilizations for the current user from Firestore
    func loadUtilizations(for userId: String) async {
        await MainActor.run {
            isLoading = true
        }

        do {
            let snapshot = try await db
                .collection("users")
                .document(userId)
                .collection("benefitUtilizations")
                .getDocuments()

            var loadedUtilizations: [BenefitUtilization] = []

            for doc in snapshot.documents {
                if let utilization = try? doc.data(as: BenefitUtilization.self) {
                    loadedUtilizations.append(utilization)
                }
            }

            await MainActor.run {
                self.utilizations = loadedUtilizations
                self.isLoading = false
            }

            print("✅ Loaded \(loadedUtilizations.count) benefit utilizations")

        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            print("❌ Error loading utilizations: \(error.localizedDescription)")
        }
    }

    // MARK: - Process Transactions

    /// Processes transactions to calculate benefit utilization
    func processTransactions(
        _ transactions: [Transaction],
        userCards: [CreditCard],
        userId: String,
        cardMatches: [CardMatch] = []
    ) async -> [BenefitUtilization] {
        var newUtilizations: [BenefitUtilization] = []

        for card in userCards {
            // Find which Plaid account(s) map to this card and get anniversary date
            let matchesForCard = cardMatches.filter { $0.creditCard?.id == card.id }
            let accountIds = matchesForCard.map { $0.plaidAccount.id }
            let anniversaryDate = matchesForCard.first?.anniversaryDate
            
            // Filter transactions to only those from this card's accounts
            let cardTransactions = transactions.filter { accountIds.contains($0.accountId) }
            
            for benefit in card.benefits where benefit.canAutoDetect {
                // Get current period for this benefit, passing anniversary date if available
                let (periodStart, periodEnd) = BenefitPeriodHelper.currentPeriod(
                    for: benefit.period,
                    cardAnniversaryDate: anniversaryDate
                )

                // Find matching transactions within this period (only from this card)
                let matchingTransactions = findMatchingTransactions(
                    cardTransactions,
                    for: benefit,
                    in: periodStart...periodEnd
                )

                // Calculate total utilized amount
                let totalUtilized = matchingTransactions.reduce(0.0) { $0 + $1.amount }
                let cappedUtilized = min(totalUtilized, benefit.annualAmount)

                // Get or create utilization record
                let existingUtilization = utilizations.first {
                    $0.benefitId == benefit.id &&
                    $0.cardId == card.id &&
                    $0.periodStart == periodStart
                }

                let utilization = BenefitUtilization(
                    id: existingUtilization?.id ?? UUID().uuidString,
                    benefitId: benefit.id,
                    cardId: card.id,
                    userId: userId,
                    periodStart: periodStart,
                    periodEnd: periodEnd,
                    periodType: benefit.period,
                    totalValue: BenefitPeriodHelper.periodValue(for: benefit, periodStart: periodStart, periodEnd: periodEnd),
                    amountUtilized: cappedUtilized,
                    matchedTransactionIds: matchingTransactions.map { $0.id },
                    isManuallyMarked: existingUtilization?.isManuallyMarked ?? false,
                    manualNote: existingUtilization?.manualNote,
                    manualClaimDate: existingUtilization?.manualClaimDate,
                    createdAt: existingUtilization?.createdAt ?? Date(),
                    updatedAt: Date()
                )

                newUtilizations.append(utilization)
            }

            // Also create records for non-auto-detect benefits (so they show in UI)
            for benefit in card.benefits where !benefit.canAutoDetect {
                let (periodStart, periodEnd) = BenefitPeriodHelper.currentPeriod(for: benefit.period)

                let existingUtilization = utilizations.first {
                    $0.benefitId == benefit.id &&
                    $0.cardId == card.id &&
                    $0.periodStart == periodStart
                }

                let utilization = BenefitUtilization(
                    id: existingUtilization?.id ?? UUID().uuidString,
                    benefitId: benefit.id,
                    cardId: card.id,
                    userId: userId,
                    periodStart: periodStart,
                    periodEnd: periodEnd,
                    periodType: benefit.period,
                    totalValue: BenefitPeriodHelper.periodValue(for: benefit, periodStart: periodStart, periodEnd: periodEnd),
                    amountUtilized: existingUtilization?.amountUtilized ?? 0,
                    matchedTransactionIds: existingUtilization?.matchedTransactionIds ?? [],
                    isManuallyMarked: existingUtilization?.isManuallyMarked ?? false,
                    manualNote: existingUtilization?.manualNote,
                    manualClaimDate: existingUtilization?.manualClaimDate,
                    createdAt: existingUtilization?.createdAt ?? Date(),
                    updatedAt: Date()
                )

                newUtilizations.append(utilization)
            }
        }

        await MainActor.run {
            self.utilizations = newUtilizations
        }

        return newUtilizations
    }

    // MARK: - Find Matching Transactions

    /// Finds transactions that match a benefit's eligible merchants or categories
    private func findMatchingTransactions(
        _ transactions: [Transaction],
        for benefit: CreditCardBenefit,
        in dateRange: ClosedRange<Date>
    ) -> [Transaction] {
        transactions.filter { transaction in
            // Check date range
            guard dateRange.contains(transaction.date) else { return false }
            
            // Filter by transaction type (credit vs purchase)
            // If benefit expects credits, only match credit transactions
            // If benefit expects purchases, only match purchase transactions
            if benefit.matchCreditTransactions != transaction.isCredit {
                return false
            }

            // Strategy 1: Merchant name matching
            if let merchants = benefit.eligibleMerchants {
                let normalizedMerchant = transaction.merchant.lowercased()
                if merchants.contains(where: { eligible in
                    let normalizedEligible = eligible.lowercased()
                    return normalizedMerchant.contains(normalizedEligible) ||
                           normalizedEligible.contains(normalizedMerchant)
                }) {
                    return true
                }
            }

            // Strategy 2: Category matching
            if let categories = benefit.eligibleCategories,
               let txCategory = transaction.category {
                let normalizedCategory = txCategory.lowercased()
                if categories.contains(where: { eligible in
                    normalizedCategory.contains(eligible.lowercased())
                }) {
                    return true
                }
            }

            return false
        }
    }

    // MARK: - Manual Claim

    /// Manually marks a benefit as used
    func markBenefitUsed(
        benefitId: String,
        cardId: String,
        amount: Double,
        note: String?,
        userId: String
    ) async throws {
        guard let benefit = CreditCardsData.getBenefit(by: benefitId) else {
            throw UtilizationError.benefitNotFound
        }

        let (periodStart, periodEnd) = BenefitPeriodHelper.currentPeriod(for: benefit.period)

        // Find or create utilization
        var utilization: BenefitUtilization
        if let existing = utilizations.first(where: {
            $0.benefitId == benefitId &&
            $0.cardId == cardId &&
            $0.periodStart == periodStart
        }) {
            utilization = existing
            utilization.amountUtilized = min(utilization.amountUtilized + amount, utilization.totalValue)
        } else {
            utilization = BenefitUtilization(
                benefitId: benefitId,
                cardId: cardId,
                userId: userId,
                periodStart: periodStart,
                periodEnd: periodEnd,
                periodType: benefit.period,
                totalValue: BenefitPeriodHelper.periodValue(for: benefit, periodStart: periodStart, periodEnd: periodEnd),
                amountUtilized: amount
            )
        }

        utilization.isManuallyMarked = true
        utilization.manualNote = note
        utilization.manualClaimDate = Date()
        utilization.updatedAt = Date()

        // Save to Firestore
        try await saveUtilization(utilization, userId: userId)

        // Update local state
        await MainActor.run {
            if let index = self.utilizations.firstIndex(where: { $0.id == utilization.id }) {
                self.utilizations[index] = utilization
            } else {
                self.utilizations.append(utilization)
            }
        }

        print("✅ Marked benefit \(benefitId) as used: $\(amount)")
    }

    // MARK: - Save Utilization

    /// Saves a utilization record to Firestore
    func saveUtilization(_ utilization: BenefitUtilization, userId: String) async throws {
        try await db
            .collection("users")
            .document(userId)
            .collection("benefitUtilizations")
            .document(utilization.id)
            .setData(try Firestore.Encoder().encode(utilization))

        print("✅ Saved utilization \(utilization.id)")
    }

    /// Saves all utilizations to Firestore
    func saveAllUtilizations(userId: String) async throws {
        let batch = db.batch()

        for utilization in utilizations {
            let docRef = db
                .collection("users")
                .document(userId)
                .collection("benefitUtilizations")
                .document(utilization.id)

            try batch.setData(from: utilization, forDocument: docRef)
        }

        try await batch.commit()
        print("✅ Saved \(utilizations.count) utilizations")
    }

    // MARK: - Computed Stats

    /// Gets total utilized value across all benefits
    var totalUtilized: Double {
        utilizations.reduce(0) { $0 + $1.amountUtilized }
    }

    /// Gets total potential value across all benefits
    var totalPotentialValue: Double {
        utilizations.reduce(0) { $0 + $1.totalValue }
    }

    /// Gets overall utilization percentage
    var overallUtilizationPercentage: Double {
        guard totalPotentialValue > 0 else { return 0 }
        return totalUtilized / totalPotentialValue
    }

    /// Gets benefits that are expiring soon (within 30 days)
    var benefitsExpiringSoon: [BenefitUtilization] {
        utilizations.filter { $0.isExpiringSoon }
    }

    /// Gets benefits that need manual action
    var benefitsRequiringAction: [BenefitUtilization] {
        utilizations.filter { utilization in
            guard let benefit = CreditCardsData.getBenefit(by: utilization.benefitId) else {
                return false
            }
            return !benefit.canAutoDetect && utilization.amountUtilized == 0
        }
    }

    /// Gets utilization for a specific card
    func utilizationsForCard(_ cardId: String) -> [BenefitUtilization] {
        utilizations.filter { $0.cardId == cardId }
    }

    /// Gets utilization for a specific benefit
    func utilizationForBenefit(_ benefitId: String, cardId: String) -> BenefitUtilization? {
        utilizations.first { $0.benefitId == benefitId && $0.cardId == cardId }
    }

    /// Clears all utilization data
    func clearAllUtilizations() {
        utilizations.removeAll()
    }
}

// MARK: - Errors

enum UtilizationError: Error, LocalizedError {
    case benefitNotFound
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .benefitNotFound:
            return "Benefit not found"
        case .saveFailed(let message):
            return "Failed to save: \(message)"
        }
    }
}
