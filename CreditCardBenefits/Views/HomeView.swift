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
    @State private var showingSavingsSheet = false
    @State private var showingRemindersSheet = false

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

                    // Fresh connection: Plaid delivers recent transactions
                    // immediately and backfills the deep history over the next
                    // few minutes — tell the user instead of looking incomplete.
                    if dataManager.plaidService.isImportingHistory {
                        HStack(spacing: 12) {
                            ProgressView()
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Importing your transaction history")
                                    .font(Ben.Font.body)
                                    .foregroundColor(Ben.Color.textPrimary)
                                Text("Recent activity is in — up to 24 months of history is still arriving. This usually takes a few minutes.")
                                    .font(Ben.Font.caption)
                                    .foregroundColor(Ben.Color.textMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(Ben.Spacing.md)
                        .background(Ben.Color.sand)
                        .cornerRadius(Ben.Radius.lg)
                        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    }

                    // New HomeHeaderView component
                    HomeHeaderView(
                        usedValue: totalUsedValue,
                        totalFees: totalAnnualFees,
                        onHeroTap: { showingCapturedBreakdown = true }
                    )

                    // Summary chips under the hero (Benefits-Captured pattern):
                    // compact summed value + capped preview, tap for the full
                    // breakdown sheet. Stacked vertically; each only when
                    // it has content.
                    if hasSavings || hasReminders {
                        VStack(spacing: 12) {
                            if hasSavings {
                                savingsChip
                            }
                            if hasReminders {
                                remindersChip
                            }
                        }
                        .padding(.horizontal, Ben.Spacing.screenH)
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
            .sheet(isPresented: $showingSavingsSheet) {
                SavingsOpportunitiesSheet()
                    .environmentObject(dataManager)
            }
            .sheet(isPresented: $showingRemindersSheet) {
                RemindersSheet()
                    .environmentObject(dataManager)
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
    
    // MARK: - Insight Summary Chips (Savings / Reminders)

    private var hasSavings: Bool { !dataManager.missedOpportunities.isEmpty }
    private var hasReminders: Bool { !dataManager.expiringReminders.isEmpty }

    private var savingsChip: some View {
        let opportunities = dataManager.missedOpportunities
        let total = opportunities.reduce(0.0) { $0 + $1.benefit.annualAmount }
        return InsightSummaryChip(
            tag: "Savings Opportunities",
            headline: "Up to \(total.asCurrency())/yr",
            headlineColor: Ben.Color.mintDark,
            previewLines: opportunities.prefix(2).map {
                "\($0.merchantDisplayName) → \($0.coveringCard.name)"
            },
            moreCount: max(0, opportunities.count - 2),
            action: { showingSavingsSheet = true }
        )
    }

    private var remindersChip: some View {
        let reminders = dataManager.expiringReminders
        let total = reminders.reduce(0.0) { $0 + $1.remaining }
        return InsightSummaryChip(
            tag: "Expiring Soon",
            headline: "\(total.asCurrency()) left to use",
            headlineColor: Ben.Color.warn,
            previewLines: reminders.prefix(2).map {
                "\($0.benefit.name) — \($0.remaining.asCurrency()) · \($0.daysLeft)d"
            },
            moreCount: max(0, reminders.count - 2),
            action: { showingRemindersSheet = true }
        )
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

// MARK: - Insight Summary Chip
// Compact tappable summary (Benefits-Captured pattern): summed value, a capped
// preview list, and a chevron; tap opens the full breakdown sheet.
struct InsightSummaryChip: View {
    let tag: String
    let headline: String
    let headlineColor: Color
    let previewLines: [String]
    let moreCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Matches BenefitProgressHeroCard's label + chevron row.
                HStack(spacing: Ben.Spacing.xs) {
                    Text(tag)
                        .font(Ben.Font.tag)
                        .tracking(1.0)
                        .textCase(.uppercase)
                        .foregroundColor(Ben.Color.textMuted)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Ben.Color.textMuted)
                }
                .padding(.bottom, Ben.Spacing.xs)

                Text(headline)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(headlineColor)
                    .padding(.bottom, 6)

                VStack(alignment: .leading, spacing: 2) {
                    ForEach(previewLines, id: \.self) { line in
                        Text(line)
                            .font(Ben.Font.bodySmall)
                            .foregroundColor(Ben.Color.textBody)
                            .lineLimit(1)
                    }
                    if moreCount > 0 {
                        Text("+ \(moreCount) more")
                            .font(Ben.Font.caption)
                            .foregroundColor(Ben.Color.textMuted)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Same surface treatment as BenefitProgressHeroCard.
            .padding(Ben.Spacing.xl)
            .background(Color.white)
            .cornerRadius(Ben.Radius.xl)
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
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
