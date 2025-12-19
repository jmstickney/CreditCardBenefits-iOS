//
//  CardDetailView.swift
//  CreditCardBenefits
//
//  Card detail view with swipeable carousel
//

import SwiftUI

struct CardDetailView: View {
    let card: CreditCard
    @State private var currentCardIndex: Int = 0
    @Environment(\.presentationMode) var presentationMode

    private let allCards = MockData.userCards

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Navigation Bar
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
                    }

                    Spacer()

                    Text(currentCard.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    Button(action: {}) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
                    }
                }
                .padding()
                .background(Color(.systemBackground))

                ScrollView {
                    VStack(spacing: 24) {
                        // Card Carousel
                        TabView(selection: $currentCardIndex) {
                            ForEach(Array(allCards.enumerated()), id: \.element.id) { index, card in
                                CardVisualView(card: card)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .frame(height: 220)

                        // Page indicator dots
                        HStack(spacing: 8) {
                            ForEach(0..<allCards.count, id: \.self) { index in
                                Circle()
                                    .fill(index == currentCardIndex ? Color.primary : Color.secondary)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.top, -10)

                        // Benefits Summary Card
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Annual Benefits")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                    Text(formatCurrency(totalAnnualBenefits))
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(.primary)
                                }

                                Spacer()

                                Button(action: {}) {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
                                }
                            }

                            Divider()
                                .background(Color.secondary.opacity(0.3))

                            HStack {
                                Text("Potential Savings")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text(formatCurrency(potentialSavings))
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)

                        // Benefits List
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Available Benefits")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(.horizontal)

                            ForEach(currentCard.benefits) { benefit in
                                BenefitDetailRow(benefit: benefit, card: currentCard)
                            }
                        }

                        // Matched Subscriptions
                        if !matchedSubscriptions.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Matched Subscriptions")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal)

                                ForEach(matchedSubscriptions) { match in
                                    MatchedSubscriptionRow(match: match)
                                }
                            }
                            .padding(.top)
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if let index = allCards.firstIndex(where: { $0.id == card.id }) {
                currentCardIndex = index
            }
        }
    }

    private var currentCard: CreditCard {
        allCards[currentCardIndex]
    }

    private var totalAnnualBenefits: Double {
        currentCard.benefits.reduce(0) { $0 + $1.annualAmount }
    }

    private var potentialSavings: Double {
        matchedSubscriptions.reduce(0) { $0 + $1.potentialSavings }
    }

    private var matchedSubscriptions: [BenefitMatch] {
        let subscriptions = SubscriptionDetector.detectSubscriptions(from: MockData.transactions)
        let allMatches = BenefitMatcher.matchBenefits(
            subscriptions: subscriptions,
            userCards: MockData.userCards
        )
        return allMatches.filter { $0.card.id == currentCard.id }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// Card Visual Component
struct CardVisualView: View {
    let card: CreditCard

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(LinearGradient(
                colors: cardGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(height: 200)
            .overlay(
                VStack(alignment: .leading) {
                    HStack {
                        Text(card.issuer.rawValue.uppercased())
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)

                        Spacer()

                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()

                    Text(card.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Text("•••• •••• •••• \(String(card.id.suffix(4)))")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(24)
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
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
}

// Benefit Detail Row
struct BenefitDetailRow: View {
    let benefit: CreditCardBenefit
    let card: CreditCard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(benefit.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(benefit.description)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(benefit.amount))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text(benefit.frequencyDisplay)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }

            if let merchants = benefit.eligibleMerchants, !merchants.isEmpty {
                Text("Eligible: \(merchants.prefix(3).joined(separator: ", "))")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
            }
        }
        .padding()
        .background(Color(white: 0.12))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// Matched Subscription Row
struct MatchedSubscriptionRow: View {
    let match: BenefitMatch

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color(white: 0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(match.subscription.merchant.prefix(1)))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(match.subscription.merchant)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(match.benefit.name)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(match.potentialSavings))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.green)

                    Text("per year")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }

            HStack(spacing: 16) {
                Text("Current: \(formatCurrency(match.subscription.amount))\(match.subscription.frequencyDisplay)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                Text("•")
                    .foregroundColor(.gray)

                Text("Credit: \(formatCurrency(match.benefit.amount))\(match.benefit.frequencyDisplay)")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
            }
        }
        .padding()
        .background(Color(white: 0.12))
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

#Preview {
    CardDetailView(card: MockData.userCards[0])
}
