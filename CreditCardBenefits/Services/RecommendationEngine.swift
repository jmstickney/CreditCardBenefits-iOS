//
//  RecommendationEngine.swift
//  CreditCardBenefits
//
//  Generates personalized recommendations for optimizing credit card benefits
//

import Foundation

class RecommendationEngine {
    
    // MARK: - Public API
    
    /// Generates prioritized recommendations based on user's cards, transactions, and utilization
    static func generateRecommendations(
        userCards: [CreditCard],
        subscriptions: [Subscription],
        benefitMatches: [BenefitMatch],
        utilizations: [BenefitUtilization],
        transactions: [Transaction]
    ) -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        // 1. Find unused benefits (high priority)
        recommendations.append(contentsOf: findUnusedBenefits(
            userCards: userCards,
            utilizations: utilizations
        ))
        
        // 2. Find suboptimal subscription assignments
        recommendations.append(contentsOf: findSuboptimalSubscriptions(
            subscriptions: subscriptions,
            userCards: userCards,
            benefitMatches: benefitMatches
        ))
        
        // 3. Find benefits requiring enrollment
        recommendations.append(contentsOf: findEnrollmentRequired(
            userCards: userCards,
            utilizations: utilizations
        ))
        
        // 4. Find seasonal/expiring opportunities
        recommendations.append(contentsOf: findExpiringBenefits(
            utilizations: utilizations,
            userCards: userCards
        ))
        
        // 5. Find underutilized cards
        recommendations.append(contentsOf: findUnderutilizedCards(
            userCards: userCards,
            utilizations: utilizations
        ))
        
        // Sort by priority and potential savings
        return recommendations
            .sorted { ($0.priority, $0.potentialSavings) < ($1.priority, $1.potentialSavings) }
            .prefix(5)  // Limit to top 5 recommendations
            .map { $0 }
    }
    
    // MARK: - Recommendation Generators
    
    /// Find benefits with zero utilization
    private static func findUnusedBenefits(
        userCards: [CreditCard],
        utilizations: [BenefitUtilization]
    ) -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        for card in userCards {
            for benefit in card.benefits {
                // Find utilization for this benefit
                let utilization = utilizations.first {
                    $0.cardId == card.id && $0.benefitId == benefit.id
                }
                
                // Check if unused (0% utilization)
                let isUnused = (utilization?.amountUtilized ?? 0) == 0
                let benefitValue = benefit.annualAmount
                
                // Only recommend if benefit is auto-detectable or worth > $50/year
                guard isUnused && benefitValue >= 50 else { continue }
                
                // Skip if benefit requires enrollment (handled separately)
                guard !benefit.requiresEnrollment else { continue }
                
                let title: String
                let description: String
                
                if let merchants = benefit.eligibleMerchants, !merchants.isEmpty {
                    // Specific merchant benefit
                    title = "Use your \(benefit.name)"
                    description = "You have \(benefitValue.asCurrency()) available at \(merchants.joined(separator: ", ")). Start using it to offset your \(card.name) annual fee."
                } else {
                    // Category benefit
                    title = "Activate \(benefit.name)"
                    description = "You're not using \(benefitValue.asCurrency())/year in \(benefit.category ?? "benefits") on your \(card.name)."
                }
                
                recommendations.append(Recommendation(
                    type: .activateUnusedBenefit,
                    title: title,
                    description: description,
                    potentialSavings: benefitValue,
                    priority: 1,  // High priority
                    metadata: RecommendationMetadata(
                        benefitId: benefit.id,
                        cardId: card.id
                    )
                ))
            }
        }
        
        return recommendations
    }
    
    /// Find subscriptions that could be switched to a better card
    private static func findSuboptimalSubscriptions(
        subscriptions: [Subscription],
        userCards: [CreditCard],
        benefitMatches: [BenefitMatch]
    ) -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        // Group matches by subscription
        let matchesBySubscription = Dictionary(grouping: benefitMatches) { $0.subscription.id }
        
        for subscription in subscriptions {
            guard let matches = matchesBySubscription[subscription.id],
                  matches.count > 1 else {
                continue  // No alternative cards available
            }
            
            // Find best match (highest savings)
            let sortedMatches = matches.sorted { $0.potentialSavings > $1.potentialSavings }
            guard let bestMatch = sortedMatches.first,
                  let currentMatch = sortedMatches.dropFirst().first,
                  bestMatch.potentialSavings > currentMatch.potentialSavings else {
                continue  // Already using best card
            }
            
            let additionalSavings = bestMatch.potentialSavings - currentMatch.potentialSavings
            
            // Only recommend if savings > $20/year
            guard additionalSavings >= 20 else { continue }
            
            recommendations.append(Recommendation(
                type: .switchSubscriptionCard,
                title: "Switch \(subscription.merchant) to \(bestMatch.card.name)",
                description: "Save \(additionalSavings.asCurrency())/year by using your \(bestMatch.card.name) (\(bestMatch.benefit.name)) instead of \(currentMatch.card.name).",
                potentialSavings: additionalSavings,
                priority: 2,
                metadata: RecommendationMetadata(
                    subscriptionId: subscription.id,
                    fromCardId: currentMatch.card.id,
                    toCardId: bestMatch.card.id,
                    benefitId: bestMatch.benefit.id
                )
            ))
        }
        
        return recommendations
    }
    
    /// Find benefits that require manual enrollment
    private static func findEnrollmentRequired(
        userCards: [CreditCard],
        utilizations: [BenefitUtilization]
    ) -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        for card in userCards {
            for benefit in card.benefits where benefit.requiresEnrollment {
                // Check if already enrolled/used
                let utilization = utilizations.first {
                    $0.cardId == card.id && $0.benefitId == benefit.id
                }
                
                let isEnrolled = (utilization?.amountUtilized ?? 0) > 0 || 
                                 (utilization?.isManuallyMarked ?? false)
                
                guard !isEnrolled else { continue }
                
                let benefitValue = benefit.annualAmount
                
                recommendations.append(Recommendation(
                    type: .enrollmentRequired,
                    title: "Enroll in \(benefit.name)",
                    description: "This \(benefitValue.asCurrency())/year benefit requires enrollment. Tap to activate on your \(card.name).",
                    potentialSavings: benefitValue,
                    priority: 2,
                    actionUrl: benefit.enrollmentUrl,
                    metadata: RecommendationMetadata(
                        benefitId: benefit.id,
                        cardId: card.id
                    )
                ))
            }
        }
        
        return recommendations
    }
    
    /// Find benefits expiring soon
    private static func findExpiringBenefits(
        utilizations: [BenefitUtilization],
        userCards: [CreditCard]
    ) -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        for utilization in utilizations where utilization.isExpiringSoon {
            guard let card = userCards.first(where: { $0.id == utilization.cardId }),
                  let benefit = card.benefits.first(where: { $0.id == utilization.benefitId }) else {
                continue
            }
            
            let remainingValue = utilization.amountRemaining
            guard remainingValue > 0 else { continue }
            
            let daysRemaining = Calendar.current.dateComponents(
                [.day],
                from: Date(),
                to: utilization.periodEnd
            ).day ?? 0
            
            recommendations.append(Recommendation(
                type: .seasonalOpportunity,
                title: "Use \(benefit.name) before it expires",
                description: "You have \(remainingValue.asCurrency()) remaining on your \(card.name). Expires in \(daysRemaining) days.",
                potentialSavings: remainingValue,
                priority: 1,  // High priority due to expiration
                metadata: RecommendationMetadata(
                    benefitId: benefit.id,
                    cardId: card.id,
                    expirationDate: utilization.periodEnd
                )
            ))
        }
        
        return recommendations
    }
    
    /// Find cards where fees exceed benefits utilized
    private static func findUnderutilizedCards(
        userCards: [CreditCard],
        utilizations: [BenefitUtilization]
    ) -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        for card in userCards {
            // Skip free cards
            guard card.annualFee > 0 else { continue }
            
            // Calculate total utilization for this card
            let totalUtilized = utilizations
                .filter { $0.cardId == card.id }
                .reduce(0.0) { $0 + $1.amountUtilized }
            
            // Check if not worth the fee
            let netValue = totalUtilized - card.annualFee
            
            // Only recommend cancellation if losing > $100/year
            guard netValue < -100 else { continue }
            
            let utilizationRate = card.totalBenefitsValue > 0 
                ? (totalUtilized / card.totalBenefitsValue) * 100 
                : 0
            
            recommendations.append(Recommendation(
                type: .cancelUnderutilizedCard,
                title: "Consider canceling \(card.name)",
                description: "You're only using \(Int(utilizationRate))% of benefits (\(totalUtilized.asCurrency())) but paying \(card.annualFee.asCurrency()) in fees. Net loss: \(abs(netValue).asCurrency())/year.",
                potentialSavings: abs(netValue),  // Savings from canceling
                priority: 3,  // Lower priority (drastic action)
                metadata: RecommendationMetadata(
                    cardId: card.id
                )
            ))
        }
        
        return recommendations
    }
}
