import SwiftUI

// MARK: - Home Header View
// Drop this into HomeView.swift, replacing everything above the "Accounts" section header.
// Requires BenTheme.swift to be present in the project.

struct HomeHeaderView: View {
    // Pass these in from your existing HomeView state/viewmodel
    let usedValue: Double        // e.g. 23.0
    let totalFees: Double        // e.g. 1340.0
    let cardCount: Int           // e.g. 3
    let unusedBenefitCount: Int  // e.g. 23

    private var progress: Double {
        guard totalFees > 0 else { return 0 }
        return min(usedValue / totalFees, 1.0)
    }

    private var remaining: Double {
        max(totalFees - usedValue, 0)
    }

    private var percentCaptured: Int {
        Int((progress * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Ben.Spacing.md) {
            dateLabel
            heroCard
            quickStats
        }
        .padding(.horizontal, Ben.Spacing.screenH)
        .padding(.top, Ben.Spacing.lg)
        .padding(.bottom, Ben.Spacing.sm)
    }

    // MARK: - Date label
    private var dateLabel: some View {
        Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            .font(Ben.Font.tag)
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundColor(Ben.Color.textMuted)
    }

    // MARK: - Forest green hero card
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Label
            Text("annual fee value")
                .font(Ben.Font.tag)
                .tracking(1.0)
                .textCase(.uppercase)
                .foregroundColor(Ben.Color.mint)
                .padding(.bottom, Ben.Spacing.xs)

            // Big number
            Text(usedValue, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(Ben.Font.heroNumber)
                .foregroundColor(Ben.Color.mintLight)
                .lineLimit(1)

            // Subtitle
            Text("of \(totalFees, format: .currency(code: "USD").precision(.fractionLength(0))) used so far")
                .font(Ben.Font.micro)
                .foregroundColor(Ben.Color.mint)
                .padding(.bottom, Ben.Spacing.lg)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 6)
                    Capsule()
                        .fill(Ben.Color.mint)
                        .frame(width: max(geo.size.width * progress, 6), height: 6)
                        .animation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.2), value: progress)
                }
            }
            .frame(height: 6)
            .padding(.bottom, Ben.Spacing.sm)

            // Bar meta row
            HStack {
                Text("\(percentCaptured)% captured")
                    .font(Ben.Font.micro)
                    .foregroundColor(Ben.Color.mint)
                Spacer()
                Text("\(remaining, format: .currency(code: "USD").precision(.fractionLength(0))) remaining")
                    .font(Ben.Font.micro)
                    .foregroundColor(Ben.Color.mint)
            }
        }
        .padding(Ben.Spacing.xl)
        .background(Ben.Color.forest)
        .cornerRadius(Ben.Radius.xl)
    }

    // MARK: - Quick stat chips below the hero card
    private var quickStats: some View {
        HStack(spacing: Ben.Spacing.sm) {
            QuickStatChip(
                label: "cards",
                value: "\(cardCount)",
                valueColor: Ben.Color.textPrimary
            )
            QuickStatChip(
                label: "unused benefits",
                value: "\(unusedBenefitCount)",
                valueColor: unusedBenefitCount > 0 ? Ben.Color.warn : Ben.Color.mintDark
            )
        }
    }
}

// MARK: - Quick Stat Chip
private struct QuickStatChip: View {
    let label: String
    let value: String
    let valueColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(Ben.Font.tag)
                .tracking(0.6)
                .foregroundColor(Ben.Color.textMuted)
            Text(value)
                .font(Ben.Font.sans(17, weight: .medium))
                .foregroundColor(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Ben.Spacing.md)
        .padding(.vertical, Ben.Spacing.md)
        .background(Ben.Color.sand)
        .cornerRadius(Ben.Radius.lg)
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            HomeHeaderView(
                usedValue: 23,
                totalFees: 1340,
                cardCount: 3,
                unusedBenefitCount: 23
            )

            // Simulate the Accounts section below
            VStack(alignment: .leading, spacing: Ben.Spacing.sm) {
                HStack {
                    Text("Accounts")
                        .font(Ben.Font.sans(15, weight: .medium))
                        .foregroundColor(Ben.Color.textPrimary)
                    Spacer()
                    Image(systemName: "plus")
                        .foregroundColor(Ben.Color.forest)
                        .font(.system(size: 16, weight: .medium))
                }
                .padding(.horizontal, Ben.Spacing.screenH)
                .padding(.top, Ben.Spacing.lg)
            }
        }
    }
    .benBackground()
    .previewDisplayName("Home Header — Ben")
}
