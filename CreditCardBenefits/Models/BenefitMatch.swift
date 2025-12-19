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

struct BenefitMatch: Identifiable {
    let id = UUID()
    let subscription: Subscription
    let benefit: CreditCardBenefit
    let card: CreditCard
    let potentialSavings: Double
    let status: BenefitStatus
}

struct UserStats {
    let totalSubscriptions: Int
    let monthlySubscriptionCost: Double
    let annualSubscriptionCost: Double
    let potentialSavings: Double
    let activeCards: Int
}
