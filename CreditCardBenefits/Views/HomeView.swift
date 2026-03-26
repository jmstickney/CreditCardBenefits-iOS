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

    var body: some View {
        NavigationStack {
            ZStack {
                // Ben cream background
                Color.benCream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Header with date and welcome
                        VStack(alignment: .leading, spacing: 20) {
                            Text(Date().asDateString)
                                .font(.system(size: 13))
                                .foregroundColor(.benMute)

                            Text("Welcome")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.benDark)
                            
                            // Horizontal utilization bar
                            if dataManager.userCards.count > 0 {
                                CompactBenefitUtilizationBar(
                                    userCards: dataManager.userCards,
                                    utilizations: dataManager.utilizationService.utilizations
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 60)
                        .padding(.bottom, 32)

                        // Accounts section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Accounts")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.benDark)
                                
                                Spacer()
                                
                                Button(action: {
                                    Task {
                                        await handleAddCard()
                                    }
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.benForest)
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
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.benDark)
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
            }
            .navigationBarHidden(true)
            .preferredColorScheme(.dark)
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.benDark)
                    .lineLimit(1)
                
                // Benefits summary (like "Payment due in 3 days")
                if unusedBenefits > 0 {
                    Text("\(unusedBenefits) of \(totalBenefits) benefits unused")
                        .font(.system(size: 13))
                        .foregroundColor(.benWarn)
                } else {
                    Text("All \(totalBenefits) benefits active")
                        .font(.system(size: 13))
                        .foregroundColor(.benGoodGreen)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.benSand)
        .cornerRadius(12)
        .padding(.horizontal, 20)
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
                    .fill(Color.benForest.opacity(0.2))
                    .frame(width: 56, height: 36)
                    .overlay(
                        Image(systemName: recommendation.type.icon)
                            .font(.system(size: 16))
                            .foregroundColor(.benForest)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(recommendation.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.benDark)
                        .lineLimit(2)
                    
                    if recommendation.potentialSavings > 0 {
                        Text("Save \(recommendation.potentialSavings.asCurrency())/year")
                            .font(.system(size: 13))
                            .foregroundColor(.benGoodGreen)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.benMute.opacity(0.5))
            }
            .padding(16)
            .background(Color.benSand)
            .cornerRadius(12)
            .padding(.horizontal, 20)
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
                .foregroundColor(.benMute.opacity(0.3))
            
            Text("No cards connected")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.benBark)
            
            Text("Connect your bank account to get started")
                .font(.system(size: 13))
                .foregroundColor(.benMute)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.benSand)
        .cornerRadius(12)
        .padding(.horizontal, 20)
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
