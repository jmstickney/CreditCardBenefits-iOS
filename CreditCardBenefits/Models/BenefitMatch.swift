//
//  BenefitMatch.swift
//  CreditCardBenefits
//
//  Created for Credit Card Benefits Tracker POC
//

import Foundation

enum BenefitStatus: String, Codable {
    case available
    case maximized
    case partial
}

struct BenefitMatch: Identifiable, Codable {
    let id: UUID
    let subscription: Subscription
    let benefit: CreditCardBenefit
    let card: CreditCard
    let potentialSavings: Double
    let status: BenefitStatus

    init(subscription: Subscription, benefit: CreditCardBenefit, card: CreditCard,
         potentialSavings: Double, status: BenefitStatus, id: UUID = UUID()) {
        self.id = id
        self.subscription = subscription
        self.benefit = benefit
        self.card = card
        self.potentialSavings = potentialSavings
        self.status = status
    }
}

struct UserStats: Codable {
    let totalSubscriptions: Int
    let monthlySubscriptionCost: Double
    let annualSubscriptionCost: Double
    let potentialSavings: Double
    let activeCards: Int
    let totalAnnualFees: Double
    let totalBenefitsValue: Double

    // NEW: Utilization tracking
    let totalBenefitsUtilized: Double      // Actual value claimed/used
    let utilizationPercentage: Double      // % of benefits used
    let benefitsExpiringSoon: Int          // Count expiring in 30 days
    let benefitsRequiringAction: Int       // Need enrollment/manual claim

    // MARK: - Computed Properties

    /// Net value based on potential benefits
    var netValue: Double {
        totalBenefitsValue - totalAnnualFees
    }

    /// Net value based on actual utilization
    var actualNetValue: Double {
        totalBenefitsUtilized - totalAnnualFees
    }

    var isNetPositive: Bool {
        netValue >= 0
    }

    /// Whether the user has broken even based on actual usage
    var hasActuallyBrokenEven: Bool {
        actualNetValue >= 0
    }

    /// Amount needed to break even
    var amountToBreakEven: Double {
        max(0, totalAnnualFees - totalBenefitsUtilized)
    }

    /// Status message for the user
    var statusMessage: String {
        if hasActuallyBrokenEven {
            return "You're winning!"
        } else if utilizationPercentage > 0.5 {
            return "Almost there!"
        } else if utilizationPercentage > 0 {
            return "Keep going"
        } else {
            return "Get started"
        }
    }

    // MARK: - Initializers

    /// Full initializer with all fields
    init(
        totalSubscriptions: Int,
        monthlySubscriptionCost: Double,
        annualSubscriptionCost: Double,
        potentialSavings: Double,
        activeCards: Int,
        totalAnnualFees: Double,
        totalBenefitsValue: Double,
        totalBenefitsUtilized: Double = 0,
        utilizationPercentage: Double = 0,
        benefitsExpiringSoon: Int = 0,
        benefitsRequiringAction: Int = 0
    ) {
        self.totalSubscriptions = totalSubscriptions
        self.monthlySubscriptionCost = monthlySubscriptionCost
        self.annualSubscriptionCost = annualSubscriptionCost
        self.potentialSavings = potentialSavings
        self.activeCards = activeCards
        self.totalAnnualFees = totalAnnualFees
        self.totalBenefitsValue = totalBenefitsValue
        self.totalBenefitsUtilized = totalBenefitsUtilized
        self.utilizationPercentage = utilizationPercentage
        self.benefitsExpiringSoon = benefitsExpiringSoon
        self.benefitsRequiringAction = benefitsRequiringAction
    }
}
