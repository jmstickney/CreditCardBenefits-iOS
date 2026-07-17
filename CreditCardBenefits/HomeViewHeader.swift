import SwiftUI

// MARK: - Home Header View
// Drop this into HomeView.swift, replacing everything above the "Accounts" section header.
// Requires BenTheme.swift to be present in the project.

struct HomeHeaderView: View {
    // Pass these in from your existing HomeView state/viewmodel
    let usedValue: Double        // e.g. 23.0
    let totalFees: Double        // e.g. 1340.0
    /// Optional: makes the "Benefits Captured" hero tappable (breakdown drill-in).
    var onHeroTap: (() -> Void)? = nil

    // NOTE: the quick-stat chips (cards / unused benefits) moved to the bottom
    // of HomeView so Savings Opportunities can sit directly under the hero.

    var body: some View {
        VStack(alignment: .leading, spacing: Ben.Spacing.md) {
            dateLabel
            BenefitProgressHeroCard(
                label: "Benefits Captured",
                usedValue: usedValue,
                totalFees: totalFees,
                onTap: onHeroTap
            )
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
}

// MARK: - Benefit Progress Hero Card

/// Reusable hero card showing "$ benefits captured vs $ in fees" with a gradient progress bar.
/// Used on the homepage (aggregate across all cards) and on card detail (single card).
struct BenefitProgressHeroCard: View {
    let label: String
    let usedValue: Double
    let totalFees: Double
    /// When set, the card becomes tappable (shows a chevron) and runs this on tap.
    var onTap: (() -> Void)? = nil

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
        if let onTap {
            Button(action: onTap) { cardBody }
                .buttonStyle(PlainButtonStyle())
        } else {
            cardBody
        }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Label (+ chevron affordance when tappable)
            HStack(spacing: Ben.Spacing.xs) {
                Text(label)
                    .font(Ben.Font.tag)
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundColor(Ben.Color.textMuted)

                if onTap != nil {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Ben.Color.textMuted)
                }
            }
            .padding(.bottom, Ben.Spacing.xs)

            // Big number
            Text(usedValue, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(Ben.Font.heroNumber)
                .foregroundColor(Ben.Color.textPrimary)
                .lineLimit(1)

            // Subtitle
            Text("of \(totalFees, format: .currency(code: "USD").precision(.fractionLength(0))) in annual fees")
                .font(Ben.Font.micro)
                .foregroundColor(Ben.Color.textMuted)
                .padding(.bottom, Ben.Spacing.lg)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Ben.Color.sandBorder.opacity(0.5))
                        .frame(height: 12)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * progress, 12), height: 12)
                        .animation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.2), value: progress)
                }
            }
            .frame(height: 12)
            .padding(.bottom, Ben.Spacing.sm)

            // Bar meta row
            HStack {
                Text("\(percentCaptured)% captured")
                    .font(Ben.Font.micro)
                    .foregroundColor(Ben.Color.textMuted)
                Spacer()
                Text("\(remaining, format: .currency(code: "USD").precision(.fractionLength(0))) remaining")
                    .font(Ben.Font.micro)
                    .foregroundColor(Ben.Color.textMuted)
            }
        }
        .padding(Ben.Spacing.xl)
        .background(Color.white)
        .cornerRadius(Ben.Radius.xl)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

// MARK: - Quick Stat Chip
struct QuickStatChip: View {
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
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            HomeHeaderView(
                usedValue: 23,
                totalFees: 1340
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
