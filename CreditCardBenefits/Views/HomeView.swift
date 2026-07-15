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
    @State private var linkTokenItem: LinkTokenItem?
    @State private var showSignIn = false
    @State private var showingCapturedBreakdown = false

    private struct LinkTokenItem: Identifiable {
        let id = UUID()
        let token: String
    }
    
    // Computed properties for HomeHeaderView
    private var totalUsedValue: Double {
        BenefitPeriodHelper.yearToDateUtilized(dataManager.utilizationService.utilizations)
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
                        unusedBenefitCount: unusedBenefitCount,
                        onHeroTap: { showingCapturedBreakdown = true }
                    )
                    
                    // Accounts section
                    VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Accounts")
                                    .font(Ben.Font.bodyLarge)
                                    .foregroundColor(Ben.Color.textPrimary)
                                
                                Spacer()
                                
                                Button(action: {
                                    if dataManager.authService.isAuthenticated {
                                        Task { await handleAddCard() }
                                    } else {
                                        showSignIn = true
                                    }
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(Ben.Color.forest)
                                }
                                .authGate(
                                    isPresented: $showSignIn,
                                    dataManager: dataManager
                                ) {
                                    Task { await handleAddCard() }
                                }
                            }
                            .padding(.horizontal, 20)

                            // Card list
                            if dataManager.userCards.isEmpty {
                                EmptyAccountsView {
                                    if dataManager.authService.isAuthenticated {
                                        Task { await handleAddCard() }
                                    } else {
                                        showSignIn = true
                                    }
                                }
                                .padding(.horizontal, 20)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(dataManager.userCards.enumerated()), id: \.element.id) { index, card in
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

                                        if index < dataManager.userCards.count - 1 {
                                            Divider()
                                                .padding(.leading, 88)
                                        }
                                    }
                                }
                                .background(Ben.Color.sand)
                                .cornerRadius(Ben.Radius.lg)
                                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                                .padding(.horizontal, 20)
                            }
                    }

                    Spacer(minLength: 100)
                }
            }
            .benBackground()
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.light)
            .onAppear {
                if !dataManager.isRestoringState && !dataManager.plaidService.transactions.isEmpty {
                    dataManager.loadData(from: dataManager.plaidService.transactions)
                }
            }
            .onChange(of: dataManager.plaidService.transactions) { _, newTransactions in
                if !dataManager.isRestoringState && !newTransactions.isEmpty {
                    dataManager.loadData(from: newTransactions)
                }
            }
            .sheet(isPresented: $showingCapturedBreakdown) {
                BenefitsCapturedBreakdownView(
                    title: "Benefits Captured",
                    total: totalUsedValue,
                    contributions: BenefitsCapturedBreakdownView.makeContributions(
                        from: dataManager.utilizationService.utilizations,
                        transactions: dataManager.plaidService.transactions
                    ),
                    showCardName: true
                )
            }
            .sheet(item: $linkTokenItem) { item in
                PlaidLinkView(
                    linkToken: item.token,
                    onSuccess: { publicToken in
                        Task {
                            await dataManager.plaidService.exchangePublicToken(publicToken)
                            linkTokenItem = nil
                        }
                    },
                    onExit: {
                        linkTokenItem = nil
                    }
                )
            }
            .onChange(of: dataManager.plaidService.accounts) { _, newAccounts in
                if !dataManager.isRestoringState && !newAccounts.isEmpty {
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
    
    @MainActor
    private func handleAddCard() async {
        do {
            let token = try await dataManager.plaidService.createLinkToken()
            linkTokenItem = LinkTokenItem(token: token)
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
            benLog("Recommendation tapped: \(recommendation.title)")
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
        .contentShape(Rectangle())
        .padding(Ben.Spacing.md)
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
    let onConnect: () -> Void

    var body: some View {
        VStack(spacing: Ben.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Ben.Color.forest.opacity(0.08))
                    .frame(width: 84, height: 84)
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(Ben.Color.forest)
            }

            VStack(spacing: Ben.Spacing.xs) {
                Text("Add your first card")
                    .font(Ben.Font.bodyLarge)
                    .foregroundColor(Ben.Color.textPrimary)

                Text("Connect your bank to automatically track your card benefits — so you never leave money on the table.")
                    .font(Ben.Font.bodySmall)
                    .foregroundColor(Ben.Color.textMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            BenPrimaryButton(title: "Connect a Card", action: onConnect)
                .padding(.top, Ben.Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .benCard(padding: Ben.Spacing.xl)
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
