//
//  Recommendation.swift
//  CreditCardBenefits
//
//  AI-powered recommendations for optimizing credit card benefits
//

import Foundation

enum RecommendationType: String, Codable {
    case switchSubscriptionCard      // Move subscription to better card
    case activateUnusedBenefit      // Benefit available but not used
    case consolidateSubscriptions    // Bundle subscriptions for savings
    case addMissingCard             // Suggest new card for spending pattern
    case cancelUnderutilizedCard    // Card not worth the annual fee
    case seasonalOpportunity        // Time-sensitive benefit expiring
    case enrollmentRequired         // Benefit needs manual enrollment
    
    var icon: String {
        switch self {
        case .switchSubscriptionCard: return "arrow.triangle.2.circlepath"
        case .activateUnusedBenefit: return "star.circle.fill"
        case .consolidateSubscriptions: return "square.stack.3d.up.fill"
        case .addMissingCard: return "plus.circle.fill"
        case .cancelUnderutilizedCard: return "minus.circle.fill"
        case .seasonalOpportunity: return "clock.fill"
        case .enrollmentRequired: return "hand.tap.fill"
        }
    }
    
    var color: String {
        switch self {
        case .switchSubscriptionCard: return "blue"
        case .activateUnusedBenefit: return "green"
        case .consolidateSubscriptions: return "purple"
        case .addMissingCard: return "orange"
        case .cancelUnderutilizedCard: return "red"
        case .seasonalOpportunity: return "yellow"
        case .enrollmentRequired: return "indigo"
        }
    }
}

struct Recommendation: Identifiable, Codable {
    let id: String
    let type: RecommendationType
    let title: String
    let description: String
    let potentialSavings: Double        // Annual $ impact
    let priority: Int                   // 1 = highest priority
    let actionUrl: String?              // Deep link or enrollment URL
    let metadata: RecommendationMetadata?
    let createdAt: Date
    
    init(
        id: String = UUID().uuidString,
        type: RecommendationType,
        title: String,
        description: String,
        potentialSavings: Double,
        priority: Int,
        actionUrl: String? = nil,
        metadata: RecommendationMetadata? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.potentialSavings = potentialSavings
        self.priority = priority
        self.actionUrl = actionUrl
        self.metadata = metadata
        self.createdAt = createdAt
    }
}

// Additional context for different recommendation types
struct RecommendationMetadata: Codable {
    // For switchSubscriptionCard
    let subscriptionId: String?
    let fromCardId: String?
    let toCardId: String?
    
    // For activateUnusedBenefit
    let benefitId: String?
    let cardId: String?
    let expirationDate: Date?
    
    // For addMissingCard
    let suggestedCardId: String?
    let spendingCategory: String?
    
    init(
        subscriptionId: String? = nil,
        fromCardId: String? = nil,
        toCardId: String? = nil,
        benefitId: String? = nil,
        cardId: String? = nil,
        expirationDate: Date? = nil,
        suggestedCardId: String? = nil,
        spendingCategory: String? = nil
    ) {
        self.subscriptionId = subscriptionId
        self.fromCardId = fromCardId
        self.toCardId = toCardId
        self.benefitId = benefitId
        self.cardId = cardId
        self.expirationDate = expirationDate
        self.suggestedCardId = suggestedCardId
        self.spendingCategory = spendingCategory
    }
}
