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
    case rideshareCredit = "rideshare_credit"
    case airlineIncidental = "airline_incidental"
    case hotelCredit = "hotel_credit"
    case shoppingCredit = "shopping_credit"
    case enrollmentBenefit = "enrollment_benefit"
    case cashback
}

enum BenefitPeriod: String, Codable {
    case monthly              // Resets each month
    case calendarYear         // Jan 1 - Dec 31
    case cardmemberYear       // Resets on card anniversary
    case oneTime              // Doesn't reset (e.g., Global Entry every 4 years)
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

    // NEW: Period & reset logic
    let period: BenefitPeriod

    // NEW: Variable monthly amounts (e.g., Uber: $15/mo, $35 Dec)
    // Key is month number (1-12), value is amount for that month
    let monthlyAmounts: [Int: Double]?

    // NEW: Detection configuration
    let eligibleCategories: [String]?     // Plaid categories for matching
    let canAutoDetect: Bool               // Can we detect from transactions?
    let requiresEnrollment: Bool          // Must user opt-in?
    let enrollmentUrl: String?            // Where to enroll
    let matchCreditTransactions: Bool     // Match statement credits instead of purchases (default: false)

    // MARK: - Computed Properties

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

    /// Gets the benefit amount for a specific month (handles variable amounts like Uber December bonus)
    func amountForMonth(_ month: Int) -> Double {
        if let monthlyAmounts = monthlyAmounts, let specialAmount = monthlyAmounts[month] {
            return specialAmount
        }
        return amount
    }

    /// Total annual value considering variable monthly amounts
    var annualAmount: Double {
        switch frequency {
        case .monthly:
            if let monthlyAmounts = monthlyAmounts {
                // Sum up special months + regular months
                var total = 0.0
                for month in 1...12 {
                    total += monthlyAmounts[month] ?? amount
                }
                return total
            }
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

    var periodDisplay: String {
        switch period {
        case .monthly: return "Resets monthly"
        case .calendarYear: return "Resets Jan 1"
        case .cardmemberYear: return "Resets on anniversary"
        case .oneTime: return "One-time benefit"
        }
    }

    // MARK: - Initializers

    /// Full initializer with all fields
    init(
        id: String,
        type: BenefitType,
        name: String,
        description: String,
        amount: Double,
        frequency: BenefitFrequency,
        eligibleMerchants: [String]? = nil,
        category: String? = nil,
        conditions: String? = nil,
        period: BenefitPeriod = .monthly,
        monthlyAmounts: [Int: Double]? = nil,
        eligibleCategories: [String]? = nil,
        canAutoDetect: Bool = true,
        requiresEnrollment: Bool = false,
        enrollmentUrl: String? = nil,
        matchCreditTransactions: Bool = false
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.description = description
        self.amount = amount
        self.frequency = frequency
        self.eligibleMerchants = eligibleMerchants
        self.category = category
        self.conditions = conditions
        self.period = period
        self.monthlyAmounts = monthlyAmounts
        self.eligibleCategories = eligibleCategories
        self.canAutoDetect = canAutoDetect
        self.requiresEnrollment = requiresEnrollment
        self.enrollmentUrl = enrollmentUrl
        self.matchCreditTransactions = matchCreditTransactions
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, type, name, description, amount, frequency
        case eligibleMerchants, category, conditions
        case period, monthlyAmounts, eligibleCategories
        case canAutoDetect, requiresEnrollment, enrollmentUrl
        case matchCreditTransactions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(BenefitType.self, forKey: .type)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        amount = try container.decode(Double.self, forKey: .amount)
        frequency = try container.decode(BenefitFrequency.self, forKey: .frequency)
        eligibleMerchants = try container.decodeIfPresent([String].self, forKey: .eligibleMerchants)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        conditions = try container.decodeIfPresent(String.self, forKey: .conditions)

        // New fields with defaults
        period = try container.decodeIfPresent(BenefitPeriod.self, forKey: .period) ?? .monthly
        monthlyAmounts = try container.decodeIfPresent([Int: Double].self, forKey: .monthlyAmounts)
        eligibleCategories = try container.decodeIfPresent([String].self, forKey: .eligibleCategories)
        canAutoDetect = try container.decodeIfPresent(Bool.self, forKey: .canAutoDetect) ?? true
        requiresEnrollment = try container.decodeIfPresent(Bool.self, forKey: .requiresEnrollment) ?? false
        enrollmentUrl = try container.decodeIfPresent(String.self, forKey: .enrollmentUrl)
        matchCreditTransactions = try container.decodeIfPresent(Bool.self, forKey: .matchCreditTransactions) ?? false
    }
}

struct CreditCard: Identifiable, Codable {
    let id: String
    let name: String
    let issuer: CardIssuer
    let benefits: [CreditCardBenefit]
    let annualFee: Double

    var totalBenefitsValue: Double {
        benefits.reduce(0) { $0 + $1.annualAmount }
    }

    var netValue: Double {
        totalBenefitsValue - annualFee
    }
}
