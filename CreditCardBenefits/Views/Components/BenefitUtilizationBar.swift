//
//  BenefitUtilizationBar.swift
//  CreditCardBenefits
//
//  Horizontal stacked bar showing benefit utilization vs annual fees
//

import SwiftUI

struct BenefitUtilizationBar: View {
    let userCards: [CreditCard]
    let utilizations: [BenefitUtilization]
    
    private var totalAnnualFees: Double {
        userCards.reduce(0) { $0 + $1.annualFee }
    }
    
    private var totalUtilized: Double {
        utilizations.reduce(0) { $0 + $1.amountUtilized }
    }
    
    private var utilizationPercentage: Double {
        guard totalAnnualFees > 0 else { return 0 }
        return min((totalUtilized / totalAnnualFees) * 100, 100)
    }
    
    private var isBreakingEven: Bool {
        totalUtilized >= totalAnnualFees
    }
    
    // Calculate utilization by card
    private var cardUtilizations: [(card: CreditCard, utilized: Double)] {
        userCards.map { card in
            let cardUtilized = utilizations
                .filter { $0.cardId == card.id }
                .reduce(0.0) { $0 + $1.amountUtilized }
            return (card: card, utilized: cardUtilized)
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Benefit Utilization")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.benDark)
                    
                    Text("vs. Annual Fees")
                        .font(.system(size: 13))
                        .foregroundColor(.benMute)
                }
                
                Spacer()
                
                // Status badge
                HStack(spacing: 6) {
                    Image(systemName: isBreakingEven ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                    Text(isBreakingEven ? "Breaking Even" : "Below Fees")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(isBreakingEven ? .green : .orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isBreakingEven ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                .cornerRadius(12)
            }
            
            // The stacked horizontal bar
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background (total fees)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.benMute.opacity(0.2))
                            .frame(width: geometry.size.width, height: 40)
                        
                        // Stacked utilization bars (one per card)
                        HStack(spacing: 0) {
                            ForEach(Array(cardUtilizations.enumerated()), id: \.element.card.id) { index, item in
                                let cardPercentage = (item.utilized / totalAnnualFees) * 100
                                let width = geometry.size.width * (cardPercentage / 100)
                                
                                if width > 0 {
                                    RoundedRectangle(cornerRadius: index == 0 ? 8 : 0)
                                        .fill(cardColor(for: item.card, index: index))
                                        .frame(width: width, height: 40)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        // Percentage label overlay
                        HStack {
                            Spacer()
                            Text("\(Int(utilizationPercentage))%")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.benCream)
                            Spacer()
                        }
                    }
                }
                .frame(height: 40)
                
                // Legend and amounts
                HStack(spacing: 4) {
                    Text(totalUtilized.asCurrency())
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isBreakingEven ? .benGoodGreen : .benWarn)
                    
                    Text("of")
                        .font(.system(size: 13))
                        .foregroundColor(.benMute)
                    
                    Text(totalAnnualFees.asCurrency())
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.benBark)
                    
                    Spacer()
                    
                    if !isBreakingEven {
                        Text("\(abs(totalAnnualFees - totalUtilized).asCurrency()) to go")
                            .font(.system(size: 13))
                            .foregroundColor(.benMute)
                    } else {
                        Text("+\((totalUtilized - totalAnnualFees).asCurrency()) ahead")
                            .font(.system(size: 13))
                            .foregroundColor(.benGoodGreen)
                    }
                }
            }
            
            // Card breakdown (compact legend)
            if userCards.count > 1 {
                VStack(spacing: 8) {
                    ForEach(Array(cardUtilizations.enumerated()), id: \.element.card.id) { index, item in
                        if item.utilized > 0 {
                            HStack(spacing: 8) {
                                // Color indicator
                                Circle()
                                    .fill(cardColor(for: item.card, index: index))
                                    .frame(width: 8, height: 8)
                                
                                Text(item.card.name)
                                    .font(.system(size: 13))
                                    .foregroundColor(.benBark)
                                
                                Spacer()
                                
                                Text(item.utilized.asCurrency())
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.benDark)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.benSand)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.benMute.opacity(0.2), lineWidth: 1)
        )
    }
    
    // Generate color for each card
    private func cardColor(for card: CreditCard, index: Int) -> Color {
        let colors: [Color] = [.blue, .purple, .pink, .orange, .cyan, .indigo]
        return colors[index % colors.count]
    }
}

// MARK: - Compact Version (for smaller space)

struct CompactBenefitUtilizationBar: View {
    let userCards: [CreditCard]
    let utilizations: [BenefitUtilization]
    
    private var totalAnnualFees: Double {
        userCards.reduce(0) { $0 + $1.annualFee }
    }
    
    private var totalUtilized: Double {
        utilizations.reduce(0) { $0 + $1.amountUtilized }
    }
    
    private var utilizationPercentage: Double {
        guard totalAnnualFees > 0 else { return 0 }
        return min((totalUtilized / totalAnnualFees) * 100, 100)
    }
    
    private var isBreakingEven: Bool {
        totalUtilized >= totalAnnualFees
    }
    
    // Calculate utilization by card
    private var cardUtilizations: [(card: CreditCard, utilized: Double)] {
        userCards.map { card in
            let cardUtilized = utilizations
                .filter { $0.cardId == card.id }
                .reduce(0.0) { $0 + $1.amountUtilized }
            return (card: card, utilized: cardUtilized)
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with amounts
            HStack {
                Text("Benefits Used")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.benBark)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(totalUtilized.asCurrency())
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(isBreakingEven ? .benGoodGreen : .benWarn)
                    
                    Text("/")
                        .font(.system(size: 13))
                        .foregroundColor(.benMute)
                    
                    Text(totalAnnualFees.asCurrency())
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.benBark)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.benMute.opacity(0.2))
                        .frame(width: geometry.size.width, height: 12)
                    
                    // Stacked utilization
                    HStack(spacing: 0) {
                        ForEach(Array(cardUtilizations.enumerated()), id: \.element.card.id) { index, item in
                            let cardPercentage = (item.utilized / totalAnnualFees) * 100
                            let width = geometry.size.width * (cardPercentage / 100)
                            
                            if width > 0 {
                                Rectangle()
                                    .fill(cardColor(for: item.card, index: index))
                                    .frame(width: width, height: 12)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .frame(height: 12)
            
            // Status text
            HStack {
                Text("\(Int(utilizationPercentage))% of annual fees")
                    .font(.system(size: 13))
                    .foregroundColor(.benMute)
                
                Spacer()
                
                if !isBreakingEven {
                    Text("\((totalAnnualFees - totalUtilized).asCurrency()) to break even")
                        .font(.system(size: 13))
                        .foregroundColor(.benWarn)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Breaking even")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.benGoodGreen)
                }
            }
        }
    }
    
    private func cardColor(for card: CreditCard, index: Int) -> Color {
        let colors: [Color] = [.blue, .purple, .pink, .orange, .cyan, .indigo]
        return colors[index % colors.count]
    }
}

#Preview {
    VStack(spacing: 20) {
        BenefitUtilizationBar(
            userCards: MockData.userCards,
            utilizations: []
        )
        
        CompactBenefitUtilizationBar(
            userCards: MockData.userCards,
            utilizations: []
        )
    }
    .padding()
    .background(Color.black)
}
