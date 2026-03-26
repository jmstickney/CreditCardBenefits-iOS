import SwiftUI

// MARK: - Root Onboarding View
struct BenOnboardingView: View {
    @EnvironmentObject var dataManager: AppDataManager
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color.benCream.ignoresSafeArea()

            TabView(selection: $currentPage) {
                WelcomeScreen(onNext: { advance() })
                    .tag(0)
                ProblemScreen(onNext: { advance() })
                    .tag(1)
                HowItWorksScreen(onNext: { advance() })
                    .tag(2)
                DashboardPreviewScreen(onNext: { advance() })
                    .tag(3)
                PaywallScreen(onComplete: { dataManager.completeOnboarding() })
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.35), value: currentPage)

            VStack {
                Spacer()
                PageDotsView(total: 5, current: currentPage)
                    .padding(.bottom, 12)
            }
        }
    }

    private func advance() {
        withAnimation { currentPage = min(currentPage + 1, 4) }
    }
}

// MARK: - Page Dots
struct PageDotsView: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.benForest : Color.benMute.opacity(0.3))
                    .frame(width: i == current ? 18 : 6, height: 6)
                    .animation(.spring(response: 0.3), value: current)
            }
        }
    }
}

// MARK: - Screen 1: Welcome
struct WelcomeScreen: View {
    let onNext: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 6) {
                Text("ben.")
                    .font(.custom("Georgia", size: 42).bold())
                    .foregroundColor(.benForest)
                Text("Your credit cards have a secret.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.benMute)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)

            Spacer().frame(height: 32)

            // Hero stat card
            HeroStatCard(
                label: "Left unused last year",
                number: "$412",
                description: "Average value missed by premium cardholders"
            )
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.easeOut(duration: 0.5).delay(0.25), value: appeared)
            .padding(.horizontal, 28)

            Spacer().frame(height: 20)

            Text("Your cards are packed with credits and perks.\nBen makes sure you actually use them.")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.benBark)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 36)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.4), value: appeared)

            Spacer()

            VStack(spacing: 8) {
                BenButton(title: "Let's go →", action: onNext)
                BenGhostButton(title: "I already know the deal", action: { onNext(); onNext(); onNext(); onNext() })
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 56)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.5), value: appeared)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Screen 2: The Problem
struct ProblemScreen: View {
    let onNext: () -> Void
    @State private var appeared = false

    let chips: [(String, Bool)] = [
        ("$200 hotel credit", false),
        ("$200 airline credit", true),
        ("Uber Cash $15/mo", true),
        ("$100 Resy credit", false),
        ("Streaming $240/yr", true),
        ("CLEAR credit $199", true),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    TagLabel(text: "The problem")
                        .padding(.top, 24)

                    Text("High fees.\nHidden benefits.\nEasy to lose.")
                        .font(.custom("Georgia", size: 26).weight(.semibold))
                        .foregroundColor(.benDark)
                        .lineSpacing(2)
                        .padding(.top, 10)

                    Text("Premium cards offset their fees with credits — but most require enrollment, reset monthly, and are buried in apps nobody opens.")
                        .font(.system(size: 14))
                        .foregroundColor(.benBark)
                        .lineSpacing(4)
                        .padding(.top, 12)
                        .padding(.bottom, 20)

                    HStack(spacing: 10) {
                        MiniStatCard(label: "Annual fee", value: "$895", subtitle: "Amex Platinum", valueColor: .benWarn)
                        MiniStatCard(label: "Avg. used", value: "$483", subtitle: "Typical cardholder", valueColor: .benWarn)
                    }
                    .padding(.bottom, 16)

                    BenefitChipsView(chips: chips)
                        .padding(.bottom, 10)

                    Text("Green = benefits most people forget. Ben tracks them all.")
                        .font(.system(size: 12))
                        .foregroundColor(.benMute)
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 28)
            }

            BenButton(title: "Show me how →", action: onNext)
                .padding(.horizontal, 28)
                .padding(.bottom, 56)
        }
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { appeared = true } }
    }
}

// MARK: - Screen 3: How It Works
struct HowItWorksScreen: View {
    let onNext: () -> Void
    @State private var appeared = false

    let steps: [(String, String)] = [
        ("Connect your cards via Plaid", "Secure, read-only access. Ben sees transactions, not your passwords."),
        ("Ben maps your benefits", "Every credit, perk, and reset date — organized and human-readable."),
        ("Get nudged before you miss", "Monthly credit about to reset? Ben tells you in time to use it."),
        ("See your true annual fee ROI", "Live dashboard showing what you've used vs. what you paid."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                TagLabel(text: "How it works")
                    .padding(.top, 24)

                Text("Connect once.\nBen handles the rest.")
                    .font(.custom("Georgia", size: 26).weight(.semibold))
                    .foregroundColor(.benDark)
                    .lineSpacing(2)
                    .padding(.top, 10)

                Text("No manual tracking. No spreadsheets. No forgetting to enroll.")
                    .font(.system(size: 14))
                    .foregroundColor(.benBark)
                    .lineSpacing(4)
                    .padding(.top, 12)
                    .padding(.bottom, 28)

                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    StepRow(number: index + 1, title: step.0, subtitle: step.1)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.08), value: appeared)
                }
            }
            .padding(.horizontal, 28)

            Spacer()

            BenButton(title: "See the dashboard →", action: onNext)
                .padding(.horizontal, 28)
                .padding(.bottom, 56)
        }
        .onAppear { withAnimation { appeared = true } }
    }
}

// MARK: - Screen 4: Dashboard Preview
struct DashboardPreviewScreen: View {
    let onNext: () -> Void
    @State private var appeared = false
    @State private var barProgress: CGFloat = 0

    let remainingChips: [(String, Bool)] = [
        ("Uber Cash — $45 left", true),
        ("Saks credit — $50", true),
        ("Resy — used ✓", false),
        ("Airline credit — $157", true),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                TagLabel(text: "Your annual fee scorecard")
                    .padding(.top, 24)

                Text("Know exactly\nwhere you stand.")
                    .font(.custom("Georgia", size: 26).weight(.semibold))
                    .foregroundColor(.benDark)
                    .lineSpacing(2)
                    .padding(.top, 10)

                Text("Ben's ROI meter shows what you've captured vs. what's still on the table — updated after every transaction.")
                    .font(.system(size: 14))
                    .foregroundColor(.benBark)
                    .lineSpacing(4)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                HStack(spacing: 10) {
                    MiniStatCard(label: "Fee paid", value: "$895", subtitle: "Amex Platinum", valueColor: .benDark)
                    MiniStatCard(label: "Value used", value: "$643", subtitle: "so far this year", valueColor: .benGoodGreen)
                }
                .padding(.bottom, 16)

                // ROI bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Benefits used")
                            .font(.system(size: 11))
                            .foregroundColor(.benMute)
                        Spacer()
                        Text("72%")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.benDark)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.benMute.opacity(0.2))
                                .frame(height: 10)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.benForest)
                                .frame(width: geo.size.width * barProgress, height: 10)
                                .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3), value: barProgress)
                        }
                    }
                    .frame(height: 10)

                    Text("$252 still available this year")
                        .font(.system(size: 11))
                        .foregroundColor(.benWarn)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(18)
                .background(Color.benSand)
                .cornerRadius(16)
                .padding(.bottom, 16)

                BenefitChipsView(chips: remainingChips)
            }
            .padding(.horizontal, 28)

            Spacer()

            BenButton(title: "I want this →", action: onNext)
                .padding(.horizontal, 28)
                .padding(.bottom, 56)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
            barProgress = 0.72
        }
    }
}

// MARK: - Screen 5: Paywall
struct PaywallScreen: View {
    let onComplete: () -> Void
    @State private var appeared = false

    let features = [
        "Benefits tracker for all your cards",
        "Monthly reset alerts before credits expire",
        "Annual fee ROI scorecard",
        "\"Best card for this purchase\" suggestions",
        "New benefit & enrollment notifications",
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 6) {
                Text("ben.")
                    .font(.custom("Georgia", size: 38).bold())
                    .foregroundColor(.benForest)
                Text("Start for free. Pay only if you love it.")
                    .font(.system(size: 13))
                    .foregroundColor(.benMute)
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

            Spacer().frame(height: 20)

            // Price pill
            Text("7 days free  ·  then $4.99 / month")
                .font(.system(size: 12))
                .foregroundColor(.benBark)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Color.benSand)
                .clipShape(Capsule())
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)

            Spacer().frame(height: 20)

            // Feature list card
            VStack(alignment: .leading, spacing: 0) {
                Text("Everything in Ben:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.benDark)
                    .padding(.bottom, 14)

                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    HStack(alignment: .top, spacing: 10) {
                        Text("✓")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.benGoodGreen)
                        Text(feature)
                            .font(.system(size: 13))
                            .foregroundColor(.benBark)
                            .lineSpacing(3)
                    }
                    .padding(.bottom, index < features.count - 1 ? 10 : 0)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.35).delay(0.25 + Double(index) * 0.06), value: appeared)
                }
            }
            .padding(20)
            .background(Color.benSand)
            .cornerRadius(18)
            .padding(.horizontal, 28)

            Spacer().frame(height: 16)

            Text("If Ben doesn't find you at least $10/month in missed value, cancel anytime — no questions asked.")
                .font(.system(size: 11))
                .foregroundColor(.benMute)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 40)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.6), value: appeared)

            Spacer()

            VStack(spacing: 8) {
                BenButton(title: "Start free trial →", action: onComplete)
                BenGhostButton(title: "Restore purchase", action: {})
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 56)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.5), value: appeared)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Reusable Components

struct HeroStatCard: View {
    let label: String
    let number: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(1.0)
                .foregroundColor(.benMint)
            Text(number)
                .font(.custom("Georgia", size: 48).bold())
                .foregroundColor(.benLightMint)
                .lineLimit(1)
            Text(description)
                .font(.system(size: 12))
                .foregroundColor(.benMint)
                .lineSpacing(3)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.benForest)
        .cornerRadius(20)
    }
}

struct MiniStatCard: View {
    let label: String
    let value: String
    let subtitle: String
    let valueColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(0.8)
                .foregroundColor(.benMute)
            Text(value)
                .font(.custom("Georgia", size: 22).weight(.semibold))
                .foregroundColor(valueColor)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(.benMute)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.benSand)
        .cornerRadius(14)
    }
}

struct TagLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .medium))
            .tracking(1.2)
            .foregroundColor(.benMute)
    }
}

struct StepRow: View {
    let number: Int
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.benForest)
                    .frame(width: 30, height: 30)
                Text("\(number)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.benLightMint)
            }
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.benDark)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.benMute)
                    .lineSpacing(3)
            }
        }
        .padding(.bottom, 18)
    }
}

struct BenefitChipsView: View {
    let chips: [(String, Bool)]

    var body: some View {
        var rows: [[Int]] = [[]]
        // Simple wrap — SwiftUI doesn't have built-in wrapping for HStacks
        // Use LazyVGrid with flexible columns as a workaround
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6)], spacing: 6) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                Text(chip.0)
                    .font(.system(size: 11))
                    .foregroundColor(chip.1 ? .benGoodGreen : Color(red: 0.42, green: 0.39, blue: 0.34))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(chip.1 ? Color.benLightMint : Color.benCream)
                    .overlay(
                        Capsule()
                            .stroke(chip.1 ? Color.benMint : Color.benMute.opacity(0.3), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                    .strikethrough(!chip.1 && chip.0.contains("✓"))
            }
        }
    }
}

struct BenButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.benLightMint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.benForest)
                .cornerRadius(16)
        }
    }
}

struct BenGhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.benMute)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
    }
}

// MARK: - Preview
#Preview {
    BenOnboardingView()
}
