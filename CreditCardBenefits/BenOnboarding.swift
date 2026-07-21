import SwiftUI
import StoreKit

// MARK: - Root Onboarding View
// Value-first funnel: pitch → sign in → connect via Plaid → reveal the user's
// REAL numbers → paywall personalized with them. Navigation is button-driven
// (no free swiping) so the gated sign-in/connect steps can't be skipped past
// accidentally — the explicit "skip" buttons are the escape hatches.
struct BenOnboardingView: View {
    @EnvironmentObject var dataManager: AppDataManager
    @State private var currentPage = 0

    static let signInPage = 3
    static let paywallPage = 6

    var body: some View {
        ZStack {
            Ben.Color.cream.ignoresSafeArea()

            Group {
                switch currentPage {
                case 0:
                    WelcomeScreen(
                        onNext: { advance() },
                        onSkip: { goTo(Self.signInPage) }
                    )
                case 1:
                    ProblemScreen(onNext: { advance() })
                case 2:
                    HowItWorksScreen(onNext: { advance() })
                case 3:
                    SignInStep(
                        onNext: { advance() },
                        onSkip: { goTo(Self.paywallPage) }
                    )
                case 4:
                    ConnectStep(
                        onNext: { advance() },
                        onSkip: { goTo(Self.paywallPage) }
                    )
                case 5:
                    RevealStep(onNext: { advance() })
                default:
                    PaywallScreen(onComplete: { dataManager.completeOnboarding() })
                }
            }
            .id(currentPage)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            VStack {
                Spacer()
                PageDotsView(total: 7, current: currentPage)
                    .padding(.bottom, 12)
            }
        }
        // Onboarding is one-time: once the user reaches the paywall page
        // they've seen the pitch. Persist directly to UserDefaults (NOT the
        // published flag) so this session stays in onboarding and can
        // purchase, while the next launch goes straight to the app — where
        // the subscription gate enforces the paywall for non-subscribers.
        .onChange(of: currentPage) { _, page in
            if page == Self.paywallPage {
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            }
        }
        // Card-type selection must be able to present DURING onboarding —
        // benefits can't compute until accounts are mapped to cards.
        .sheet(isPresented: $dataManager.needsCardConfirmation) {
            CardSelectionView()
        }
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage = min(currentPage + 1, Self.paywallPage)
        }
    }

    private func goTo(_ page: Int) {
        withAnimation(.easeInOut(duration: 0.3)) { currentPage = page }
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
                    .fill(i == current ? Ben.Color.forest : Ben.Color.textMuted.opacity(0.3))
                    .frame(width: i == current ? 18 : 6, height: 6)
                    .animation(.spring(response: 0.3), value: current)
            }
        }
    }
}

// MARK: - Screen 1: Welcome
struct WelcomeScreen: View {
    let onNext: () -> Void
    let onSkip: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 6) {
                Text("ben.")
                    .font(Ben.Font.logo)
                    .foregroundColor(Ben.Color.forest)
                Text("Your credit cards have a secret.")
                    .font(Ben.Font.bodyLarge)
                    .foregroundColor(Ben.Color.textMuted)
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
                .font(Ben.Font.body)
                .foregroundColor(Ben.Color.textBody)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 36)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.4), value: appeared)

            Spacer()

            VStack(spacing: 8) {
                BenButton(title: "Let's go →", action: onNext)
                BenGhostButton(title: "I already know the deal", action: onSkip)
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
                        .font(Ben.Font.serif(26, weight: .semibold))
                        .foregroundColor(Ben.Color.textPrimary)
                        .lineSpacing(2)
                        .padding(.top, 10)

                    Text("Premium cards offset their fees with credits — but most require enrollment, reset monthly, and are buried in apps nobody opens.")
                        .font(Ben.Font.body)
                        .foregroundColor(Ben.Color.textBody)
                        .lineSpacing(4)
                        .padding(.top, 12)
                        .padding(.bottom, 20)

                    HStack(spacing: 10) {
                        MiniStatCard(label: "Annual fee", value: "$895", subtitle: "Amex Platinum", valueColor: Ben.Color.warn)
                        MiniStatCard(label: "Avg. used", value: "$483", subtitle: "Typical cardholder", valueColor: Ben.Color.warn)
                    }
                    .padding(.bottom, 16)

                    BenefitChipsView(chips: chips)
                        .padding(.bottom, 10)

                    Text("Green = benefits most people forget. Ben tracks them all.")
                        .font(Ben.Font.caption)
                        .foregroundColor(Ben.Color.textMuted)
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
                    .font(Ben.Font.serif(26, weight: .semibold))
                    .foregroundColor(Ben.Color.textPrimary)
                    .lineSpacing(2)
                    .padding(.top, 10)

                Text("No manual tracking. No spreadsheets. No forgetting to enroll.")
                    .font(Ben.Font.body)
                    .foregroundColor(Ben.Color.textBody)
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

// MARK: - Screen 4: Sign In
struct SignInStep: View {
    @EnvironmentObject var dataManager: AppDataManager
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TagLabel(text: "Step 1 of 2")
                .padding(.top, 24)

            Text("Create your\nBen account.")
                .font(Ben.Font.serif(26, weight: .semibold))
                .foregroundColor(Ben.Color.textPrimary)
                .lineSpacing(2)
                .padding(.top, 10)

            Text("Your cards and benefits stay synced, secure, and private to you.")
                .font(Ben.Font.body)
                .foregroundColor(Ben.Color.textBody)
                .lineSpacing(4)
                .padding(.top, 12)

            Spacer()

            VStack(spacing: 8) {
                SignInButtonsView(onSignedIn: onNext)
                BenGhostButton(title: "Skip for now", action: onSkip)
            }
            .padding(.bottom, 56)
        }
        .padding(.horizontal, 28)
        .onAppear {
            // Returning users (e.g. reinstall) are already signed in.
            if dataManager.authService.isAuthenticated { onNext() }
        }
    }
}

// MARK: - Screen 5: Connect Bank
struct ConnectStep: View {
    @EnvironmentObject var dataManager: AppDataManager
    let onNext: () -> Void
    let onSkip: () -> Void

    @State private var linkTokenItem: LinkTokenItem?
    @State private var isPreparing = false
    @State private var errorMessage: String?

    private struct LinkTokenItem: Identifiable {
        let id = UUID()
        let token: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TagLabel(text: "Step 2 of 2")
                .padding(.top, 24)

            Text("Connect your cards.\nSee your real numbers.")
                .font(Ben.Font.serif(26, weight: .semibold))
                .foregroundColor(Ben.Color.textPrimary)
                .lineSpacing(2)
                .padding(.top, 10)

            Text("Secure, read-only access through Plaid — the same connection trusted by Venmo and Robinhood. Ben sees transactions, never your bank login.")
                .font(Ben.Font.body)
                .foregroundColor(Ben.Color.textBody)
                .lineSpacing(4)
                .padding(.top, 12)

            Spacer()

            VStack(spacing: 8) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(Ben.Font.caption)
                        .foregroundColor(Ben.Color.warn)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                if isPreparing {
                    ProgressView()
                        .frame(height: 52)
                        .frame(maxWidth: .infinity)
                } else {
                    BenButton(title: "Connect securely with Plaid", action: startConnect)
                    BenGhostButton(title: "I'll connect later", action: onSkip)
                }
            }
            .padding(.bottom, 56)
        }
        .padding(.horizontal, 28)
        .onAppear {
            // Already connected (e.g. resumed onboarding) → straight to results.
            if dataManager.plaidService.isLinked { onNext() }
        }
        .fullScreenCover(item: $linkTokenItem) { item in
            PlaidLinkView(
                linkToken: item.token,
                onSuccess: { publicToken in
                    linkTokenItem = nil
                    Task { @MainActor in
                        await dataManager.plaidService.exchangePublicToken(publicToken)
                        await dataManager.processPlaidAccounts()
                        onNext()
                    }
                },
                onExit: {
                    linkTokenItem = nil
                }
            )
            .ignoresSafeArea()
        }
    }

    private func startConnect() {
        isPreparing = true
        errorMessage = nil
        Task { @MainActor in
            do {
                let token = try await dataManager.plaidService.createLinkToken()
                linkTokenItem = LinkTokenItem(token: token)
            } catch {
                errorMessage = error.localizedDescription
            }
            isPreparing = false
        }
    }
}

// MARK: - Screen 6: Reveal (the user's real numbers)
struct RevealStep: View {
    @EnvironmentObject var dataManager: AppDataManager
    let onNext: () -> Void

    /// Fallback so a mapping problem can't strand the user on the spinner.
    @State private var timedOut = false
    @State private var addBankToken: AddBankToken?
    @State private var isPreparingAddBank = false

    private struct AddBankToken: Identifiable {
        let id = UUID()
        let token: String
    }

    private var totalBenefits: Double {
        dataManager.userCards.reduce(0) { $0 + $1.totalBenefitsValue }
    }

    private var savingsTotal: Double {
        dataManager.missedOpportunities.reduce(0) { $0 + $1.benefit.annualAmount }
    }

    /// YTD statement credits Ben auto-detected on the user's own history —
    /// the single-card proof point (wrong-card savings needs 2+ cards).
    private var capturedYTD: Double {
        BenefitPeriodHelper.yearToDateUtilized(dataManager.utilizationService.utilizations)
    }

    private var unclaimed: Double {
        max(0, totalBenefits - capturedYTD)
    }

    private var isAnalyzing: Bool {
        dataManager.needsCardConfirmation ||
        (dataManager.userCards.isEmpty && !timedOut)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isAnalyzing {
                Spacer()
                VStack(spacing: 14) {
                    ProgressView()
                        .scaleEffect(1.4)
                    Text("Analyzing your accounts…")
                        .font(Ben.Font.body)
                        .foregroundColor(Ben.Color.textBody)
                    Text("This usually takes under a minute.")
                        .font(Ben.Font.caption)
                        .foregroundColor(Ben.Color.textMuted)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        TagLabel(text: "Your results")
                            .padding(.top, 24)

                        Text("Here's what\nBen found.")
                            .font(Ben.Font.serif(26, weight: .semibold))
                            .foregroundColor(Ben.Color.textPrimary)
                            .lineSpacing(2)
                            .padding(.top, 10)
                            .padding(.bottom, 20)

                        if totalBenefits > 0 {
                            // Anchor: total benefits on THEIR cards.
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your cards carry")
                                    .font(Ben.Font.tag)
                                    .tracking(1.0)
                                    .textCase(.uppercase)
                                    .foregroundColor(Ben.Color.textMuted)
                                Text("\(totalBenefits.asCurrency())/yr")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundColor(Ben.Color.forest)
                                Text("in benefits across \(dataManager.userCards.count) card\(dataManager.userCards.count == 1 ? "" : "s")")
                                    .font(Ben.Font.caption)
                                    .foregroundColor(Ben.Color.textMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Ben.Spacing.xl)
                            .background(Color.white)
                            .cornerRadius(Ben.Radius.xl)
                            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                            .padding(.bottom, 12)
                        }

                        if totalBenefits > 0, unclaimed > 0 {
                            // Single-card hook: what their history shows they
                            // have and haven't captured this year. Numbers grow
                            // live as the transaction history imports.
                            VStack(alignment: .leading, spacing: 4) {
                                Text("This year so far")
                                    .font(Ben.Font.tag)
                                    .tracking(1.0)
                                    .textCase(.uppercase)
                                    .foregroundColor(Ben.Color.textMuted)
                                Text("\(unclaimed.asCurrency()) unclaimed")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(Ben.Color.warn)
                                Text(capturedYTD > 0
                                    ? "You've already captured \(capturedYTD.asCurrency()) — Ben tracks the rest so you never miss a credit."
                                    : "Ben tracks every credit so nothing slips by.")
                                    .font(Ben.Font.caption)
                                    .foregroundColor(Ben.Color.textMuted)
                                    .fixedSize(horizontal: false, vertical: true)

                                if dataManager.plaidService.isImportingHistory {
                                    Text("Still importing your history — these update live.")
                                        .font(Ben.Font.micro)
                                        .foregroundColor(Ben.Color.textMuted.opacity(0.8))
                                        .padding(.top, 2)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Ben.Spacing.xl)
                            .background(Color.white)
                            .cornerRadius(Ben.Radius.xl)
                            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                            .padding(.bottom, 12)
                        }

                        if !dataManager.missedOpportunities.isEmpty {
                            // Wrong-card savings already detected.
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Already found — wrong card used")
                                    .font(Ben.Font.tag)
                                    .tracking(1.0)
                                    .textCase(.uppercase)
                                    .foregroundColor(Ben.Color.textMuted)
                                Text("Up to \(savingsTotal.asCurrency())/yr in missed savings")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(Ben.Color.mintDark)

                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(dataManager.missedOpportunities.prefix(3)) { opp in
                                        Text("\(opp.merchantDisplayName) → \(opp.coveringCard.name)")
                                            .font(Ben.Font.bodySmall)
                                            .foregroundColor(Ben.Color.textBody)
                                            .lineLimit(1)
                                    }
                                    if dataManager.missedOpportunities.count > 3 {
                                        Text("+ \(dataManager.missedOpportunities.count - 3) more")
                                            .font(Ben.Font.caption)
                                            .foregroundColor(Ben.Color.textMuted)
                                    }
                                }
                                .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Ben.Spacing.xl)
                            .background(Color.white)
                            .cornerRadius(Ben.Radius.xl)
                            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                            .padding(.bottom, 12)
                        }

                        if totalBenefits > 0 {
                            Text("Ben watches every transaction so these never slip by again.")
                                .font(Ben.Font.caption)
                                .foregroundColor(Ben.Color.textMuted)
                        } else {
                            // Timed-out / no mapped cards yet: honest fallback.
                            Text("Ben is still importing your transactions — your dashboard will fill in shortly after you continue.")
                                .font(Ben.Font.body)
                                .foregroundColor(Ben.Color.textBody)
                                .lineSpacing(4)
                        }
                    }
                    .padding(.horizontal, 28)
                }

                VStack(spacing: 6) {
                    BenButton(title: "Continue →", action: onNext)

                    // Wrong-card detection needs 2+ cards — each Plaid session
                    // links one institution, so offer (optionally) adding more.
                    if isPreparingAddBank {
                        ProgressView()
                            .frame(height: 40)
                    } else {
                        BenGhostButton(title: "Add another bank", action: startAddBank)
                    }
                    Text("More cards unlock \"wrong card used\" alerts.")
                        .font(Ben.Font.micro)
                        .foregroundColor(Ben.Color.textMuted)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 56)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(25))
            timedOut = true
        }
        .fullScreenCover(item: $addBankToken) { item in
            PlaidLinkView(
                linkToken: item.token,
                onSuccess: { publicToken in
                    addBankToken = nil
                    Task { @MainActor in
                        await dataManager.plaidService.exchangePublicToken(publicToken)
                        await dataManager.processPlaidAccounts()
                    }
                },
                onExit: {
                    addBankToken = nil
                }
            )
            .ignoresSafeArea()
        }
    }

    private func startAddBank() {
        isPreparingAddBank = true
        Task { @MainActor in
            if let token = try? await dataManager.plaidService.createLinkToken() {
                addBankToken = AddBankToken(token: token)
            }
            isPreparingAddBank = false
        }
    }
}

// MARK: - Screen 5: Paywall
struct PaywallScreen: View {
    let onComplete: () -> Void
    @EnvironmentObject var dataManager: AppDataManager
    @State private var appeared = false
    @State private var errorMessage: String?

    /// Update once the privacy policy is hosted (also goes in App Store Connect).
    private let privacyPolicyURL = URL(string: "https://getben.app/privacy-policy")!
    /// Apple's standard EULA — allowed as Terms of Use for App Review 3.1.2.
    private let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    private var subscriptions: SubscriptionManager { dataManager.subscriptionService }

    /// Live App Store price when loaded; falls back to the configured price.
    private var priceText: String {
        subscriptions.product?.displayPrice ?? "$4.99"
    }

    // Personalization from the value-first flow (zero when the user skipped
    // connecting — generic copy is used instead).
    private var personalBenefitsTotal: Double {
        dataManager.userCards.reduce(0) { $0 + $1.totalBenefitsValue }
    }

    private var personalSavingsTotal: Double {
        dataManager.missedOpportunities.reduce(0) { $0 + $1.benefit.annualAmount }
    }

    let features = [
        "Benefits tracker for all your cards",
        "\"Best card for this purchase\" suggestions",
        "Monthly reset alerts before credits expire",
        "Annual fee ROI scorecard",
        "New benefit & enrollment notifications",
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 6) {
                Text("ben.")
                    .font(Ben.Font.logo)
                    .foregroundColor(Ben.Color.forest)
                // Personalized when the user connected during onboarding.
                Text(personalBenefitsTotal > 0
                    ? "Keep tracking your \(personalBenefitsTotal.asCurrency())/yr in benefits."
                    : "Start for free. Pay only if you love it.")
                    .font(Ben.Font.body)
                    .foregroundColor(Ben.Color.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

            Spacer().frame(height: 20)

            // Price pill (live App Store price)
            Text("7 days free  ·  then \(priceText) / month")
                .font(Ben.Font.caption)
                .foregroundColor(Ben.Color.textBody)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Ben.Color.sand)
                .clipShape(Capsule())
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)

            if personalSavingsTotal > 0 {
                Text("Ben already found \(personalSavingsTotal.asCurrency())/yr in missed savings for you.")
                    .font(Ben.Font.caption)
                    .foregroundColor(Ben.Color.mintDark)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 8)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.25), value: appeared)
            }

            Spacer().frame(height: 20)

            // Feature list card
            VStack(alignment: .leading, spacing: 0) {
                Text("Everything in Ben:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Ben.Color.textPrimary)
                    .padding(.bottom, 14)

                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    HStack(alignment: .top, spacing: 10) {
                        Text("✓")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Ben.Color.mintDark)
                        Text(feature)
                            .font(.system(size: 13))
                            .foregroundColor(Ben.Color.textBody)
                            .lineSpacing(3)
                    }
                    .padding(.bottom, index < features.count - 1 ? 10 : 0)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.35).delay(0.25 + Double(index) * 0.06), value: appeared)
                }
            }
            .padding(20)
            .background(Ben.Color.sand)
            .cornerRadius(18)
            .padding(.horizontal, 28)

            Spacer().frame(height: 16)

            Text("If Ben doesn't find you at least $10/month in missed value, cancel anytime — no questions asked.")
                .font(.system(size: 11))
                .foregroundColor(Ben.Color.textMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 40)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.6), value: appeared)

            Spacer()

            VStack(spacing: 8) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(Ben.Font.caption)
                        .foregroundColor(Ben.Color.warn)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                if subscriptions.isPurchasing {
                    ProgressView()
                        .frame(height: 52)
                } else {
                    BenButton(title: "Start free trial →", action: { startTrial() })
                    BenGhostButton(title: "Restore purchase", action: { restore() })
                }

                // Required for auto-renewable subscriptions (App Review 3.1.2).
                HStack(spacing: 16) {
                    Link("Terms of Use", destination: termsOfUseURL)
                    Link("Privacy Policy", destination: privacyPolicyURL)
                }
                .font(.system(size: 11))
                .foregroundColor(Ben.Color.textMuted)
                .padding(.top, 4)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 56)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.5), value: appeared)
        }
        .onAppear { appeared = true }
    }

    // MARK: - Purchase Actions

    private func startTrial() {
        errorMessage = nil
        Task {
            do {
                if try await subscriptions.purchase() {
                    onComplete()
                }
                // Cancelled/pending: stay on the paywall silently.
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func restore() {
        errorMessage = nil
        Task {
            do {
                if try await subscriptions.restore() {
                    onComplete()
                } else {
                    errorMessage = "No previous purchase found for this Apple ID."
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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
                .foregroundColor(Ben.Color.textMuted)
            Text(number)
                .font(.custom("Georgia", size: 48).bold())
                .foregroundColor(Ben.Color.textPrimary)
                .lineLimit(1)
            Text(description)
                .font(.system(size: 12))
                .foregroundColor(Ben.Color.textMuted)
                .lineSpacing(3)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
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
                .foregroundColor(Ben.Color.textMuted)
            Text(value)
                .font(.custom("Georgia", size: 22).weight(.semibold))
                .foregroundColor(valueColor)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(Ben.Color.textMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ben.Color.sand)
        .cornerRadius(14)
    }
}

struct TagLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .medium))
            .tracking(1.2)
            .foregroundColor(Ben.Color.textMuted)
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
                    .fill(Ben.Color.forest)
                    .frame(width: 30, height: 30)
                Text("\(number)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Ben.Color.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Ben.Color.textMuted)
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
                    .foregroundColor(chip.1 ? Ben.Color.mintDark : Ben.Color.textBody)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(chip.1 ? Ben.Color.mintLight : Ben.Color.cream)
                    .overlay(
                        Capsule()
                            .stroke(chip.1 ? Ben.Color.mint : Ben.Color.textMuted.opacity(0.3), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                    .strikethrough(!chip.1 && chip.0.contains("✓"))
            }
        }
    }
}



// Use BenPrimaryButton and BenGhostButton from BenTheme.swift
// Aliased here for convenience in onboarding screens
typealias BenButton = BenPrimaryButton

// MARK: - Preview
#Preview {
    BenOnboardingView()
        .environmentObject(AppDataManager())
}
