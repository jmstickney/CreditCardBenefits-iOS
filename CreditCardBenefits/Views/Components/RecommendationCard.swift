//
//  RecommendationCard.swift
//  CreditCardBenefits
//
//  Component for displaying personalized recommendations
//

import SwiftUI

struct RecommendationCard: View {
    let recommendation: Recommendation
    let onTap: (() -> Void)?
    
    init(recommendation: Recommendation, onTap: (() -> Void)? = nil) {
        self.recommendation = recommendation
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            HStack(spacing: 16) {
                // Icon
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: recommendation.type.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(iconColor)
                    )
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(recommendation.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        // Savings badge
                        if recommendation.potentialSavings > 0 {
                            Text("+\(recommendation.potentialSavings.asCurrency())")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                    
                    Text(recommendation.description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconColor: Color {
        switch recommendation.type.color {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "yellow": return Color(red: 0.95, green: 0.77, blue: 0.06)
        case "indigo": return .indigo
        default: return .gray
        }
    }
}

// MARK: - Compact Variant

struct RecommendationCompactCard: View {
    let recommendation: Recommendation
    let onTap: (() -> Void)?
    
    init(recommendation: Recommendation, onTap: (() -> Void)? = nil) {
        self.recommendation = recommendation
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            HStack(spacing: 12) {
                // Icon
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: recommendation.type.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(iconColor)
                    )
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("Save \(recommendation.potentialSavings.asCurrency())/year")
                        .font(.system(size: 13))
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconColor: Color {
        switch recommendation.type.color {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "yellow": return Color(red: 0.95, green: 0.77, blue: 0.06)
        case "indigo": return .indigo
        default: return .gray
        }
    }
}

#Preview("Full Card") {
    VStack {
        RecommendationCard(
            recommendation: Recommendation(
                type: .activateUnusedBenefit,
                title: "Use your Uber Cash",
                description: "You have $200 available in Uber Cash on your Amex Platinum. Start using it to offset your annual fee.",
                potentialSavings: 200,
                priority: 1
            )
        )
        
        RecommendationCard(
            recommendation: Recommendation(
                type: .switchSubscriptionCard,
                title: "Switch Netflix to Chase Sapphire",
                description: "Save $60/year by using your Chase Sapphire Preferred for Netflix instead of your current card.",
                potentialSavings: 60,
                priority: 2
            )
        )
    }
    .padding()
    .background(Color(.systemBackground))
}

#Preview("Compact Card") {
    VStack {
        RecommendationCompactCard(
            recommendation: Recommendation(
                type: .activateUnusedBenefit,
                title: "Use your Uber Cash",
                description: "You have $200 available",
                potentialSavings: 200,
                priority: 1
            )
        )
        
        RecommendationCompactCard(
            recommendation: Recommendation(
                type: .switchSubscriptionCard,
                title: "Switch Netflix to Chase Sapphire",
                description: "Save $60/year",
                potentialSavings: 60,
                priority: 2
            )
        )
    }
    .padding()
    .background(Color(.systemBackground))
}
