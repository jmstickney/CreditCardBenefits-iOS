//
//  CardSelectionView.swift
//  CreditCardBenefits
//
//  UI for selecting which credit card each Plaid account is
//

import SwiftUI

struct CardSelectionView: View {
    @EnvironmentObject var dataManager: AppDataManager
    @Environment(\.dismiss) private var dismiss

    private var unconfirmedMatches: [CardMatch] {
        dataManager.cardMatches.filter { !$0.isConfirmed }
    }

    private var confirmedMatches: [CardMatch] {
        dataManager.cardMatches.filter { $0.isConfirmed }
    }

    var body: some View {
        NavigationStack {
            List {
                // Instructions
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Your Cards")
                            .font(.headline)
                        Text("We found credit card accounts in your linked bank. Please select which card each account is so we can track your benefits.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Accounts needing selection
                if !unconfirmedMatches.isEmpty {
                    Section(header: Text("Needs Selection")) {
                        ForEach(unconfirmedMatches) { match in
                            CardMatchRow(match: match)
                        }
                    }
                }

                // Already confirmed accounts
                if !confirmedMatches.isEmpty {
                    Section(header: Text("Confirmed")) {
                        ForEach(confirmedMatches) { match in
                            CardMatchRow(match: match)
                        }
                    }
                }
            }
            .navigationTitle("Your Cards")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dataManager.needsCardConfirmation = false
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Card Match Row

struct CardMatchRow: View {
    let match: CardMatch
    @EnvironmentObject var dataManager: AppDataManager
    @State private var showingPicker = false

    var body: some View {
        Button {
            showingPicker = true
        } label: {
            HStack(spacing: 12) {
                // Status icon
                if match.isConfirmed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                } else {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                }

                // Account info
                VStack(alignment: .leading, spacing: 4) {
                    Text(match.plaidAccount.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let mask = match.plaidAccount.mask {
                        Text("•••• \(mask)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Selected card or prompt
                    if let card = match.creditCard {
                        HStack(spacing: 4) {
                            Text(card.name)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            Text("• \(card.benefits.count) benefits")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Tap to select card type")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .sheet(isPresented: $showingPicker) {
            CardPickerView(plaidAccount: match.plaidAccount, currentCard: match.creditCard)
        }
    }
}

// MARK: - Card Picker View

struct CardPickerView: View {
    let plaidAccount: PlaidAccount
    let currentCard: CreditCard?

    @EnvironmentObject var dataManager: AppDataManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCard: CreditCard?
    @State private var showingAnniversaryPicker = false

    // Cards already assigned to OTHER accounts (not this one)
    private var alreadyAssignedCardIds: Set<String> {
        Set(dataManager.cardMatches
            .filter { $0.plaidAccount.id != plaidAccount.id && $0.creditCard != nil }
            .compactMap { $0.creditCard?.id })
    }

    // Available cards (not already assigned elsewhere)
    private var availableCards: [CreditCard] {
        CreditCardsData.allCards.filter { card in
            !alreadyAssignedCardIds.contains(card.id)
        }
    }

    // Group available cards by issuer
    private var cardsByIssuer: [(issuer: CardIssuer, cards: [CreditCard])] {
        let grouped = Dictionary(grouping: availableCards) { $0.issuer }
        return grouped
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { (issuer: $0.key, cards: $0.value) }
            .filter { !$0.cards.isEmpty }  // Only show issuers with available cards
    }
    
    // Check if the selected card has any cardmemberYear benefits
    private func needsAnniversaryDate(for card: CreditCard) -> Bool {
        card.benefits.contains { $0.period == .cardmemberYear }
    }

    var body: some View {
        NavigationStack {
            List {
                // Header showing which account we're selecting for
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Which card is this?")
                            .font(.headline)

                        HStack {
                            Image(systemName: "creditcard.fill")
                                .foregroundColor(.blue)
                            Text(plaidAccount.name)
                                .font(.subheadline)
                            if let mask = plaidAccount.mask {
                                Text("•••• \(mask)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Supported cards grouped by issuer
                ForEach(cardsByIssuer, id: \.issuer) { group in
                    Section(header: Text(group.issuer.rawValue)) {
                        ForEach(group.cards) { card in
                            Button {
                                // Check if card needs anniversary date
                                if needsAnniversaryDate(for: card) {
                                    selectedCard = card
                                    showingAnniversaryPicker = true
                                } else {
                                    Task {
                                        await dataManager.assignCard(card, to: plaidAccount, anniversaryDate: nil)
                                        dismiss()
                                    }
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(card.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)

                                        HStack(spacing: 8) {
                                            Text("$\(Int(card.annualFee))/year")
                                                .font(.caption)
                                                .foregroundColor(.secondary)

                                            Text("•")
                                                .foregroundColor(.secondary)

                                            Text("\(card.benefits.count) benefits")
                                                .font(.caption)
                                                .foregroundColor(.secondary)

                                            Text("•")
                                                .foregroundColor(.secondary)

                                            Text("$\(Int(card.totalBenefitsValue)) value")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                    }

                                    Spacer()

                                    if currentCard?.id == card.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                // Option for cards not in the database
                Section {
                    Button {
                        Task {
                            await dataManager.assignCard(nil, to: plaidAccount, anniversaryDate: nil)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.secondary)
                            Text("My card isn't listed")
                                .foregroundColor(.secondary)
                        }
                    }

                    if !alreadyAssignedCardIds.isEmpty {
                        Text("Some cards are hidden because they're already linked to another account.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("We currently support premium travel cards. More cards coming soon!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Select Card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAnniversaryPicker) {
                if let card = selectedCard {
                    AnniversaryDatePickerView(
                        card: card,
                        plaidAccount: plaidAccount,
                        onSave: { date in
                            Task {
                                await dataManager.assignCard(card, to: plaidAccount, anniversaryDate: date)
                                dismiss()
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Anniversary Date Picker View

struct AnniversaryDatePickerView: View {
    let card: CreditCard
    let plaidAccount: PlaidAccount
    let onSave: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedDay: Int = Calendar.current.component(.day, from: Date())

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

                    Text("Pick the month and day your account was opened.")
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
                    }
                }
            }
        }
    }
}

// MARK: - Month/Day Picker

struct MonthDayPicker: View {
    @Binding var month: Int
    @Binding var day: Int

    private let monthNames = Calendar.current.monthSymbols

    private var daysInMonth: Int {
        var components = DateComponents()
        components.year = 2024  // leap year so Feb 29 is selectable
        components.month = month
        if let date = Calendar.current.date(from: components),
           let range = Calendar.current.range(of: .day, in: .month, for: date) {
            return range.count
        }
        return 31
    }

    var body: some View {
        HStack(spacing: 0) {
            Picker("Month", selection: $month) {
                ForEach(1...12, id: \.self) { m in
                    Text(monthNames[m - 1]).tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)

            Picker("Day", selection: $day) {
                ForEach(1...daysInMonth, id: \.self) { d in
                    Text("\(d)").tag(d)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: month) { _, _ in
            if day > daysInMonth {
                day = daysInMonth
            }
        }
    }
}

// MARK: - Anniversary Date Helper

enum AnniversaryDateHelper {
    /// Builds a Date from a month/day, using a leap year so Feb 29 is representable.
    /// Only the month and day are meaningful; downstream logic ignores the year.
    static func makeDate(month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = 2024
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }

    /// Formats a stored anniversary Date as "Month Day" (year stripped).
    static func displayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    CardSelectionView()
        .environmentObject(AppDataManager())
}
