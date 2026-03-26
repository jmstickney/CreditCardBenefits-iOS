import SwiftUI

// MARK: - Ben Design System
// Single source of truth for all colors, typography, spacing, and corner radii.
// Import this file and reference Ben.Color.*, Ben.Font.*, Ben.Radius.* throughout the app.
// Matches the onboarding flow exactly.

enum Ben {

    // MARK: - Colors
    enum Color {
        // Primary palette
        /// Deep forest green — primary actions, key UI elements, hero backgrounds
        static let forest      = SwiftUI.Color(red: 0.102, green: 0.239, blue: 0.169) // #1A3D2B
        /// Light mint — text on forest, success states, positive accents
        static let mint        = SwiftUI.Color(red: 0.490, green: 0.749, blue: 0.604) // #7DBF9A
        /// Pale mint — mint chip backgrounds, success fill areas
        static let mintLight   = SwiftUI.Color(red: 0.910, green: 0.961, blue: 0.933) // #E8F5EE
        /// Deep mint — success text on light backgrounds
        static let mintDark    = SwiftUI.Color(red: 0.102, green: 0.420, blue: 0.251) // #1A6B40

        // Backgrounds
        /// Warm cream — primary app background (replaces plain white)
        static let cream       = SwiftUI.Color(red: 0.996, green: 0.988, blue: 0.969) // #FEFCF7
        /// Warm sand — secondary surfaces, cards, input backgrounds
        static let sand        = SwiftUI.Color(red: 0.933, green: 0.914, blue: 0.875) // #EEE9DF
        /// Muted sand border — dividers, card strokes
        static let sandBorder  = SwiftUI.Color(red: 0.839, green: 0.816, blue: 0.769) // #D6D0C4

        // Text
        /// Near-black — primary text, headings
        static let textPrimary = SwiftUI.Color(red: 0.110, green: 0.102, blue: 0.082) // #1C1A15
        /// Warm brown — body text, secondary content
        static let textBody    = SwiftUI.Color(red: 0.420, green: 0.388, blue: 0.337) // #6B6356
        /// Muted tan — captions, labels, placeholders
        static let textMuted   = SwiftUI.Color(red: 0.541, green: 0.498, blue: 0.431) // #8A7F6E

        // Semantic
        /// Warm amber — warnings, "worth-it" anxiety states
        static let warn        = SwiftUI.Color(red: 0.722, green: 0.361, blue: 0.039) // #B85C0A
        /// Soft amber background — warning fill areas
        static let warnLight   = SwiftUI.Color(red: 0.980, green: 0.933, blue: 0.855) // #FAEEDA
        /// Destructive red — errors, negative states
        static let danger      = SwiftUI.Color.red
    }

    // MARK: - Typography
    enum Font {
        /// Display serif — "ben." logo, screen titles, hero numbers
        static func serif(_ size: CGFloat, weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            .custom("Georgia", size: size).weight(weight)
        }

        /// App body — labels, body copy, buttons
        static func sans(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight)
        }

        // Semantic scales
        static let logo         = serif(38)
        static let screenTitle  = serif(26, weight: .semibold)
        static let heroNumber   = serif(42, weight: .semibold)
        static let cardNumber   = serif(22, weight: .semibold)

        static let bodyLarge    = sans(15)
        static let body         = sans(14)
        static let bodySmall    = sans(13)
        static let caption      = sans(12)
        static let micro        = sans(11)
        static let tag          = sans(10, weight: .medium)

        static let buttonPrimary   = sans(15, weight: .medium)
        static let buttonSecondary = sans(13)
    }

    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 12
        static let lg: CGFloat  = 16
        static let xl: CGFloat  = 20
        static let xxl: CGFloat = 28
        static let screenH: CGFloat = 28  // horizontal screen padding
        static let screenV: CGFloat = 24  // vertical screen padding
    }

    // MARK: - Corner Radii
    enum Radius {
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 12
        static let lg: CGFloat  = 16
        static let xl: CGFloat  = 20
        static let chip: CGFloat = 99  // fully rounded pills/chips
    }
}

// MARK: - View Modifiers

/// Screen-level background — warm cream
struct BenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Ben.Color.cream.ignoresSafeArea())
    }
}

/// Standard card surface — sand bg, subtle border
struct BenCard: ViewModifier {
    var padding: CGFloat = Ben.Spacing.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Ben.Color.sand)
            .cornerRadius(Ben.Radius.lg)
    }
}

/// Raised card — cream bg, sand border (for cards that float above the sand bg)
struct BenRaisedCard: ViewModifier {
    var padding: CGFloat = Ben.Spacing.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Ben.Color.cream)
            .cornerRadius(Ben.Radius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: Ben.Radius.lg)
                    .stroke(Ben.Color.sandBorder, lineWidth: 0.5)
            )
    }
}

/// Hero dark card — forest bg, for key metrics (used in onboarding welcome screen)
struct BenHeroCard: ViewModifier {
    var padding: CGFloat = Ben.Spacing.xl

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Ben.Color.forest)
            .cornerRadius(Ben.Radius.xl)
    }
}

/// Tag / section label — uppercase, muted, small tracking
struct BenTagStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Ben.Font.tag)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundColor(Ben.Color.textMuted)
    }
}

/// Benefit chip — rounded pill
struct BenChip: ViewModifier {
    var isHighlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .font(Ben.Font.micro)
            .foregroundColor(isHighlighted ? Ben.Color.mintDark : Ben.Color.textBody)
            .padding(.horizontal, Ben.Spacing.md)
            .padding(.vertical, Ben.Spacing.xs + 2)
            .background(isHighlighted ? Ben.Color.mintLight : Ben.Color.cream)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        isHighlighted ? Ben.Color.mint : Ben.Color.sandBorder,
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Convenience View Extensions

extension View {
    func benBackground()              -> some View { modifier(BenBackground()) }
    func benCard(padding: CGFloat = Ben.Spacing.lg) -> some View { modifier(BenCard(padding: padding)) }
    func benRaisedCard(padding: CGFloat = Ben.Spacing.lg) -> some View { modifier(BenRaisedCard(padding: padding)) }
    func benHeroCard(padding: CGFloat = Ben.Spacing.xl) -> some View { modifier(BenHeroCard(padding: padding)) }
    func benTag()                     -> some View { modifier(BenTagStyle()) }
    func benChip(highlighted: Bool = false) -> some View { modifier(BenChip(isHighlighted: highlighted)) }
}

// MARK: - Reusable UI Components

/// Primary CTA button — forest bg, mint text
struct BenPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Ben.Font.buttonPrimary)
                .foregroundColor(Ben.Color.mintLight)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Ben.Spacing.lg)
                .background(Ben.Color.forest)
                .cornerRadius(Ben.Radius.lg)
        }
    }
}

/// Ghost button — no bg, muted text
struct BenGhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Ben.Font.buttonSecondary)
                .foregroundColor(Ben.Color.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Ben.Spacing.md)
        }
    }
}

/// Outlined button — sand border, primary text
struct BenOutlineButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Ben.Font.buttonPrimary)
                .foregroundColor(Ben.Color.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Ben.Spacing.lg)
                .background(Ben.Color.cream)
                .cornerRadius(Ben.Radius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: Ben.Radius.lg)
                        .stroke(Ben.Color.sandBorder, lineWidth: 1)
                )
        }
    }
}

/// Section header — tag label + optional title
struct BenSectionHeader: View {
    let tag: String
    var title: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Ben.Spacing.sm) {
            Text(tag)
                .benTag()
            if let title {
                Text(title)
                    .font(Ben.Font.screenTitle)
                    .foregroundColor(Ben.Color.textPrimary)
                    .lineSpacing(2)
            }
        }
    }
}

/// Stat card — used in dashboard and detail views
struct BenStatCard: View {
    let label: String
    let value: String
    var subtitle: String? = nil
    var valueColor: SwiftUI.Color = Ben.Color.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: Ben.Spacing.xs) {
            Text(label.uppercased())
                .font(Ben.Font.tag)
                .tracking(0.8)
                .foregroundColor(Ben.Color.textMuted)
            Text(value)
                .font(Ben.Font.cardNumber)
                .foregroundColor(valueColor)
            if let subtitle {
                Text(subtitle)
                    .font(Ben.Font.micro)
                    .foregroundColor(Ben.Color.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .benCard()
    }
}

/// ROI progress bar — used in dashboard
struct BenROIBar: View {
    let used: Double       // e.g. 643
    let total: Double      // e.g. 895
    var animated: Bool = true

    @State private var progress: CGFloat = 0

    var pct: Double { min(used / total, 1.0) }
    var remaining: Double { max(total - used, 0) }

    var body: some View {
        VStack(spacing: Ben.Spacing.sm) {
            HStack {
                Text("Benefits used")
                    .font(Ben.Font.micro)
                    .foregroundColor(Ben.Color.textMuted)
                Spacer()
                Text("\(Int(pct * 100))%")
                    .font(Ben.Font.micro)
                    .fontWeight(.medium)
                    .foregroundColor(Ben.Color.textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Ben.Color.sandBorder.opacity(0.5))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Ben.Color.forest)
                        .frame(width: geo.size.width * progress, height: 10)
                        .animation(animated ? .spring(response: 0.8, dampingFraction: 0.7).delay(0.3) : .none, value: progress)
                }
            }
            .frame(height: 10)
            Text("$\(Int(remaining)) still available this year")
                .font(Ben.Font.micro)
                .foregroundColor(Ben.Color.warn)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .benCard()
        .onAppear { progress = CGFloat(pct) }
    }
}

/// Step row — used in onboarding how-it-works and any instructional lists
struct BenStepRow: View {
    let number: Int
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: Ben.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Ben.Color.forest)
                    .frame(width: 30, height: 30)
                Text("\(number)")
                    .font(Ben.Font.sans(13, weight: .medium))
                    .foregroundColor(Ben.Color.mintLight)
            }
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Ben.Font.body)
                    .fontWeight(.medium)
                    .foregroundColor(Ben.Color.textPrimary)
                Text(subtitle)
                    .font(Ben.Font.caption)
                    .foregroundColor(Ben.Color.textMuted)
                    .lineSpacing(3)
            }
        }
    }
}

// MARK: - Preview Helpers
#if DEBUG
struct BenTheme_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("ben.")
                    .font(Ben.Font.logo)
                    .foregroundColor(Ben.Color.forest)

                BenSectionHeader(tag: "Dashboard", title: "Where you stand")

                HStack(spacing: 12) {
                    BenStatCard(label: "Fee paid", value: "$895", subtitle: "Amex Platinum")
                    BenStatCard(label: "Used", value: "$643", subtitle: "this year", valueColor: Ben.Color.mintDark)
                }

                BenROIBar(used: 643, total: 895)

                HStack {
                    Text("Uber Cash — $45 left").benChip(highlighted: true)
                    Text("Resy — used ✓").benChip()
                }

                BenStepRow(number: 1, title: "Connect your cards", subtitle: "Secure, read-only access via Plaid.")

                BenPrimaryButton(title: "Start free trial →") {}
                BenOutlineButton(title: "Start with Ben — $4.99/mo") {}
                BenGhostButton(title: "Restore purchase") {}
            }
            .padding(Ben.Spacing.screenH)
        }
        .benBackground()
        .previewDisplayName("Ben Design System")
    }
}
#endif
