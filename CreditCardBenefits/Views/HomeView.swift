//
//  HomeView.swift
//  CreditCardBenefits
//
//  Redesigned with Amex-inspired clean, compact aesthetic
//

import SwiftUI
import Combine

struct HomeView: View {
    @EnvironmentObject var dataManager: AppDataManager
    @State private var showingAddCard = false
    @State private var linkToken: String?
    
    // Computed properties for HomeHeaderView
    private var totalUsedValue: Double {
        dataManager.utilizationService.utilizations.reduce(0) { $0 + $1.amountUtilized }
    }
    
    private var totalAnnualFees: Double {
        dataManager.userCards.reduce(0) { $0 + $1.annualFee }
    }
    
    private var unusedBenefitCount: Int {
        let usedBenefitIds = Set(dataManager.utilizationService.utilizations.filter { $0.amountUtilized > 0 }.map { $0.benefitId })
        let allBenefitIds = Set(dataManager.userCards.flatMap { $0.benefits.map { $0.id } })
        return allBenefitIds.count - usedBenefitIds.count
    }

    var body: some View {
        ScrollView {
                VStack(spacing: 0) {
                    // New HomeHeaderView component
                    HomeHeaderView(
                        usedValue: totalUsedValue,
                        totalFees: totalAnnualFees,
                        cardCount: dataManager.userCards.count,
                        unusedBenefitCount: unusedBenefitCount
                    )
                    
                    // Accounts section
                    VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Accounts")
                                    .font(Ben.Font.bodyLarge)
                                    .foregroundColor(Ben.Color.textPrimary)
                                
                                Spacer()
                                
                                Button(action: {
                                    Task {
                                        await handleAddCard()
                                    }
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(Ben.Color.forest)
                                }
                            }
                            .padding(.horizontal, 20)

                            // Card list
                            if dataManager.userCards.isEmpty {
                                EmptyAccountsView()
                            } else {
                                ForEach(dataManager.userCards) { card in
                                    NavigationLink(destination: SwipeableCardDetailView(
                                        initialCard: card,
                                        allCards: dataManager.userCards
                                    )) {
                                        AmexStyleCardRow(
                                            card: card,
                                            utilizations: dataManager.utilizationService.utilizationsForCard(card.id)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                    }

                    // Recommendations section (if any)
                    if !dataManager.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Don't Miss Out")
                                .font(Ben.Font.bodyLarge)
                                .foregroundColor(Ben.Color.textPrimary)
                                .padding(.horizontal, 20)
                                .padding(.top, 32)

                            ForEach(dataManager.recommendations.prefix(2)) { recommendation in
                                AmexStyleRecommendationCard(recommendation: recommendation) {
                                    handleRecommendationTap(recommendation)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 100)
                }
            }
            .benBackground()
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.light)
            .onAppear {
                if !dataManager.plaidService.transactions.isEmpty {
                    dataManager.loadData(from: dataManager.plaidService.transactions)
                }
            }
            .onChange(of: dataManager.plaidService.transactions) { _, newTransactions in
                if !newTransactions.isEmpty {
                    dataManager.loadData(from: newTransactions)
                }
            }
            .alert("Error", isPresented: $dataManager.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = dataManager.error {
                    Text(error.localizedDescription)
                }
            }
            .sheet(isPresented: $dataManager.needsCardConfirmation) {
                CardSelectionView()
            }
            .sheet(isPresented: $showingAddCard) {
                if let linkToken = linkToken {
                    PlaidLinkView(
                        linkToken: linkToken,
                        onSuccess: { publicToken in
                            Task {
                                await dataManager.plaidService.exchangePublicToken(publicToken)
                                showingAddCard = false
                            }
                        },
                        onExit: {
                            showingAddCard = false
                        }
                    )
                }
            }
            .onChange(of: dataManager.plaidService.accounts) { _, newAccounts in
                if !newAccounts.isEmpty {
                    Task {
                        await dataManager.processPlaidAccounts()
                }
            }
        }
    }
    
    private var stats: UserStats {
        dataManager.stats
    }
    
    // MARK: - Add Card Action
    
    private func handleAddCard() async {
        do {
            linkToken = try await dataManager.plaidService.createLinkToken()
            showingAddCard = true
        } catch {
            dataManager.error = .network(error.localizedDescription)
            dataManager.showError = true
        }
    }
    
    // MARK: - Recommendation Actions
    
    private func handleRecommendationTap(_ recommendation: Recommendation) {
        switch recommendation.type {
        case .activateUnusedBenefit:
            if let metadata = recommendation.metadata,
               let cardId = metadata.cardId,
               let card = dataManager.userCards.first(where: { $0.id == cardId }) {
                // Navigate to card detail
            }
            
        case .enrollmentRequired:
            if let urlString = recommendation.actionUrl,
               let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
            
        default:
            print("Recommendation tapped: \(recommendation.title)")
        }
    }
}

// MARK: - Amex-Style Card Row

struct AmexStyleCardRow: View {
    let card: CreditCard
    let utilizations: [BenefitUtilization]
    
    private var totalBenefits: Int {
        card.benefits.count
    }
    
    private var unusedBenefits: Int {
        let usedBenefitIds = Set(utilizations.filter { $0.amountUtilized > 0 }.map { $0.benefitId })
        return totalBenefits - usedBenefitIds.count
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Card thumbnail
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: Color.cardGradient(for: card.issuer),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 56, height: 36)
                .overlay(
                    Text(card.issuer.rawValue.uppercased())
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                )

            VStack(alignment: .leading, spacing: 6) {
                // Card name (like "Platinum Card® (•••81009)")
                Text(card.name)
                    .font(Ben.Font.body)
                    .foregroundColor(Ben.Color.textPrimary)
                    .lineLimit(1)
                
                // Benefits summary (like "Payment due in 3 days")
                if unusedBenefits > 0 {
                    Text("\(unusedBenefits) of \(totalBenefits) benefits unused")
                        .font(Ben.Font.bodySmall)
                        .foregroundColor(Ben.Color.warn)
                } else {
                    Text("All \(totalBenefits) benefits active")
                        .font(Ben.Font.bodySmall)
                        .foregroundColor(Ben.Color.mintDark)
                }
            }
            
            Spacer()
        }
        .benCard()
    }
}

// MARK: - Amex-Style Recommendation Card

struct AmexStyleRecommendationCard: View {
    let recommendation: Recommendation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon matching Ben theme
                RoundedRectangle(cornerRadius: 6)
                    .fill(Ben.Color.forest.opacity(0.2))
                    .frame(width: 56, height: 36)
                    .overlay(
                        Image(systemName: recommendation.type.icon)
                            .font(.system(size: 16))
                            .foregroundColor(Ben.Color.forest)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(recommendation.title)
                        .font(Ben.Font.body)
                        .foregroundColor(Ben.Color.textPrimary)
                        .lineLimit(2)
                    
                    if recommendation.potentialSavings > 0 {
                        Text("Save \(recommendation.potentialSavings.asCurrency())/year")
                            .font(Ben.Font.bodySmall)
                            .foregroundColor(Ben.Color.mintDark)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Ben.Color.textMuted.opacity(0.5))
            }
            .benCard()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Empty State

struct EmptyAccountsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard")
                .font(.system(size: 48))
                .foregroundColor(Ben.Color.textMuted.opacity(0.3))
            
            Text("No cards connected")
                .font(Ben.Font.body)
                .foregroundColor(Ben.Color.textBody)
            
            Text("Connect your bank account to get started")
                .font(Ben.Font.bodySmall)
                .foregroundColor(Ben.Color.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .benCard(padding: 40)
    }
}

// MARK: - Circular Value Indicator

struct CircularValueIndicator: View {
    let utilizedValue: Double
    let totalValue: Double
    let annualFees: Double
    
    private var netValue: Double {
        utilizedValue - annualFees
    }
    
    private var utilizationPercentage: Double {
        guard totalValue > 0 else { return 0 }
        return min(1.0, utilizedValue / totalValue)
    }
    
    private var progressColor: Color {
        if netValue >= 0 {
            return .green
        } else if utilizationPercentage >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 8)
                .frame(width: 80, height: 80)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: utilizationPercentage)
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: utilizationPercentage)
            
            // Center content
            VStack(spacing: 2) {
                Text(netValue >= 0 ? "+" : "")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(progressColor) +
                Text(abs(netValue).asCurrency())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(progressColor)
                
                Text("\(Int(utilizationPercentage * 100))%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}

#Preview("Circular Indicator") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 40) {
            VStack {
                Text("Winning Scenario")
                    .foregroundColor(.white)
                CircularValueIndicator(
                    utilizedValue: 850,
                    totalValue: 1200,
                    annualFees: 695
                )
            }
            
            VStack {
                Text("Partial Usage")
                    .foregroundColor(.white)
                CircularValueIndicator(
                    utilizedValue: 400,
                    totalValue: 1200,
                    annualFees: 695
                )
            }
            
            VStack {
                Text("Low Usage")
                    .foregroundColor(.white)
                CircularValueIndicator(
                    utilizedValue: 150,
                    totalValue: 1200,
                    annualFees: 695
                )
            }
        }
    }
}

#Preview("Home View") {
    HomeView()
        .environmentObject(AppDataManager())
}
