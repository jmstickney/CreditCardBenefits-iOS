//
//  CardDetailView.swift
//  CreditCardBenefits
//
//  Amex-inspired card detail view
//

import SwiftUI

struct CardDetailView: View {
    let card: CreditCard
    let allCards: [CreditCard]
    var showBackButton: Bool = true  // Hide back button when in swipeable view
    
    @EnvironmentObject var dataManager: AppDataManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showingAnniversaryPicker = false
    @State private var showingCapturedBreakdown = false
    @State private var showConfetti = false

    private var utilizations: [BenefitUtilization] {
        dataManager.utilizationService.utilizationsForCard(card.id)
    }
    
    /// Year-to-date benefits actually used on this card (sums `amountUtilized`,
    /// with monthly periods rolled up across the current calendar year).
    private var totalUtilizedAnnual: Double {
        BenefitPeriodHelper.yearToDateUtilized(utilizations)
    }
    
    private var cardMatch: CardMatch? {
        dataManager.cardMatches.first { $0.creditCard?.id == card.id }
    }
    
    private var hasCardmemberYearBenefits: Bool {
        card.benefits.contains { $0.period == .cardmemberYear }
    }

    /// Whether to offer the card-anniversary setting. Amex resets its annual
    /// credits on the calendar year (no anniversary needed), so it's hidden for
    /// Amex regardless of how individual benefits are modeled.
    private var showsAnniversarySetting: Bool {
        hasCardmemberYearBenefits && card.issuer != .amex
    }

    /// Name of the benefit that resets on the anniversary (Chase's travel
    /// credit), used in the anniversary prompt copy.
    private var anniversaryBenefitName: String {
        card.benefits.first { $0.period == .cardmemberYear }?.name ?? "annual credit"
    }

    var body: some View {
        ZStack {
            // Ben cream background
            Ben.Color.cream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Large card image at top (like Amex)
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(
                                colors: Color.cardGradient(for: card.issuer),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(height: 200)
                            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Spacer()
                            
                            Text(card.name)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)

                            Text("•••• \(String(card.id.suffix(4)))")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 80)
                    .padding(.bottom, 32)

                    // Benefits Captured hero (matches homepage layout, scoped to this card)
                    BenefitProgressHeroCard(
                        label: "Benefits Captured",
                        usedValue: totalUtilizedAnnual,
                        totalFees: card.annualFee,
                        onTap: { showingCapturedBreakdown = true }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    
                    // Anniversary Date Section — only for cards with a
                    // cardmember-year benefit (e.g. Chase's travel credit).
                    if showsAnniversarySetting {
                        if let anniversaryDate = cardMatch?.anniversaryDate {
                            // Set: compact display with an Edit action.
                            VStack(spacing: 16) {
                                HStack {
                                    Text("Card Anniversary")
                                        .font(Ben.Font.bodySmall)
                                        .foregroundColor(Ben.Color.textMuted)

                                    Spacer()

                                    Button {
                                        showingAnniversaryPicker = true
                                    } label: {
                                        Text("Edit")
                                            .font(Ben.Font.body)
                                            .foregroundColor(Ben.Color.forest)
                                    }
                                }

                                HStack {
                                    Text(AnniversaryDateHelper.displayString(for: anniversaryDate))
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(Ben.Color.textPrimary)
                                    Spacer()
                                }

                                Text("Your \(anniversaryBenefitName) resets on this date each year.")
                                    .font(Ben.Font.caption)
                                    .foregroundColor(Ben.Color.textMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .benCard()
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                        } else {
                            // Unset: prominent nudge. Without an anniversary the
                            // travel credit falls back to calendar-year tracking,
                            // so make setting it easy to notice.
                            Button {
                                showingAnniversaryPicker = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.system(size: 22))
                                        .foregroundColor(Ben.Color.warn)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Set your card anniversary")
                                            .font(Ben.Font.body)
                                            .foregroundColor(Ben.Color.textPrimary)
                                        Text("Your \(anniversaryBenefitName) resets on your account anniversary — set it so Ben tracks it on the right dates.")
                                            .font(Ben.Font.caption)
                                            .foregroundColor(Ben.Color.textMuted)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    Spacer(minLength: 8)

                                    Text("Set")
                                        .font(Ben.Font.body)
                                        .foregroundColor(Ben.Color.forest)
                                }
                                .padding(Ben.Spacing.lg)
                                .background(Ben.Color.warn.opacity(0.10))
                                .cornerRadius(Ben.Radius.lg)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Ben.Radius.lg)
                                        .stroke(Ben.Color.warn.opacity(0.35), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                        }
                    }

                    // Benefits Breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Benefits")
                            .font(Ben.Font.bodyLarge)
                            .foregroundColor(Ben.Color.textPrimary)
                            .padding(.horizontal, 20)

                        ForEach(card.benefits) { benefit in
                            AmexBenefitRow(
                                benefit: benefit,
                                cardId: card.id
                            )
                            .environmentObject(dataManager)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(card.name)
        .toolbar {
            if showBackButton {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 17))
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .toolbarBackground(Ben.Color.cream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showingCapturedBreakdown) {
            BenefitsCapturedBreakdownView(
                title: "Benefits Captured",
                total: totalUtilizedAnnual,
                contributions: BenefitsCapturedBreakdownView.makeContributions(
                    from: utilizations,
                    transactions: dataManager.plaidService.transactions
                ),
                showCardName: false
            )
        }
        .sheet(isPresented: $showingAnniversaryPicker) {
            if let plaidAccount = cardMatch?.plaidAccount {
                EditAnniversaryDateView(
                    card: card,
                    plaidAccount: plaidAccount,
                    currentDate: cardMatch?.anniversaryDate,
                    onSave: { newDate in
                        Task {
                            await dataManager.updateAnniversaryDate(newDate, for: plaidAccount)
                        }
                    }
                )
            }
        }
        .preferredColorScheme(.light)
        // Celebration: first time this card's captured benefits beat its
        // annual fee, rain confetti (once per card, per user).
        .overlay {
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .onAppear { celebrateIfFeeBeaten() }
        .onChange(of: totalUtilizedAnnual) { _, _ in celebrateIfFeeBeaten() }
    }

    // MARK: - Fee-Beaten Celebration

    private func celebrateIfFeeBeaten() {
        guard card.annualFee > 0, totalUtilizedAnnual > card.annualFee else { return }

        var celebrated = CacheManager.shared.load([String].self, for: .celebratedCards) ?? []
        guard !celebrated.contains(card.id) else { return }
        celebrated.append(card.id)
        CacheManager.shared.save(celebrated, for: .celebratedCards)

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { showConfetti = true }

        // Emission stops at ~4s (ConfettiView); remove the overlay once the
        // last particles have fallen through.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(9))
            withAnimation(.easeOut(duration: 0.5)) { showConfetti = false }
        }
    }
}

// MARK: - Amex-Style Benefit Row

struct AmexBenefitRow: View {
    let benefit: CreditCardBenefit
    let cardId: String
    @EnvironmentObject var dataManager: AppDataManager
    @State private var showingTransactions = false
    @State private var showingManualToggle = false

    // All utilization records for this benefit on this card, across periods.
    private var benefitUtilizations: [BenefitUtilization] {
        dataManager.utilizationService.utilizations.filter {
            $0.benefitId == benefit.id && $0.cardId == cardId
        }
    }

    // Current-period record — drives manual marking + manual status, matching
    // the period the manual toggle writes to.
    private var currentUtilization: BenefitUtilization? {
        dataManager.utilizationService.utilizationForBenefit(benefit.id, cardId: cardId)
    }

    // Year-to-date figures so the row reconciles with the "Benefits Captured"
    // hero and its breakdown. A monthly credit captured in earlier months still
    // shows here even if the current month hasn't posted yet (the bug this fixes).
    private var amountUsed: Double {
        BenefitPeriodHelper.yearToDateUtilized(benefitUtilizations)
    }

    private var totalValue: Double {
        benefit.annualAmount
    }

    private var utilizationPercentage: Double {
        guard totalValue > 0 else { return 0 }
        return min(amountUsed / totalValue, 1.0)
    }

    private var matchedTransactions: [Transaction] {
        let ytdRecords = BenefitPeriodHelper.yearToDateRecords(benefitUtilizations)
        let transactionIds = Set(ytdRecords.flatMap { $0.matchedTransactionIds })
        return dataManager.plaidService.transactions.filter { transactionIds.contains($0.id) }
    }

    private var isManuallyMarked: Bool {
        currentUtilization?.isManuallyMarked ?? false
    }

    private var isUsed: Bool {
        amountUsed > 0 || isManuallyMarked
    }

    private var canAutoDetect: Bool {
        benefit.canAutoDetect
    }

    // Wrong-card suggestion targeting this benefit (spend on another card
    // that this benefit would cover).
    private var missedOpportunity: MissedBenefitOpportunity? {
        dataManager.missedOpportunities.first {
            $0.benefit.id == benefit.id && $0.coveringCard.id == cardId
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                if canAutoDetect {
                    // Always show transaction search for auto-detect benefits
                    showingTransactions = true
                } else {
                    // Show manual toggle for non-auto-detect benefits
                    showingManualToggle = true
                }
            }) {
                HStack(spacing: 16) {
                    // Status indicator
                    Circle()
                        .fill(isUsed ? Ben.Color.mintDark : Ben.Color.textMuted.opacity(0.3))
                        .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(benefit.name)
                            .font(Ben.Font.body)
                            .foregroundColor(Ben.Color.textPrimary)

                        if isUsed {
                            if canAutoDetect && amountUsed > 0 {
                                HStack(spacing: 4) {
                                    Text("Used \(amountUsed.asCurrency()) • \(Int((utilizationPercentage * 100).rounded()))% utilized")
                                        .font(Ben.Font.bodySmall)
                                        .foregroundColor(Ben.Color.mintDark)
                                    
                                    if !matchedTransactions.isEmpty {
                                        Text("• \(matchedTransactions.count) transaction\(matchedTransactions.count == 1 ? "" : "s")")
                                            .font(Ben.Font.bodySmall)
                                            .foregroundColor(Ben.Color.forest)
                                    }
                                }
                            } else if isManuallyMarked {
                                Text("Marked as used • \(benefit.annualAmount.asCurrency()) value")
                                    .font(Ben.Font.bodySmall)
                                    .foregroundColor(Ben.Color.mintDark)
                            } else {
                                Text("Not used • \(benefit.annualAmount.asCurrency()) available")
                                    .font(Ben.Font.bodySmall)
                                    .foregroundColor(Ben.Color.textMuted)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Text("Not used • \(benefit.annualAmount.asCurrency()) available")
                                    .font(Ben.Font.bodySmall)
                                    .foregroundColor(Ben.Color.textMuted)

                                if !canAutoDetect {
                                    Text("• Tap to mark")
                                        .font(Ben.Font.bodySmall)
                                        .foregroundColor(Ben.Color.forest)
                                }
                            }
                        }

                        // Wrong-card callout: eligible spend happened elsewhere.
                        if let opportunity = missedOpportunity {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 11))
                                Text("Paid \(opportunity.merchantDisplayName) on \(opportunity.paidCardNames.joined(separator: ", ")) — use this card")
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .font(Ben.Font.caption)
                            .foregroundColor(Ben.Color.warn)
                        }
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Text(benefit.annualAmount.asCurrency())
                            .font(Ben.Font.body)
                            .foregroundColor(Ben.Color.textPrimary)
                        
                        // Always show chevron - all benefits are tappable now
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(Ben.Color.textMuted.opacity(0.5))
                    }
                }
                .benCard()
                .padding(.horizontal, 20)
            }
            .buttonStyle(PlainButtonStyle())
            .sheet(isPresented: $showingTransactions) {
                BenefitTransactionsView(
                    benefit: benefit,
                    amountUsed: amountUsed,
                    totalValue: totalValue,
                    transactions: matchedTransactions,
                    wrongCardTransactions: missedOpportunity?.matchedTransactions ?? []
                )
                .environmentObject(dataManager)
            }
            .sheet(isPresented: $showingManualToggle) {
                ManualBenefitToggleView(
                    benefit: benefit,
                    utilization: currentUtilization,
                    cardId: cardId
                )
            }
        }
    }
}

// MARK: - Benefit Transactions View

struct BenefitTransactionsView: View {
    let benefit: CreditCardBenefit
    let amountUsed: Double
    let totalValue: Double
    let transactions: [Transaction]
    /// Eligible purchases made on OTHER cards (wrong-card opportunities).
    var wrongCardTransactions: [Transaction] = []
    @EnvironmentObject var dataManager: AppDataManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingAllTransactions = false
    @State private var searchText = ""
    
    /// Every transaction across all connected cards, newest first. This box is
    /// meant to be a "search all" tool — scoping it to one card's accounts hid
    /// charges that landed on a different card (and made recent items look
    /// missing).
    private var allTransactions: [Transaction] {
        dataManager.plaidService.transactions
            .sorted(by: { $0.date > $1.date })
    }

    private var filteredTransactions: [Transaction] {
        if searchText.isEmpty {
            return allTransactions
        }
        // Match against both the raw name and Plaid's cleaned merchant_name so
        // a brand like "Uber" is found even when the raw descriptor differs.
        return allTransactions.filter {
            $0.merchant.localizedCaseInsensitiveContains(searchText) ||
            ($0.merchantName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            ($0.category?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Ben.Color.cream.ignoresSafeArea()
                
                List {
                    // Summary Section
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(benefit.name)
                                .font(Ben.Font.bodyLarge)
                                .foregroundColor(Ben.Color.textPrimary)
                            
                            Text(benefit.description)
                                .font(Ben.Font.bodySmall)
                                .foregroundColor(Ben.Color.textMuted)
                            
                            Divider()
                                .background(Ben.Color.sandBorder)
                                .padding(.vertical, 8)

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Used this year")
                                        .font(Ben.Font.caption)
                                        .foregroundColor(Ben.Color.textMuted)
                                    Text(amountUsed.asCurrency())
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(Ben.Color.mintDark)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Remaining")
                                        .font(Ben.Font.caption)
                                        .foregroundColor(Ben.Color.textMuted)
                                    Text(max(totalValue - amountUsed, 0).asCurrency())
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(Ben.Color.textPrimary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Ben.Color.sand)
                    }
                    
                    // Matched Transactions Section
                    if !transactions.isEmpty {
                        Section(header: Text("Auto-Matched Transactions (\(transactions.count))")) {
                            ForEach(transactions.sorted(by: { $0.date > $1.date })) { transaction in
                                TransactionRowView(transaction: transaction)
                                    .listRowBackground(Ben.Color.sand)
                            }
                        }
                    }

                    // Wrong-card purchases: eligible spend made on other cards.
                    if !wrongCardTransactions.isEmpty {
                        Section {
                            ForEach(wrongCardTransactions) { transaction in
                                TransactionRowView(transaction: transaction, showType: true)
                                    .listRowBackground(Ben.Color.sand)
                            }
                        } header: {
                            Text("Eligible Purchases on Other Cards (\(wrongCardTransactions.count))")
                        } footer: {
                            Text("These purchases were made on a card that doesn't carry this benefit. Switching to this card could cover them.")
                        }
                    }
                    
                    // Search All Transactions Section
                    Section(header: Text("Search All Transactions")) {
                        VStack(spacing: 0) {
                            TextField("Search merchant or category", text: $searchText)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(Ben.Color.textMuted.opacity(0.2))
                                .cornerRadius(8)
                                .foregroundColor(Ben.Color.textPrimary)
                            
                            if !searchText.isEmpty {
                                Text("\(filteredTransactions.count) results")
                                    .font(Ben.Font.caption)
                                    .foregroundColor(Ben.Color.textMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 8)
                            }
                        }
                        .listRowBackground(Ben.Color.sand)
                    }
                    
                    if !searchText.isEmpty && !filteredTransactions.isEmpty {
                        Section(header: Text("Search Results")) {
                            ForEach(filteredTransactions.prefix(50)) { transaction in
                                TransactionRowView(transaction: transaction, showType: true)
                                    .listRowBackground(Ben.Color.sand)
                            }
                            
                            if filteredTransactions.count > 50 {
                                Text("Showing first 50 results")
                                    .font(Ben.Font.caption)
                                    .foregroundColor(Ben.Color.textMuted)
                                    .listRowBackground(Ben.Color.sand)
                            }
                        }
                    } else if searchText.isEmpty {
                        Section {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(Ben.Color.textMuted)
                                Text("Search for transactions to debug matching")
                                    .font(Ben.Font.bodySmall)
                                    .foregroundColor(Ben.Color.textMuted)
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(Ben.Color.sand)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Benefit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Ben.Color.forest)
                }
            }
            .preferredColorScheme(.light)
        }
    }
}

// MARK: - Manual Benefit Toggle View

struct ManualBenefitToggleView: View {
    let benefit: CreditCardBenefit
    let utilization: BenefitUtilization?
    let cardId: String
    
    @EnvironmentObject var dataManager: AppDataManager
    @Environment(\.dismiss) private var dismiss
    @State private var isUsing: Bool
    @State private var note: String = ""
    
    init(benefit: CreditCardBenefit, utilization: BenefitUtilization?, cardId: String) {
        self.benefit = benefit
        self.utilization = utilization
        self.cardId = cardId
        self._isUsing = State(initialValue: utilization?.isManuallyMarked ?? false)
        self._note = State(initialValue: utilization?.manualNote ?? "")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Ben.Color.cream.ignoresSafeArea()
                
                Form {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(benefit.name)
                                .font(Ben.Font.bodyLarge)
                                .foregroundColor(Ben.Color.textPrimary)
                            
                            Text(benefit.description)
                                .font(Ben.Font.bodySmall)
                                .foregroundColor(Ben.Color.textMuted)
                            
                            HStack {
                                Text("Annual Value:")
                                    .font(Ben.Font.bodySmall)
                                    .foregroundColor(Ben.Color.textMuted)
                                Spacer()
                                Text(benefit.annualAmount.asCurrency())
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Ben.Color.mintDark)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Ben.Color.sand)
                    }
                    
                    Section(header: Text("Usage Status")) {
                        Toggle(isOn: $isUsing) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("I'm using this benefit")
                                    .font(Ben.Font.body)
                                    .foregroundColor(Ben.Color.textPrimary)
                                Text("Mark if you're actively using this benefit")
                                    .font(Ben.Font.caption)
                                    .foregroundColor(Ben.Color.textMuted)
                            }
                        }
                        .tint(Ben.Color.mintDark)
                        .listRowBackground(Ben.Color.sand)
                    }
                    
                    if isUsing {
                        Section(header: Text("Notes (Optional)")) {
                            TextField("Add a note", text: $note, axis: .vertical)
                                .lineLimit(3...6)
                                .foregroundColor(Ben.Color.textPrimary)
                                .listRowBackground(Ben.Color.sand)
                        }
                    }
                    
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Can't auto-detect", systemImage: "info.circle")
                                .font(Ben.Font.bodySmall)
                                .foregroundColor(Ben.Color.forest)
                            
                            Text("This benefit is delivered outside of credit card transactions (e.g., credits added to partner apps). Use this toggle to manually track if you're using it.")
                                .font(Ben.Font.caption)
                                .foregroundColor(Ben.Color.textMuted)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Ben.Color.sand)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Track Benefit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Ben.Color.forest)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveBenefitStatus()
                            dismiss()
                        }
                    }
                    .foregroundColor(Ben.Color.forest)
                    .fontWeight(.semibold)
                }
            }
            .preferredColorScheme(.light)
        }
    }

    private func saveBenefitStatus() async {
        if isUsing {
            // Mark as used with full value
            await dataManager.markBenefitUsed(
                benefitId: benefit.id,
                cardId: cardId,
                amount: benefit.annualAmount,
                note: note.isEmpty ? nil : note
            )
        } else {
            // Mark as unused (amount = 0)
            await dataManager.markBenefitUsed(
                benefitId: benefit.id,
                cardId: cardId,
                amount: 0,
                note: nil
            )
        }
    }
}

// MARK: - Transaction Row View

struct TransactionRowView: View {
    let transaction: Transaction
    var showType: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Date badge
            VStack(spacing: 2) {
                Text(transaction.date.formatted(.dateTime.month(.abbreviated)))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Ben.Color.textMuted)
                Text("\(Calendar.current.component(.day, from: transaction.date))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Ben.Color.textPrimary)
            }
            .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchant)
                    .font(Ben.Font.body)
                    .foregroundColor(Ben.Color.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    if let category = transaction.category {
                        Text(category)
                            .font(Ben.Font.caption)
                            .foregroundColor(Ben.Color.textMuted)
                    }
                    
                    if showType {
                        Text("•")
                            .foregroundColor(Ben.Color.textMuted.opacity(0.5))
                        Text(transaction.isCredit ? "Credit" : "Purchase")
                            .font(Ben.Font.caption)
                            .foregroundColor(transaction.isCredit ? Ben.Color.mintDark : Ben.Color.forest)
                    }
                }
            }
            
            Spacer()
            
            Text((transaction.isCredit ? "-" : "") + transaction.amount.asCurrency())
                .font(Ben.Font.body)
                .foregroundColor(transaction.isCredit ? Ben.Color.mintDark : Ben.Color.textPrimary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Edit Anniversary Date View

struct EditAnniversaryDateView: View {
    let card: CreditCard
    let plaidAccount: PlaidAccount
    let currentDate: Date?
    let onSave: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMonth: Int
    @State private var selectedDay: Int

    init(card: CreditCard, plaidAccount: PlaidAccount, currentDate: Date?, onSave: @escaping (Date) -> Void) {
        self.card = card
        self.plaidAccount = plaidAccount
        self.currentDate = currentDate
        self.onSave = onSave
        let calendar = Calendar.current
        let initial = currentDate ?? Date()
        _selectedMonth = State(initialValue: calendar.component(.month, from: initial))
        _selectedDay = State(initialValue: calendar.component(.day, from: initial))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Card Anniversary")
                            .font(.headline)
                        Text("Annual benefits reset on this month and day each year.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("Select Anniversary")) {
                    MonthDayPicker(month: $selectedMonth, day: $selectedDay)

                    Text("Pick the month and day your account was opened. For example, if you opened your account on September 22, set it to September 22.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(card.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(AnniversaryDateHelper.makeDate(month: selectedMonth, day: selectedDay))
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CardDetailView(
            card: MockData.userCards[0],
            allCards: MockData.userCards
        )
        .environmentObject(AppDataManager())
    }
}
