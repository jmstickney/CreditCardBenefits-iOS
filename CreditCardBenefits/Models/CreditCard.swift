//
//  CreditCard.swift
//  CreditCardBenefits
//
//  Created for Credit Card Benefits Tracker POC
//

import Foundation

enum CardIssuer: String, Codable {
    case amex
    case chase
    case capitalOne = "capital-one"
    case citi
    case usBank = "us-bank"
    case other
}

enum BenefitType: String, Codable {
    case subscriptionCredit = "subscription_credit"
    case diningCredit = "dining_credit"
    case travelCredit = "travel_credit"
    case cashback
}

enum BenefitFrequency: String, Codable {
    case monthly
    case annual
    case perTransaction = "per-transaction"
}

struct CreditCardBenefit: Identifiable, Codable {
    let id: String
    let type: BenefitType
    let name: String
    let description: String
    let amount: Double
    let frequency: BenefitFrequency
    let eligibleMerchants: [String]?
    let category: String?
    let conditions: String?

    var monthlyAmount: Double {
        switch frequency {
        case .monthly:
            return amount
        case .annual:
            return amount / 12.0
        case .perTransaction:
            return amount
        }
    }

    var annualAmount: Double {
        switch frequency {
        case .monthly:
            return amount * 12.0
        case .annual:
            return amount
        case .perTransaction:
            return amount * 12.0 // Simplified assumption
        }
    }

    var frequencyDisplay: String {
        switch frequency {
        case .monthly: return "/mo"
        case .annual: return "/yr"
        case .perTransaction: return "/transaction"
        }
    }
}

struct CreditCard: Identifiable, Codable {
    let id: String
    let name: String
    let issuer: CardIssuer
    let benefits: [CreditCardBenefit]
}
