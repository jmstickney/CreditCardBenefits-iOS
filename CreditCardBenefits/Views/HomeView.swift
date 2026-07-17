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
    @State private var reconnectLinkToken: LinkTokenItem?
    @State private var showSignIn = false
    @State private var showingCapturedBreakdown = false
    @State private var dismissCandidate: MissedBenefitOpportunity?

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
                    // Reconnect prompt when a bank login has expired.
                    if dataManager.plaidService.needsReconnect {
                        ReconnectBanner(cardName: reconnectCardName) {
                            Task { await startReconnect() }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    }

                    // New HomeHeaderView component
                    HomeHeaderView(
                        usedValue: totalUsedValue,
                        totalFees: totalAnnualFees,
                        onHeroTap: { showingCapturedBreakdown = true }
                    )

                    // Savings opportunities directly under the hero — the most
                    // actionable insight, so it stays above the fold.
                    if !dataManager.missedOpportunities.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Savings Opportunities")
                                .font(Ben.Font.bodyLarge)
                                .foregroundColor(Ben.Color.textPrimary)
                                .padding(.horizontal, 20)

                            ForEach(dataManager.missedOpportunities.prefix(3)) { opportunity in
                                NavigationLink(destination: SwipeableCardDetailView(
                                    initialCard: opportunity.coveringCard,
                                    allCards: dataManager.userCards
                                )) {
                                    OpportunityCard(opportunity: opportunity) {
                                        dismissCandidate = opportunity
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.bottom, 16)
                    }

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

                                        Divider()
                                            .padding(.leading, 88)
                                    }

                                    // Always-visible affordance to link another card.
                                    Button(action: {
                                        if dataManager.authService.isAuthenticated {
                                            Task { await handleAddCard() }
                                        } else {
                                            showSignIn = true
                                        }
                                    }) {
                                        AddCardRow()
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .background(Ben.Color.sand)
                                .cornerRadius(Ben.Radius.lg)
                                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                                .padding(.horizontal, 20)
                            }
                    }

                    // Quick stats — moved below Accounts (secondary info once
                    // cards are established; Savings Opportunities took their
                    // spot under the hero).
                    HStack(spacing: Ben.Spacing.sm) {
                        QuickStatChip(
                            label: "cards",
                            value: "\(dataManager.userCards.count)",
                            valueColor: Ben.Color.textPrimary
                        )
                        QuickStatChip(
                            label: "unused benefits",
                            value: "\(unusedBenefitCount)",
                            valueColor: unusedBenefitCount > 0 ? Ben.Color.warn : Ben.Color.mintDark
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

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
                ReviewPrompter.maybePromptForSavings(dataManager.missedOpportunities)
            }
            .onChange(of: dataManager.missedOpportunities) { _, opportunities in
                // Delight moment: Ben just surfaced savings worth more than a
                // year of the subscription — the right time to ask for a rating.
                ReviewPrompter.maybePromptForSavings(opportunities)
            }
            .onChange(of: dataManager.plaidService.transactions) { _, newTransactions in
                if !dataManager.isRestoringState && !newTransactions.isEmpty {
                    dataManager.loadData(from: newTransactions)
                }
            }
            .alert(
                "Hide this suggestion?",
                isPresented: Binding(
                    get: { dismissCandidate != nil },
                    set: { if !$0 { dismissCandidate = nil } }
                ),
                presenting: dismissCandidate
            ) { candidate in
                Button("Hide Permanently", role: .destructive) {
                    dataManager.dismissOpportunity(candidate)
                    dismissCandidate = nil
                }
                Button("Cancel", role: .cancel) { dismissCandidate = nil }
            } message: { candidate in
                Text("Ben will permanently stop suggesting \(candidate.benefit.name) for \(candidate.merchantDisplayName) purchases. This can't be undone unless you sign out and back in.")
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
            .sheet(item: $reconnectLinkToken) { item in
                PlaidLinkView(
                    linkToken: item.token,
                    onSuccess: { _ in
                        // Update mode: the item is re-authenticated in place —
                        // no public token to exchange. Just refresh + recheck.
                        reconnectLinkToken = nil
                        Task {
                            await dataManager.plaidService.refreshTransactions()
                            await dataManager.plaidService.fetchItemsStatus()
                        }
                    },
                    onExit: {
                        reconnectLinkToken = nil
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
    
    // MARK: - Reconnect

    /// Card name for the first item needing reconnection (nil → generic copy).
    private var reconnectCardName: String? {
        guard let item = dataManager.plaidService.itemsNeedingReconnect.first else { return nil }
        let accountIds = dataManager.plaidService.accounts
            .filter { $0.itemId == item.itemId }
            .map { $0.id }
        return dataManager.cardMatches.first { match in
            accountIds.contains(match.plaidAccount.id) && match.creditCard != nil
        }?.creditCard?.name
    }

    @MainActor
    private func startReconnect() async {
        guard let item = dataManager.plaidService.itemsNeedingReconnect.first else { return }
        do {
            let token = try await dataManager.plaidService.createUpdateLinkToken(itemId: item.itemId)
            reconnectLinkToken = LinkTokenItem(token: token)
        } catch {
            dataManager.error = .network(error.localizedDescription)
            dataManager.showError = true
        }
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

// MARK: - Reconnect Banner
// Shown when a bank login expired (Plaid ITEM_LOGIN_REQUIRED). Tapping
// Reconnect launches Plaid Link in update mode to re-authenticate in place.
struct ReconnectBanner: View {
    let cardName: String?
    let onReconnect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundColor(Ben.Color.warn)

            VStack(alignment: .leading, spacing: 2) {
                Text(cardName.map { "\($0) needs reconnecting" }
                    ?? "A bank connection needs attention")
                    .font(Ben.Font.body)
                    .foregroundColor(Ben.Color.textPrimary)
                Text("Reconnect to keep transactions and benefits up to date.")
                    .font(Ben.Font.caption)
                    .foregroundColor(Ben.Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onReconnect) {
                Text("Reconnect")
                    .font(Ben.Font.bodySmall)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Ben.Color.forest)
                    .cornerRadius(10)
            }
        }
        .padding(Ben.Spacing.md)
        .background(Ben.Color.warn.opacity(0.10))
        .cornerRadius(Ben.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Ben.Radius.lg)
                .stroke(Ben.Color.warn.opacity(0.35), lineWidth: 1)
        )
    }
}

// MARK: - Opportunity Card
// A wrong-card suggestion: spend at a benefit-eligible merchant happened on a
// card that doesn't carry the benefit while another connected card does.
struct OpportunityCard: View {
    let opportunity: MissedBenefitOpportunity
    let onDismiss: () -> Void

    private var paidOn: String {
        opportunity.paidCardNames.joined(separator: ", ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 18))
                .foregroundColor(Ben.Color.mintDark)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(opportunity.merchantDisplayName) — paid on \(paidOn)")
                    .font(Ben.Font.body)
                    .foregroundColor(Ben.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Switch to your \(opportunity.coveringCard.name): \(opportunity.benefit.name) covers this (up to \(opportunity.benefit.annualAmount.asCurrency())/yr).")
                    .font(Ben.Font.bodySmall)
                    .foregroundColor(Ben.Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                let count = opportunity.matchedTransactions.count
                Text("\(count) purchase\(count == 1 ? "" : "s") in the last 90 days")
                    .font(Ben.Font.caption)
                    .foregroundColor(Ben.Color.textMuted.opacity(0.8))
            }

            Spacer(minLength: 4)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Ben.Color.textMuted)
                    .padding(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(Ben.Spacing.md)
        .background(Ben.Color.mintLight.opacity(0.5))
        .cornerRadius(Ben.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Ben.Radius.lg)
                .stroke(Ben.Color.mint.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Add Card Row
// Last row in the Accounts list — a clear, labeled affordance to link another
// card, so adding isn't hidden behind the small header "+".
struct AddCardRow: View {
    var body: some View {
        HStack(spacing: 16) {
            // Dashed card "slot" that echoes the real card thumbnails above it.
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    Ben.Color.forest.opacity(0.45),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                )
                .frame(width: 56, height: 36)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Ben.Color.forest)
                )

            Text("Add a card")
                .font(Ben.Font.body)
                .foregroundColor(Ben.Color.forest)

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
