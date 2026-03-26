//
//  BenefitMatcher.swift
//  CreditCardBenefits
//
//  Created for Credit Card Benefits Tracker POC
//

import Foundation

enum BenefitMatcherError: LocalizedError {
    case invalidSubscriptionData
    case invalidCardData
    case calculationError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidSubscriptionData:
            return "Invalid subscription data provided"
        case .invalidCardData:
            return "Invalid card data provided"
        case .calculationError(let message):
            return "Calculation error: \(message)"
        }
    }
}

class BenefitMatcher {

    // Match subscriptions with credit card benefits
    static func matchBenefits(
        subscriptions: [Subscription],
        userCards: [CreditCard]
    ) throws -> [BenefitMatch] {
        guard !userCards.isEmpty else {
            throw BenefitMatcherError.invalidCardData
        }
        
        var matches: [BenefitMatch] = []

        for subscription in subscriptions {
            guard subscription.amount > 0 else {
                continue // Skip invalid subscriptions
            }
            
            for card in userCards {
                for benefit in card.benefits {
                    // Check if subscription category matches benefit
                    let categoryMatch = benefit.category == subscription.category.rawValue ||
                                       benefit.type == .subscriptionCredit

                    guard categoryMatch else { continue }

                    // Check if merchant matches eligible merchants
                    if isMerchantEligible(subscription.merchant, for: benefit) {
                        do {
                            let savings = try calculateSavings(subscription: subscription, benefit: benefit)
                            let status = determineBenefitStatus(subscription: subscription, benefit: benefit)

                            let match = BenefitMatch(
                                subscription: subscription,
                                benefit: benefit,
                                card: card,
                                potentialSavings: savings,
                                status: status
                            )

                            matches.append(match)
                        } catch {
                            // Log but continue processing other matches
                            print("⚠️ Failed to calculate savings for \(subscription.merchant): \(error)")
                            continue
                        }
                    }
                }
            }
        }

        // Sort by potential savings (highest first)
        return matches.sorted { $0.potentialSavings > $1.potentialSavings }
    }

    // Check if merchant is eligible for benefit
    private static func isMerchantEligible(_ merchant: String, for benefit: CreditCardBenefit) -> Bool {
        guard let eligibleMerchants = benefit.eligibleMerchants, !eligibleMerchants.isEmpty else {
            return false
        }

        let normalizedMerchant = merchant.lowercased()

        return eligibleMerchants.contains { eligible in
            let normalizedEligible = eligible.lowercased()
            return normalizedMerchant.contains(normalizedEligible) ||
                   normalizedEligible.contains(normalizedMerchant)
        }
    }

    // Calculate potential savings
    private static func calculateSavings(subscription: Subscription, benefit: CreditCardBenefit) throws -> Double {
        guard subscription.amount > 0, benefit.amount > 0 else {
            throw BenefitMatcherError.calculationError("Invalid amounts for calculation")
        }
        
        let benefitMonthly = benefit.monthlyAmount
        let subscriptionMonthly = subscription.monthlyAmount

        // Savings is the lesser of benefit amount or subscription cost
        let monthlySavings = min(benefitMonthly, subscriptionMonthly)

        // Return annual savings
        return round(monthlySavings * 12 * 100) / 100
    }

    // Determine if benefit is being utilized
    private static func determineBenefitStatus(subscription: Subscription, benefit: CreditCardBenefit) -> BenefitStatus {
        do {
            let savings = try calculateSavings(subscription: subscription, benefit: benefit)
            let benefitAnnual = benefit.annualAmount

            if savings >= benefitAnnual * 0.9 {
                return .maximized
            } else if savings >= benefitAnnual * 0.5 {
                return .partial
            }

            return .available
        } catch {
            // If calculation fails, default to available
            return .available
        }
    }

    // Calculate total potential savings
    static func calculateTotalSavings(_ matches: [BenefitMatch]) -> Double {
        // Group by benefit to avoid double-counting
        var uniqueBenefits: [String: Double] = [:]

        for match in matches {
            let key = "\(match.card.id)-\(match.benefit.id)"
            let existing = uniqueBenefits[key] ?? 0
            uniqueBenefits[key] = max(existing, match.potentialSavings)
        }

        return uniqueBenefits.values.reduce(0, +)
    }

    // Get unmatched subscriptions
    static func getUnmatchedSubscriptions(
        subscriptions: [Subscription],
        matches: [BenefitMatch]
    ) -> [Subscription] {
        let matchedIds = Set(matches.map { $0.subscription.id })
        return subscriptions.filter { !matchedIds.contains($0.id) }
    }
}
