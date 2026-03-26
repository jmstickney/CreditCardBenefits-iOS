import SwiftUI

/// Simple cards list view for the Cards tab
/// Shows all connected cards with utilization info
struct CardsListView: View {
    @EnvironmentObject var dataManager: AppDataManager
    @State private var showingAddCard = false
    @State private var linkToken: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Ben.Spacing.md) {
                // Header
                VStack(alignment: .leading, spacing: Ben.Spacing.xs) {
                    Text("Your Cards")
                        .font(Ben.Font.screenTitle)
                        .foregroundColor(Ben.Color.textPrimary)

                    Text("\(dataManager.userCards.count) connected")
                        .font(Ben.Font.bodySmall)
                        .foregroundColor(Ben.Color.textMuted)
                }
                .padding(.horizontal, Ben.Spacing.screenH)
                .padding(.top, Ben.Spacing.lg)

                // Card list
                if dataManager.userCards.isEmpty {
                    EmptyCardsView()
                } else {
                    ForEach(dataManager.userCards) { card in
                        NavigationLink(destination: SwipeableCardDetailView(
                            initialCard: card,
                            allCards: dataManager.userCards
                        )) {
                            CardListRow(
                                card: card,
                                utilizations: dataManager.utilizationService.utilizationsForCard(card.id)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                Spacer(minLength: 100)
            }
        }
        .benBackground()
    }
}

// MARK: - Card List Row
private struct CardListRow: View {
    let card: CreditCard
    let utilizations: [BenefitUtilization]

    private var totalUtilized: Double {
        utilizations.reduce(0) { $0 + $1.amountUtilized }
    }

    private var unusedBenefits: Int {
        let usedBenefitIds = Set(utilizations.filter { $0.amountUtilized > 0 }.map { $0.benefitId })
        return card.benefits.count - usedBenefitIds.count
    }

    var body: some View {
        HStack(spacing: Ben.Spacing.md) {
            // Card thumbnail
            RoundedRectangle(cornerRadius: Ben.Radius.md)
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

            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(Ben.Font.body)
                    .foregroundColor(Ben.Color.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Ben.Spacing.xs) {
                    Text(totalUtilized.asCurrency())
                        .font(Ben.Font.bodySmall)
                        .foregroundColor(Ben.Color.mintDark)

                    Text("•")
                        .foregroundColor(Ben.Color.textMuted)

                    if unusedBenefits > 0 {
                        Text("\(unusedBenefits) unused")
                            .font(Ben.Font.bodySmall)
                            .foregroundColor(Ben.Color.warn)
                    } else {
                        Text("All benefits active")
                            .font(Ben.Font.bodySmall)
                            .foregroundColor(Ben.Color.mintDark)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Ben.Color.textMuted.opacity(0.5))
        }
        .benCard()
        .padding(.horizontal, Ben.Spacing.screenH)
    }
}

// MARK: - Empty State
private struct EmptyCardsView: View {
    var body: some View {
        VStack(spacing: Ben.Spacing.md) {
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
        .padding(.horizontal, Ben.Spacing.screenH)
    }
}

#Preview {
    NavigationStack {
        CardsListView()
    }
    .environmentObject(AppDataManager())
}
