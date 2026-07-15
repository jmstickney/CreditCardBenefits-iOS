//
//  BenefitsCapturedBreakdownView.swift
//  CreditCardBenefits
//
//  Drill-in for the "Benefits Captured" hero: lists every benefit that makes
//  up the year-to-date captured total, each expandable to the exact matched
//  transactions. Helps everyday users understand the number — and helps debug
//  why a figure is what it is.
//

import SwiftUI

// MARK: - Contribution model

/// One benefit's year-to-date contribution to a "Benefits Captured" total.
struct CapturedContribution: Identifiable {
    let id = UUID()
    let cardId: String
    let cardName: String
    let benefit: CreditCardBenefit
    let capturedYTD: Double
    let matchedTransactions: [Transaction]
}

// MARK: - Breakdown sheet

struct BenefitsCapturedBreakdownView: View {
    let title: String
    let total: Double
    let contributions: [CapturedContribution]
    /// Show the source card on each row (true for the aggregate/home view,
    /// false on a single card's detail screen where it's redundant).
    let showCardName: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Ben.Color.cream.ignoresSafeArea()

                List {
                    // Total summary — reconciles with the hero card.
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Captured year-to-date")
                                .font(Ben.Font.caption)
                                .foregroundColor(Ben.Color.textMuted)
                            Text(total.asCurrency())
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Ben.Color.textPrimary)
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Ben.Color.sand)
                    }

                    if contributions.isEmpty {
                        Section {
                            Text("No benefits captured yet this year. As statement credits post and transactions match, they'll appear here.")
                                .font(Ben.Font.bodySmall)
                                .foregroundColor(Ben.Color.textMuted)
                                .padding(.vertical, 4)
                                .listRowBackground(Ben.Color.sand)
                        }
                    } else {
                        Section(header: Text("Contributing Benefits (\(contributions.count))")) {
                            ForEach(contributions) { contribution in
                                ContributionRow(
                                    contribution: contribution,
                                    showCardName: showCardName
                                )
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(title)
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

// MARK: - Row

private struct ContributionRow: View {
    let contribution: CapturedContribution
    let showCardName: Bool
    @State private var expanded = false

    private var transactionCountLabel: String {
        let count = contribution.matchedTransactions.count
        return "\(count) transaction\(count == 1 ? "" : "s")"
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            if contribution.matchedTransactions.isEmpty {
                Text("No matched transactions — marked manually or applied outside of card transactions.")
                    .font(Ben.Font.caption)
                    .foregroundColor(Ben.Color.textMuted)
                    .padding(.vertical, 4)
            } else {
                ForEach(contribution.matchedTransactions) { transaction in
                    TransactionRowView(transaction: transaction, showType: true)
                }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(contribution.benefit.name)
                        .font(Ben.Font.body)
                        .foregroundColor(Ben.Color.textPrimary)

                    if showCardName {
                        Text(contribution.cardName)
                            .font(Ben.Font.caption)
                            .foregroundColor(Ben.Color.textMuted)
                    }

                    Text(transactionCountLabel)
                        .font(Ben.Font.caption)
                        .foregroundColor(Ben.Color.textMuted)
                }

                Spacer()

                Text(contribution.capturedYTD.asCurrency())
                    .font(Ben.Font.body)
                    .foregroundColor(Ben.Color.mintDark)
            }
        }
        .tint(Ben.Color.forest)
        .listRowBackground(Ben.Color.sand)
    }
}

// MARK: - Builder

extension BenefitsCapturedBreakdownView {

    /// Builds the per-benefit year-to-date contributions that sum to a
    /// "Benefits Captured" total, largest first. Only benefits with a positive
    /// captured amount are included — i.e. the ones actually applying to the
    /// value. The per-row amounts add up to `yearToDateUtilized(utilizations)`.
    static func makeContributions(
        from utilizations: [BenefitUtilization],
        transactions: [Transaction]
    ) -> [CapturedContribution] {
        let ytdRecords = BenefitPeriodHelper.yearToDateRecords(utilizations)
        let grouped = Dictionary(grouping: ytdRecords) {
            ContributionKey(cardId: $0.cardId, benefitId: $0.benefitId)
        }

        var result: [CapturedContribution] = []
        for (key, records) in grouped {
            let captured = records.reduce(0.0) { $0 + $1.amountUtilized }
            guard captured > 0,
                  let benefit = CreditCardsData.getBenefit(by: key.benefitId) else {
                continue
            }

            let txnIds = Set(records.flatMap { $0.matchedTransactionIds })
            let matched = transactions
                .filter { txnIds.contains($0.id) }
                .sorted { $0.date > $1.date }

            result.append(CapturedContribution(
                cardId: key.cardId,
                cardName: CreditCardsData.getCard(by: key.cardId)?.name ?? "Card",
                benefit: benefit,
                capturedYTD: captured,
                matchedTransactions: matched
            ))
        }

        return result.sorted { $0.capturedYTD > $1.capturedYTD }
    }
}

private struct ContributionKey: Hashable {
    let cardId: String
    let benefitId: String
}
