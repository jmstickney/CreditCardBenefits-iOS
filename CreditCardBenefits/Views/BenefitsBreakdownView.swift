//
//  BenefitsBreakdownView.swift
//  CreditCardBenefits
//
//  Simple, clear breakdown of card benefits - just show annual fee and what's been used
//

import SwiftUI

struct BenefitsBreakdownView: View {
    let cards: [CreditCard]
    let benefitMatches: [BenefitMatch]
    let stats: UserStats
    let utilizations: [BenefitUtilization]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Card-by-card breakdown
                ForEach(cards) { card in
                    SimpleCardBenefitsSection(
                        card: card,
                        utilizations: utilizations.filter { $0.cardId == card.id }
                    )
                }

                Spacer(minLength: 40)
            }
            .padding(.top, 20)
        }
        .navigationTitle("Benefits Breakdown")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Simple Card Benefits Section
struct SimpleCardBenefitsSection: View {
    let card: CreditCard
    let utilizations: [BenefitUtilization]

    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Card header
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 16) {
                    // Card thumbnail
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: Color.cardGradient(for: card.issuer),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 60, height: 38)
                        .overlay(
                            Text(card.issuer.rawValue.uppercased())
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("\(card.benefits.count) benefits")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(spacing: 16) {
                    Divider()
                        .padding(.horizontal)

                    // Annual Fee - Prominent
                    HStack {
                        Text("Annual Fee")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        Text(card.annualFee.asCurrency())
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Benefits List - Clear status for each
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BENEFITS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        ForEach(card.benefits) { benefit in
                            SimpleBenefitRow(
                                benefit: benefit,
                                utilization: utilizations.first { $0.benefitId == benefit.id }
                            )
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - Simple Benefit Row
struct SimpleBenefitRow: View {
    let benefit: CreditCardBenefit
    let utilization: BenefitUtilization?

    private var isUsed: Bool {
        guard let utilization = utilization else { return false }
        return utilization.amountUtilized > 0
    }

    private var amountUsed: Double {
        utilization?.amountUtilized ?? 0
    }

    private var amountRemaining: Double {
        utilization?.amountRemaining ?? benefit.annualAmount
    }

    private var utilizationPercentage: Double {
        utilization?.utilizationPercentage ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Status icon
                Circle()
                    .fill(isUsed ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: isUsed ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundColor(isUsed ? .green : .secondary.opacity(0.5))
                    )

                VStack(alignment: .leading, spacing: 6) {
                    // Benefit name
                    Text(benefit.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)

                    // Status text
                    if isUsed {
                        HStack(spacing: 4) {
                            Text("Used \(amountUsed.asCurrency()) of \(benefit.annualAmount.asCurrency())")
                                .font(.system(size: 13))
                                .foregroundColor(.green)
                            
                            if amountRemaining > 0 {
                                Text("• \(amountRemaining.asCurrency()) left")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(height: 4)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.green)
                                    .frame(width: geometry.size.width * utilizationPercentage, height: 4)
                            }
                        }
                        .frame(height: 4)
                    } else {
                        Text("Not used • \(benefit.annualAmount.asCurrency()) available")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Amount badge
                VStack(alignment: .trailing, spacing: 4) {
                    Text(benefit.annualAmount.asCurrency())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(benefit.frequency.rawValue)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    NavigationStack {
        BenefitsBreakdownView(
            cards: MockData.userCards,
            benefitMatches: [],
            stats: UserStats(
                totalSubscriptions: 10,
                monthlySubscriptionCost: 150.00,
                annualSubscriptionCost: 1800.00,
                potentialSavings: 450.00,
                activeCards: 2,
                totalAnnualFees: 1245.00,
                totalBenefitsValue: 720.00
            ),
            utilizations: []
        )
    }
}
