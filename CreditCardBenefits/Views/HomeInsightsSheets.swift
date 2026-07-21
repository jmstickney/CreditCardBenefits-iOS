//
//  HomeInsightsSheets.swift
//  CreditCardBenefits
//
//  Breakdown sheets behind the Home summary chips, mirroring the
//  "Benefits Captured" drill-in pattern (BenefitsCapturedBreakdownView):
//  - SavingsOpportunitiesSheet: every wrong-card suggestion, expandable to its
//    transactions, dismissible permanently.
//  - RemindersSheet: every expiring benefit credit with value left.
//

import SwiftUI

// MARK: - Savings Opportunities Sheet

struct SavingsOpportunitiesSheet: View {
    @EnvironmentObject var dataManager: AppDataManager
    @Environment(\.dismiss) private var dismiss
    @State private var dismissCandidate: MissedBenefitOpportunity?

    private var totalAnnualValue: Double {
        dataManager.missedOpportunities.reduce(0.0) { $0 + $1.benefit.annualAmount }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Ben.Color.cream.ignoresSafeArea()

                List {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Potential savings")
                                .font(Ben.Font.caption)
                                .foregroundColor(Ben.Color.textMuted)
                            Text("Up to \(totalAnnualValue.asCurrency())/yr")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Ben.Color.mintDark)
                            Text("Purchases made on a card that doesn't carry the benefit, while another of your cards covers it.")
                                .font(Ben.Font.caption)
                                .foregroundColor(Ben.Color.textMuted)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Ben.Color.sand)
                    }

                    if dataManager.missedOpportunities.isEmpty {
                        Section {
                            Text("No savings opportunities right now — you're using the right cards. 🎉")
                                .font(Ben.Font.bodySmall)
                                .foregroundColor(Ben.Color.textMuted)
                                .padding(.vertical, 4)
                                .listRowBackground(Ben.Color.sand)
                        }
                    } else {
                        Section(header: Text("Opportunities (\(dataManager.missedOpportunities.count))")) {
                            ForEach(dataManager.missedOpportunities) { opportunity in
                                OpportunityRow(
                                    opportunity: opportunity,
                                    onDismiss: { dismissCandidate = opportunity }
                                )
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Savings Opportunities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Ben.Color.forest)
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
            .preferredColorScheme(.light)
        }
    }
}

private struct OpportunityRow: View {
    let opportunity: MissedBenefitOpportunity
    let onDismiss: () -> Void
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ForEach(opportunity.matchedTransactions) { transaction in
                TransactionRowView(transaction: transaction, showType: true)
            }

            Button(role: .destructive, action: onDismiss) {
                Label("Hide this suggestion permanently", systemImage: "eye.slash")
                    .font(Ben.Font.bodySmall)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 15))
                    .foregroundColor(Ben.Color.mintDark)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(opportunity.merchantDisplayName) — paid on \(opportunity.paidCardNames.joined(separator: ", "))")
                        .font(Ben.Font.body)
                        .foregroundColor(Ben.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Use \(opportunity.coveringCard.name): \(opportunity.benefit.name)")
                        .font(Ben.Font.caption)
                        .foregroundColor(Ben.Color.textMuted)
                }

                Spacer()

                Text("\(opportunity.benefit.annualAmount.asCurrency())/yr")
                    .font(Ben.Font.bodySmall)
                    .foregroundColor(Ben.Color.mintDark)
            }
        }
        .tint(Ben.Color.forest)
        .listRowBackground(Ben.Color.sand)
    }
}

// MARK: - Reminders Sheet

struct RemindersSheet: View {
    @EnvironmentObject var dataManager: AppDataManager
    @Environment(\.dismiss) private var dismiss

    private var totalRemaining: Double {
        dataManager.expiringReminders.reduce(0.0) { $0 + $1.remaining }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Ben.Color.cream.ignoresSafeArea()

                List {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Expiring soon")
                                .font(Ben.Font.caption)
                                .foregroundColor(Ben.Color.textMuted)
                            Text("\(totalRemaining.asCurrency()) left to use")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Ben.Color.warn)
                            Text("Benefit credits with value remaining before their period resets.")
                                .font(Ben.Font.caption)
                                .foregroundColor(Ben.Color.textMuted)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Ben.Color.sand)
                    }

                    if dataManager.expiringReminders.isEmpty {
                        Section {
                            Text("Nothing expiring soon — you're all caught up.")
                                .font(Ben.Font.bodySmall)
                                .foregroundColor(Ben.Color.textMuted)
                                .padding(.vertical, 4)
                                .listRowBackground(Ben.Color.sand)
                        }
                    } else {
                        Section {
                            ForEach(dataManager.expiringReminders) { reminder in
                                HStack(spacing: 12) {
                                    Image(systemName: "hourglass")
                                        .font(.system(size: 15))
                                        .foregroundColor(Ben.Color.warn)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(reminder.benefit.name)
                                            .font(Ben.Font.body)
                                            .foregroundColor(Ben.Color.textPrimary)
                                        Text("\(reminder.daysLeft == 1 ? "Resets tomorrow" : "Resets in \(reminder.daysLeft) days") • \(reminder.card.name)")
                                            .font(Ben.Font.caption)
                                            .foregroundColor(Ben.Color.textMuted)
                                    }

                                    Spacer()

                                    Text("\(reminder.remaining.asCurrency()) left")
                                        .font(Ben.Font.bodySmall)
                                        .foregroundColor(Ben.Color.warn)
                                }
                                .listRowBackground(Ben.Color.sand)
                            }
                        } header: {
                            Text("Reminders (\(dataManager.expiringReminders.count))")
                        } footer: {
                            Text("Monthly credits appear within 7 days of their reset; annual credits within 30 days.")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Ben.Color.forest)
                }
            }
            .preferredColorScheme(.light)
        }
    }
}
