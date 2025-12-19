//
//  Subscription.swift
//  CreditCardBenefits
//
//  Created for Credit Card Benefits Tracker POC
//

import Foundation

enum SubscriptionFrequency: String, Codable {
    case monthly
    case quarterly
    case annual
}

enum SubscriptionCategory: String, Codable, CaseIterable {
    case streaming
    case fitness
    case food
    case software
    case other

    var displayName: String {
        rawValue.capitalized
    }
}

struct Subscription: Identifiable, Codable {
    let id: String
    let merchant: String
    let amount: Double
    let frequency: SubscriptionFrequency
    let lastCharged: Date
    let nextCharge: Date?
    let category: SubscriptionCategory
    let transactions: [Transaction]

    var monthlyAmount: Double {
        switch frequency {
        case .monthly:
            return amount
        case .quarterly:
            return amount / 3.0
        case .annual:
            return amount / 12.0
        }
    }

    var annualAmount: Double {
        return monthlyAmount * 12.0
    }

    var frequencyDisplay: String {
        switch frequency {
        case .monthly: return "/mo"
        case .quarterly: return "/qtr"
        case .annual: return "/yr"
        }
    }

    var lastChargedString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: lastCharged)
    }
}
