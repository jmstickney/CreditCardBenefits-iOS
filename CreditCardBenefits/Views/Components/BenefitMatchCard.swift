//
//  BenefitMatchCard.swift
//  CreditCardBenefits
//
//  Created for Credit Card Benefits Tracker POC
//

import SwiftUI

struct BenefitMatchCard: View {
    let match: BenefitMatch

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(match.subscription.merchant)
                    .font(.system(size: 18, weight: .bold))

                Spacer()

                Text("Save \(formatCurrency(match.potentialSavings))/year")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.green)
            }

            // Benefit info
            Text("\(match.benefit.name) - \(match.card.name)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)

            Text(match.benefit.description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            // Footer
            HStack {
                Text("Current: \(formatCurrency(match.subscription.amount))\(match.subscription.frequencyDisplay)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Spacer()

                Text("Credit: \(formatCurrency(match.benefit.amount))\(match.benefit.frequencyDisplay)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green, lineWidth: 3)
                .padding(.leading, -3)
        )
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}
