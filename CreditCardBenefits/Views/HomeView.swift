//
//  HomeView.swift
//  CreditCardBenefits
//
//  Created for Credit Card Benefits Tracker POC
//  Redesigned with Amex-inspired dark theme
//

import SwiftUI
import Combine

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedCard: CreditCard?

    var body: some View {
        NavigationView {
            ZStack {
                // Dynamic background (adapts to system appearance)
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text(getCurrentDateString())
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)

                            Text("Welcome")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 20)

                        // Summary Stats Card
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Total Benefits")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                    Text(formatCurrency(viewModel.stats.potentialSavings))
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(.primary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Utilized")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                    Text("$0.00")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.green)
                                }
                            }

                            Divider()
                                .background(Color.secondary.opacity(0.3))

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Monthly Subscriptions")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                    Text(formatCurrency(viewModel.stats.monthlySubscriptionCost))
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.primary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Active Cards")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                    Text("\(viewModel.stats.activeCards)")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)

                        // Cards Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Your Cards")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.primary)

                                Spacer()

                                Button(action: {}) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
                                }
                            }
                            .padding(.horizontal)

                            ForEach(MockData.userCards) { card in
                                NavigationLink(destination: CardDetailView(card: card)) {
                                    CardRowView(card: card, matches: viewModel.getMatches(for: card))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }

                        // Subscriptions Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Recent Subscriptions")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.horizontal)

                            ForEach(viewModel.subscriptions.prefix(5)) { subscription in
                                SubscriptionRowDark(subscription: subscription)
                            }
                        }
                        .padding(.top)

                        Spacer(minLength: 80)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    private func getCurrentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
}

// Card Row for Home Screen
struct CardRowView: View {
    let card: CreditCard
    let matches: [BenefitMatch]

    var totalBenefits: Double {
        card.benefits.reduce(0) { $0 + $1.annualAmount }
    }

    var potentialSavings: Double {
        matches.reduce(0) { $0 + $1.potentialSavings }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Card thumbnail placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: cardGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 50)
                    .overlay(
                        Text(card.issuer.rawValue.uppercased())
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(card.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("•••• \(String(card.id.suffix(4)))")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatCurrency(potentialSavings))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)

                    Text("potential")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
        }
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var cardGradient: [Color] {
        switch card.issuer {
        case .amex:
            return [Color(red: 0.0, green: 0.4, blue: 0.7), Color(red: 0.0, green: 0.3, blue: 0.5)]
        case .chase:
            return [Color(red: 0.0, green: 0.2, blue: 0.5), Color(red: 0.0, green: 0.1, blue: 0.3)]
        case .capitalOne:
            return [Color(red: 0.8, green: 0.1, blue: 0.1), Color(red: 0.6, green: 0.0, blue: 0.0)]
        default:
            return [Color.gray, Color.gray.opacity(0.7)]
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// Dark theme subscription row
struct SubscriptionRowDark: View {
    let subscription: Subscription

    var body: some View {
        HStack(spacing: 16) {
            // Icon placeholder
            Circle()
                .fill(Color(.tertiarySystemBackground))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(subscription.merchant.prefix(1)))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.merchant)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Text(subscription.category.displayName)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(formatCurrency(subscription.amount))\(subscription.frequencyDisplay)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// View Model
class HomeViewModel: ObservableObject {
    @Published var subscriptions: [Subscription] = []
    @Published var benefitMatches: [BenefitMatch] = []
    @Published var stats: UserStats

    init() {
        self.stats = UserStats(
            totalSubscriptions: 0,
            monthlySubscriptionCost: 0,
            annualSubscriptionCost: 0,
            potentialSavings: 0,
            activeCards: 0
        )

        loadData()
    }

    private func loadData() {
        subscriptions = SubscriptionDetector.detectSubscriptions(from: MockData.transactions)
        benefitMatches = BenefitMatcher.matchBenefits(
            subscriptions: subscriptions,
            userCards: MockData.userCards
        )

        let monthlyTotal = subscriptions.reduce(0.0) { sum, sub in
            sum + sub.monthlyAmount
        }

        let totalSavings = BenefitMatcher.calculateTotalSavings(benefitMatches)

        stats = UserStats(
            totalSubscriptions: subscriptions.count,
            monthlySubscriptionCost: round(monthlyTotal * 100) / 100,
            annualSubscriptionCost: round(monthlyTotal * 12 * 100) / 100,
            potentialSavings: totalSavings,
            activeCards: MockData.userCards.count
        )
    }

    func getMatches(for card: CreditCard) -> [BenefitMatch] {
        benefitMatches.filter { $0.card.id == card.id }
    }
}

#Preview {
    HomeView()
}
