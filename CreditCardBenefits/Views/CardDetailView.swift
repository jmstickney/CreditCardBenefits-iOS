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

    private var utilizations: [BenefitUtilization] {
        dataManager.utilizationService.utilizationsForCard(card.id)
    }
    
    private var totalUtilized: Double {
        utilizations.reduce(0) { $0 + $1.amountUtilized }
    }
    
    private var cardMatch: CardMatch? {
        dataManager.cardMatches.first { $0.creditCard?.id == card.id }
    }
    
    private var hasCardmemberYearBenefits: Bool {
        card.benefits.contains { $0.period == .cardmemberYear }
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
                                .foregroundColor(Ben.Color.cream)
                            
                            Text("•••• \(String(card.id.suffix(4)))")
                                .font(.system(size: 14))
                                .foregroundColor(Ben.Color.cream.opacity(0.9))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 80)
                    .padding(.bottom, 32)

                    // Annual Fee Section
                    VStack(spacing: 16) {
                        HStack {
                            Text("Annual Fee")
                                .font(Ben.Font.bodySmall)
                                .foregroundColor(Ben.Color.textMuted)
                            
                            Spacer()
                        }
                        
                        HStack(alignment: .firstTextBaseline) {
                            Text(card.annualFee.asCurrency())
                                .font(Ben.Font.heroNumber)
                                .foregroundColor(Ben.Color.textPrimary)
                            
                            Spacer()
                        }
                        
                        // Benefit usage summary
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Benefits Utilized")
                                    .font(Ben.Font.bodySmall)
                                    .foregroundColor(Ben.Color.textMuted)
                                Spacer()
                                Text(totalUtilized.asCurrency())
                                    .font(Ben.Font.body)
                                    .foregroundColor(Ben.Color.mintDark)
                            }
                            
                            HStack {
                                Text("Total Benefits Available")
                                    .font(Ben.Font.bodySmall)
                                    .foregroundColor(Ben.Color.textMuted)
                                Spacer()
                                Text(card.totalBenefitsValue.asCurrency())
                                    .font(Ben.Font.body)
                                    .foregroundColor(Ben.Color.textBody)
                            }
                            
                            Divider()
                                .background(Ben.Color.sandBorder)
                                .padding(.vertical, 8)
                            
                            HStack {
                                Text("Net Value")
                                    .font(Ben.Font.body)
                                    .foregroundColor(Ben.Color.textMuted)
                                Spacer()
                                Text((totalUtilized - card.annualFee).asCurrency())
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor((totalUtilized - card.annualFee) >= 0 ? Ben.Color.mintDark : Ben.Color.warn)
                            }
                        }
                        .benCard()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    
                    // Anniversary Date Section (only if card has cardmemberYear benefits)
                    if hasCardmemberYearBenefits {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Card Anniversary")
                                    .font(Ben.Font.bodySmall)
                                    .foregroundColor(Ben.Color.textMuted)
                                
                                Spacer()
                                
                                Button {
                                    showingAnniversaryPicker = true
                                } label: {
                                    Text(cardMatch?.anniversaryDate != nil ? "Edit" : "Set Date")
                                        .font(Ben.Font.body)
                                        .foregroundColor(Ben.Color.forest)
                                }
                            }
                            
                            HStack {
                                if let anniversaryDate = cardMatch?.anniversaryDate {
                                    Text(anniversaryDate.formatted(date: .abbreviated, time: .omitted))
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(Ben.Color.textPrimary)
                                } else {
                                    Text("Not set")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(Ben.Color.warn)
                                }
                                
                                Spacer()
                            }
                            
                            Text("Used to track annual benefits that reset on your account anniversary")
                                .font(Ben.Font.caption)
                                .foregroundColor(Ben.Color.textMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .benCard()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
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
                                utilization: utilizations.first { $0.benefitId == benefit.id }
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
        .preferredColorScheme(.dark)
    }
}

// MARK: - Amex-Style Benefit Row

struct AmexBenefitRow: View {
    let benefit: CreditCardBenefit
    let utilization: BenefitUtilization?
    @EnvironmentObject var dataManager: AppDataManager
    @State private var showingTransactions = false
    @State private var showingManualToggle = false

    private var isUsed: Bool {
        guard let utilization = utilization else { return false }
        return utilization.amountUtilized > 0 || utilization.isManuallyMarked
    }

    private var amountUsed: Double {
        utilization?.amountUtilized ?? 0
    }

    private var utilizationPercentage: Double {
        utilization?.utilizationPercentage ?? 0
    }
    
    private var matchedTransactions: [Transaction] {
        guard let utilization = utilization else { return [] }
        let transactionIds = Set(utilization.matchedTransactionIds)
        return dataManager.plaidService.transactions.filter { transactionIds.contains($0.id) }
    }
    
    private var isManuallyMarked: Bool {
        utilization?.isManuallyMarked ?? false
    }
    
    private var canAutoDetect: Bool {
        benefit.canAutoDetect
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
                                    Text("Used \(amountUsed.asCurrency()) • \((utilizationPercentage * 100).rounded())% utilized")
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
                    utilization: utilization,
                    transactions: matchedTransactions
                )
                .environmentObject(dataManager)
            }
            .sheet(isPresented: $showingManualToggle) {
                ManualBenefitToggleView(
                    benefit: benefit,
                    utilization: utilization,
                    cardId: dataManager.userCards.first(where: { $0.benefits.contains(where: { $0.id == benefit.id }) })?.id ?? ""
                )
            }
        }
    }
}

// MARK: - Benefit Transactions View

struct BenefitTransactionsView: View {
    let benefit: CreditCardBenefit
    let utilization: BenefitUtilization?
    let transactions: [Transaction]
    @EnvironmentObject var dataManager: AppDataManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingAllTransactions = false
    @State private var searchText = ""
    
    private var cardTransactions: [Transaction] {
        // Get all transactions from the card's accounts
        guard let card = dataManager.userCards.first(where: { $0.benefits.contains(where: { $0.id == benefit.id }) }) else {
            return []
        }
        
        let accountIds = dataManager.cardMatches
            .filter { $0.creditCard?.id == card.id }
            .map { $0.plaidAccount.id }
        
        return dataManager.plaidService.transactions
            .filter { accountIds.contains($0.accountId) }
            .sorted(by: { $0.date > $1.date })
    }
    
    private var filteredTransactions: [Transaction] {
        if searchText.isEmpty {
            return cardTransactions
        }
        return cardTransactions.filter {
            $0.merchant.localizedCaseInsensitiveContains(searchText) ||
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
                            
                            if let utilization = utilization {
                                Divider()
                                    .background(Ben.Color.sandBorder)
                                    .padding(.vertical, 8)
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Amount Used")
                                            .font(Ben.Font.caption)
                                            .foregroundColor(Ben.Color.textMuted)
                                        Text(utilization.amountUtilized.asCurrency())
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(Ben.Color.mintDark)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Remaining")
                                            .font(Ben.Font.caption)
                                            .foregroundColor(Ben.Color.textMuted)
                                        Text(utilization.amountRemaining.asCurrency())
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(Ben.Color.textPrimary)
                                    }
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
            .preferredColorScheme(.dark)
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
    @State private var selectedDate: Date
    
    init(card: CreditCard, plaidAccount: PlaidAccount, currentDate: Date?, onSave: @escaping (Date) -> Void) {
        self.card = card
        self.plaidAccount = plaidAccount
        self.currentDate = currentDate
        self.onSave = onSave
        _selectedDate = State(initialValue: currentDate ?? Date())
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Card Anniversary Date")
                            .font(.headline)
                        Text("This date is used to track annual benefits that reset on your account anniversary.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Select Anniversary Date")) {
                    DatePicker(
                        "Anniversary Date",
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    
                    Text("This is usually the date you opened your account. For example, if you opened your account on September 22, 2023, set it to September 22.")
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
                        onSave(selectedDate)
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
