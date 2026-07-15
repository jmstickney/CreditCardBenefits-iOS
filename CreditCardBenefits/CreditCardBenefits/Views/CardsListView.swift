import SwiftUI

/// Simple cards list view for the Cards tab
/// Shows all connected cards with utilization info
struct CardsListView: View {
    @EnvironmentObject var dataManager: AppDataManager
    @State private var linkTokenItem: LinkTokenItem?
    @State private var showSignIn = false

    private struct LinkTokenItem: Identifiable {
        let id = UUID()
        let token: String
    }

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
                    EmptyAccountsView { startAddCard() }
                        .padding(.horizontal, Ben.Spacing.screenH)
                } else {
                    VStack(spacing: 0) {
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

                            // Separator between cards (except last one)
                            if card.id != dataManager.userCards.last?.id {
                                Divider()
                                    .padding(.leading, 88)
                            }
                        }
                    }
                    .background(Ben.Color.sand)
                    .cornerRadius(Ben.Radius.lg)
                    .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                    .padding(.horizontal, Ben.Spacing.screenH)
                }

                Spacer(minLength: 100)
            }
        }
        .benBackground()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    startAddCard()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Ben.Color.forest)
                }
            }
        }
        .authGate(isPresented: $showSignIn, dataManager: dataManager) {
            Task { await handleAddCard() }
        }
        .sheet(item: $linkTokenItem) { item in
            PlaidLinkView(
                linkToken: item.token,
                onSuccess: { publicToken in
                    Task {
                        await dataManager.plaidService.exchangePublicToken(publicToken)
                        await dataManager.processPlaidAccounts()
                        linkTokenItem = nil
                    }
                },
                onExit: {
                    linkTokenItem = nil
                }
            )
        }
    }

    // MARK: - Add Card

    /// Same gating as Home's "+": connect if signed in, otherwise prompt sign-in.
    private func startAddCard() {
        if dataManager.authService.isAuthenticated {
            Task { await handleAddCard() }
        } else {
            showSignIn = true
        }
    }

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
}

// MARK: - Card List Row
private struct CardListRow: View {
    let card: CreditCard
    let utilizations: [BenefitUtilization]

    // Year-to-date, matching the card detail screen's "Benefits Captured"
    // hero. A plain sum over `utilizations` counts every historical period
    // (e.g. a monthly credit × many months), which doesn't reconcile with the
    // detail view and makes the figure look like it comes from nowhere.
    private var totalUtilized: Double {
        BenefitPeriodHelper.yearToDateUtilized(utilizations)
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
        .contentShape(Rectangle())
        .padding(Ben.Spacing.lg)
    }
}

#Preview {
    NavigationStack {
        CardsListView()
    }
    .environmentObject(AppDataManager())
}
