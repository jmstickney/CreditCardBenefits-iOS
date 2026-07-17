//
//  MissedBenefitDetector.swift
//  CreditCardBenefits
//
//  Detects purchases made on the "wrong" card: spend at a benefit-eligible
//  merchant charged to a card that doesn't carry the benefit, while another
//  connected card does (e.g. paying for Uber One on Chase when the Amex
//  Platinum's Uber credit would cover it). Detection is after-the-fact — the
//  value is switching cards for future periods, especially monthly/quarterly
//  credits.
//

import Foundation

// MARK: - Model

struct MissedBenefitOpportunity: Identifiable, Equatable {
    /// Stable identity: benefitId|coveringCardId|merchantToken. Also the key
    /// persisted when the user dismisses the suggestion (forever).
    let key: String
    let benefit: CreditCardBenefit
    let coveringCard: CreditCard
    /// Display name of the merchant (Plaid-cleaned when available).
    let merchantDisplayName: String
    /// Names of the card(s) the purchases were actually made on.
    let paidCardNames: [String]
    let matchedTransactions: [Transaction]
    let latestDate: Date

    var id: String { key }

    static func == (lhs: MissedBenefitOpportunity, rhs: MissedBenefitOpportunity) -> Bool {
        lhs.key == rhs.key &&
        lhs.matchedTransactions.map(\.id) == rhs.matchedTransactions.map(\.id)
    }
}

// MARK: - Detector

enum MissedBenefitDetector {

    /// How far back to scan for wrong-card purchases.
    private static let lookbackDays = 90

    /// Ignore tiny charges (e.g. $1 card-verification/test charges) — alerting
    /// on them is technically accurate but not worth the interruption.
    private static let absoluteMinimumAmount: Double = 50

    /// A charge qualifies if it's at least $50 OR at least half the benefit's
    /// per-period value — so small recurring memberships (Walmart+ $12.95/mo,
    /// streaming subs) still flag, while trivial test charges never do.
    private static func minimumQualifyingAmount(for benefit: CreditCardBenefit) -> Double {
        min(absoluteMinimumAmount, benefit.amount * 0.5)
    }

    /// Convenience: derives the account→card mapping from confirmed CardMatches.
    static func detect(
        transactions: [Transaction],
        userCards: [CreditCard],
        cardMatches: [CardMatch],
        utilizations: [BenefitUtilization],
        dismissedKeys: Set<String>
    ) -> [MissedBenefitOpportunity] {
        var accountToCardId: [String: String] = [:]
        for match in cardMatches {
            if let cardId = match.creditCard?.id {
                accountToCardId[match.plaidAccount.id] = cardId
            }
        }
        return detect(
            transactions: transactions,
            userCards: userCards,
            accountToCardId: accountToCardId,
            utilizations: utilizations,
            dismissedKeys: dismissedKeys
        )
    }

    /// Finds current wrong-card opportunities. Pure function — persistence of
    /// dismissals/notifications is the caller's concern (pass dismissed keys in).
    static func detect(
        transactions: [Transaction],
        userCards: [CreditCard],
        accountToCardId: [String: String],
        utilizations: [BenefitUtilization],
        dismissedKeys: Set<String>
    ) -> [MissedBenefitOpportunity] {
        guard !userCards.isEmpty else { return [] }

        let cutoff = Calendar.current.date(
            byAdding: .day, value: -lookbackDays, to: Date()
        ) ?? .distantPast

        // Recent purchases only (credits are reimbursements, not spend).
        let recentPurchases = transactions.filter {
            !$0.isCredit && $0.date >= cutoff
        }

        // Group matches by (benefit, covering card, merchant token).
        var groups: [String: (benefit: CreditCardBenefit,
                              card: CreditCard,
                              txns: [Transaction],
                              paidCards: Set<String>)] = [:]

        for txn in recentPurchases {
            // Unmapped accounts can't be judged; skip.
            guard let paidCardId = accountToCardId[txn.accountId] else { continue }

            for coveringCard in userCards where coveringCard.id != paidCardId {
                for benefit in coveringCard.benefits {
                    // In-app credits (Uber Cash, DoorDash promos, Lyft…) can't
                    // be captured by swiping a different card, so only
                    // auto-detect (statement-credit) benefits can be "missed".
                    guard benefit.canAutoDetect else { continue }

                    // Skip trivial charges (e.g. $1 test/verification charges).
                    guard txn.amount >= minimumQualifyingAmount(for: benefit) else {
                        continue
                    }

                    guard let token = matchedMerchantToken(txn, benefit: benefit) else {
                        continue
                    }

                    // Fully-used benefits offer no value this period; skip.
                    if isCurrentPeriodFullyUtilized(
                        benefitId: benefit.id,
                        cardId: coveringCard.id,
                        utilizations: utilizations
                    ) {
                        continue
                    }

                    let key = "\(benefit.id)|\(coveringCard.id)|\(token)"
                    if dismissedKeys.contains(key) { continue }

                    let paidCardName = userCards.first { $0.id == paidCardId }?.name
                        ?? CreditCardsData.getCard(by: paidCardId)?.name
                        ?? "another card"

                    var group = groups[key] ?? (benefit, coveringCard, [], [])
                    group.txns.append(txn)
                    group.paidCards.insert(paidCardName)
                    groups[key] = group
                }
            }
        }

        return groups.map { key, group in
            let sorted = group.txns.sorted { $0.date > $1.date }

            // Display name: for AND-group matches the matched tokens are more
            // precise than Plaid's cleaned merchant_name (e.g. "uber+one" →
            // "Uber One", where Plaid just says "Uber" — which would blur the
            // line between Uber One and Uber Cash). Otherwise fall back to
            // Plaid's cleaned name, then the raw descriptor.
            let display: String
            if let token = key.components(separatedBy: "|").last, token.contains("+") {
                display = token
                    .split(separator: "+")
                    .map { String($0).capitalized }
                    .joined(separator: " ")
            } else {
                display = sorted.first?.merchantName
                    ?? sorted.first?.merchant
                    ?? "Merchant"
            }

            return MissedBenefitOpportunity(
                key: key,
                benefit: group.benefit,
                coveringCard: group.card,
                merchantDisplayName: display,
                paidCardNames: group.paidCards.sorted(),
                matchedTransactions: sorted,
                latestDate: sorted.first?.date ?? Date()
            )
        }
        .sorted { $0.latestDate > $1.latestDate }
    }

    /// Merchant-only matching (categories like "Travel" are far too broad for
    /// wrong-card suggestions). Same one-directional substring rule as
    /// BenefitUtilizationService: the eligible token must appear inside the
    /// transaction's merchant string. Returns the matched token (lowercased)
    /// for stable grouping/dismissal, or nil when there's no match.
    private static func matchedMerchantToken(
        _ transaction: Transaction,
        benefit: CreditCardBenefit
    ) -> String? {
        var names = [transaction.merchant.lowercased()]
        if let cleaned = transaction.merchantName?.lowercased() {
            names.append(cleaned)
        }

        if let merchants = benefit.eligibleMerchants {
            for eligible in merchants {
                let token = eligible.lowercased()
                if names.contains(where: { $0.contains(token) }) {
                    return token
                }
            }
        }

        // AND-groups: all tokens in a group must appear. Group key joined with
        // "+" for stable grouping/dismissal (e.g. "uber+one").
        if let allOfGroups = benefit.eligibleMerchantsAllOf {
            for group in allOfGroups {
                let tokens = group.map { $0.lowercased() }
                if names.contains(where: { name in
                    tokens.allSatisfy { name.contains($0) }
                }) {
                    return tokens.joined(separator: "+")
                }
            }
        }

        return nil
    }

    private static func isCurrentPeriodFullyUtilized(
        benefitId: String,
        cardId: String,
        utilizations: [BenefitUtilization]
    ) -> Bool {
        let now = Date()
        guard let current = utilizations.first(where: {
            $0.benefitId == benefitId && $0.cardId == cardId &&
            $0.periodStart <= now && now <= $0.periodEnd
        }) else { return false }
        return current.totalValue > 0 && current.amountUtilized >= current.totalValue
    }
}
