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

            benLog("✅ Loaded \(loadedUtilizations.count) benefit utilizations")

        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            benLog("❌ Error loading utilizations: \(error.localizedDescription)")
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
                // Get all periods that span the transaction history, not just the current one
                let earliestDate = cardTransactions.map { $0.date }.min() ?? Date()
                let periods = BenefitPeriodHelper.allPeriods(
                    for: benefit.period,
                    from: earliestDate,
                    cardAnniversaryDate: anniversaryDate
                )

                for (periodStart, periodEnd) in periods {
                    // Find matching transactions within this period (only from this card)
                    let matchingTransactions = findMatchingTransactions(
                        cardTransactions,
                        for: benefit,
                        in: periodStart...periodEnd
                    )

                    // Calculate total utilized amount
                    let totalUtilized = matchingTransactions.reduce(0.0) { $0 + $1.amount }
                    let periodValue = BenefitPeriodHelper.periodValue(for: benefit, periodStart: periodStart, periodEnd: periodEnd)
                    let cappedUtilized = min(totalUtilized, periodValue)

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
                        totalValue: periodValue,
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
            
            // Filter by transaction type (credit vs purchase).
            //
            // A statement-credit benefit (matchCreditTransactions) is only
            // actually "used" when the issuer posts the reimbursement, which
            // Plaid reports as a credit/inflow (isCredit == true). A normal
            // purchase at the same merchant is a debit and must NOT count —
            // counting purchases was silently inflating utilization (e.g. an
            // ordinary Walmart or Disney+ purchase being booked against the
            // Walmart+ / Digital Entertainment credit). Purchase-matching
            // benefits, conversely, only count purchases — never credits/refunds.
            if benefit.matchCreditTransactions {
                if !transaction.isCredit { return false }
            } else if transaction.isCredit {
                return false
            }

            // Strategy 1: Merchant name matching (check both name and merchant_name from Plaid)
            // One-directional: the eligible pattern must appear as a substring of the
            // transaction merchant. The reverse direction (eligible.contains(merchant))
            // caused false positives, e.g. eligible "STUBHUB CREDIT $300/YEAR" matching
            // a regular "STUBHUB" merchant purchase.
            let merchantNames = [transaction.merchant.lowercased()] + (transaction.merchantName.map { [$0.lowercased()] } ?? [])

            if let merchants = benefit.eligibleMerchants {
                for normalizedMerchant in merchantNames {
                    if merchants.contains(where: { eligible in
                        normalizedMerchant.contains(eligible.lowercased())
                    }) {
                        return true
                    }
                }
            }

            // Strategy 1b: AND-groups — every token in a group must appear
            // (e.g. ["uber","one"] matches "UBER *ONE MEMBERSHIP", not "UBER TRIP").
            if let allOfGroups = benefit.eligibleMerchantsAllOf {
                for normalizedMerchant in merchantNames {
                    if allOfGroups.contains(where: { group in
                        group.allSatisfy { normalizedMerchant.contains($0.lowercased()) }
                    }) {
                        return true
                    }
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

        benLog("✅ Marked benefit \(benefitId) as used: $\(amount)")
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

        benLog("✅ Saved utilization \(utilization.id)")
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
        benLog("✅ Saved \(utilizations.count) utilizations")
    }

    // MARK: - Computed Stats

    /// Total benefits used so far this year. Rolls monthly periods up to YTD and
    /// counts the current-period record for annual / cardmember-year / one-time benefits.
    /// Avoids the multi-period double-counting that a naive sum would produce.
    var totalUtilized: Double {
        BenefitPeriodHelper.yearToDateUtilized(utilizations)
    }

    /// Gets total potential value across all benefits (current period only).
    var totalPotentialValue: Double {
        let now = Date()
        return utilizations
            .filter { $0.periodStart <= now && now <= $0.periodEnd }
            .reduce(0) { $0 + $1.totalValue }
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

    /// Gets utilization for a specific benefit (prefers the current period, falls back to most recent)
    func utilizationForBenefit(_ benefitId: String, cardId: String) -> BenefitUtilization? {
        let matching = utilizations.filter { $0.benefitId == benefitId && $0.cardId == cardId }
        let now = Date()
        if let current = matching.first(where: { $0.periodStart <= now && now <= $0.periodEnd }) {
            return current
        }
        return matching.sorted(by: { $0.periodStart > $1.periodStart }).first
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
