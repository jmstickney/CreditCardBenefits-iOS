//
//  AppDataManager.swift
//  CreditCardBenefits
//
//  Centralized data management for the app
//

import Foundation
import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFunctions

@MainActor
class AppDataManager: ObservableObject {
    // Services
    @Published var plaidService = PlaidService()
    @Published var authService = AuthService()
    @Published var cardMappingService = CardMappingService()
    @Published var utilizationService = BenefitUtilizationService()
    @Published var subscriptionService = SubscriptionManager()

    // Core Data
    @Published var userCards: [CreditCard] = []
    @Published var cardMatches: [CardMatch] = []
    @Published var subscriptions: [Subscription] = []
    @Published var benefitMatches: [BenefitMatch] = []
    @Published var recommendations: [Recommendation] = []
    // Wrong-card suggestions: spend that another connected card's benefit covers.
    @Published var missedOpportunities: [MissedBenefitOpportunity] = []
    @Published var stats: UserStats

    // Card Selection State
    @Published var needsCardConfirmation = false
    
    // Onboarding State
    @Published var hasCompletedOnboarding = false

    // Error handling
    @Published var error: AppError?
    @Published var showError = false

    // State restoration
    @Published var isRestoring = false
    @Published var isRestoringState = false

    /// Bumped whenever local data is wiped (sign-out / disconnect / clear).
    /// Views that can hold a stale snapshot in an inactive tab key their
    /// identity on this so they rebuild fresh — without also rebuilding on
    /// sign-in / connect (which would interrupt in-flight flows).
    @Published var clearGeneration = 0

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Initialize with empty stats
        self.stats = UserStats(
            totalSubscriptions: 0,
            monthlySubscriptionCost: 0,
            annualSubscriptionCost: 0,
            potentialSavings: 0,
            activeCards: 0,
            totalAnnualFees: 0,
            totalBenefitsValue: 0,
            totalBenefitsUtilized: 0,
            utilizationPercentage: 0,
            benefitsExpiringSoon: 0,
            benefitsRequiringAction: 0
        )
        
        // Load onboarding state from UserDefaults
        // Check if we should always show onboarding (for testing)
        if UserDefaults.standard.bool(forKey: "alwaysShowOnboarding") {
            self.hasCompletedOnboarding = false
        } else {
            self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        }

        // Don't load mock data by default - user can load via Settings > Developer Tools
        // This ensures the app starts fresh and shows real data when connected

        // Re-publish nested service changes so views observing AppDataManager
        // update immediately when auth / Plaid / utilization state changes.
        // Without this, a nested change (e.g. sign-out flipping isAuthenticated)
        // doesn't re-render observers until some unrelated update happens.
        for publisher in [
            authService.objectWillChange,
            plaidService.objectWillChange,
            utilizationService.objectWillChange,
            cardMappingService.objectWillChange,
            subscriptionService.objectWillChange,
        ] {
            publisher
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
    }

    // MARK: - State Restoration

    /// Restores app state on launch — loads cache instantly, then refreshes from network
    func restoreState() async {
        isRestoringState = true

        // Data is per-user: only load anything when a user is signed in.
        // Auth.currentUser is restored synchronously at launch (before the
        // auth-state listener fires), so instant launch from cache still works
        // for returning signed-in users while signed-out users see nothing.
        guard Auth.auth().currentUser != nil else {
            benLog("ℹ️ No signed-in user; skipping cached + network data")
            isRestoringState = false
            return
        }

        // Phase 1: Load cached data immediately (synchronous, sub-100ms)
        loadFromCache()
        let hasCachedData = !plaidService.transactions.isEmpty

        // Stream transactions live from Firestore; they update as the server
        // syncs them in (webhook-driven), so the UI fills in progressively.
        plaidService.startTransactionsListener()

        // Phase 2: Silent network refresh
        // Only show loading indicator if there's no cached data to display
        if !hasCachedData {
            isRestoring = true
        }

        benLog("🔄 Refreshing from network...")

        let hasConnection = await plaidService.checkExistingConnection()

        if hasConnection {
            // processPlaidAccounts() calls loadData() which processes utilizations,
            // matches benefits, calculates stats, and saves to cache — all in one pass.
            // On a brand-new connection this first pass runs before the sync
            // below has landed anything, so it sees little/no data.
            await processPlaidAccounts()
            // Ask the server to pull the latest from Plaid; the listener surfaces
            // new transactions as they land — but the listener's own updates are
            // ignored while isRestoringState is true (see HomeView), so without
            // this explicit follow-up pass, a new card's matches would only be
            // picked up if a listener update happens to land after this method
            // returns. Reprocessing here guarantees one accurate pass against
            // the (by now synced) data, so match/opportunity notifications for
            // a newly connected card aren't missed or based on partial data.
            await plaidService.refreshTransactions()
            loadData(from: plaidService.transactions)

            // Check whether any bank connection has expired (needs reconnect).
            await plaidService.fetchItemsStatus()

            benLog("✅ State restored: \(userCards.count) cards")
        } else {
            benLog("ℹ️ No existing connection to restore")
        }

        isRestoring = false
        isRestoringState = false
    }

    // MARK: - Local Cache

    /// Loads all cached data into @Published properties for instant UI population
    func loadFromCache() {
        let cache = CacheManager.shared

        if let transactions = cache.load([Transaction].self, for: .transactions) {
            plaidService.transactions = transactions
        }
        if let accounts = cache.load([PlaidAccount].self, for: .plaidAccounts) {
            plaidService.accounts = accounts
        }
        if let isLinked = cache.load(Bool.self, for: .isLinked) {
            plaidService.isLinked = isLinked
        }
        if let dataSource = cache.load(DataSource.self, for: .dataSource) {
            plaidService.dataSource = dataSource
        }
        if let cards = cache.load([CreditCard].self, for: .userCards) {
            // Rehydrate from CreditCardsData so any benefits added in code updates
            // appear immediately, instead of being stuck at whatever was cached.
            userCards = cards.compactMap { CreditCardsData.getCard(by: $0.id) ?? $0 }
        }
        if let subs = cache.load([Subscription].self, for: .subscriptions) {
            subscriptions = subs
        }
        if let matches = cache.load([BenefitMatch].self, for: .benefitMatches) {
            benefitMatches = matches
        }
        if let cachedStats = cache.load(UserStats.self, for: .userStats) {
            stats = cachedStats
        }
        if let mappings = cache.load([String: CardMapping].self, for: .cardMappings) {
            cardMappingService.mappings = mappings
        }
        if let utils = cache.load([BenefitUtilization].self, for: .benefitUtilizations) {
            utilizationService.utilizations = utils
        }

        if !plaidService.transactions.isEmpty {
            benLog("✅ Loaded cached data: \(plaidService.transactions.count) transactions, \(userCards.count) cards")
        }
    }

    /// Persists all current state to disk for next launch
    func saveToCache() {
        let cache = CacheManager.shared

        cache.save(plaidService.transactions, for: .transactions)
        cache.save(plaidService.accounts, for: .plaidAccounts)
        cache.save(plaidService.isLinked, for: .isLinked)
        cache.save(plaidService.dataSource, for: .dataSource)
        cache.save(userCards, for: .userCards)
        cache.save(subscriptions, for: .subscriptions)
        cache.save(benefitMatches, for: .benefitMatches)
        cache.save(stats, for: .userStats)
        cache.save(cardMappingService.mappings, for: .cardMappings)
        cache.save(utilizationService.utilizations, for: .benefitUtilizations)
        cache.save(Date(), for: .lastRefreshDate)
    }
    
    /// Loads and processes transaction data
    func loadData(from transactions: [Transaction]) {
        do {
            // Detect subscriptions
            subscriptions = try SubscriptionDetector.detectSubscriptions(from: transactions)

            // Match benefits
            benefitMatches = try BenefitMatcher.matchBenefits(
                subscriptions: subscriptions,
                userCards: userCards
            )

            // Process utilizations (async)
            Task {
                await processUtilizations(from: transactions)
            }

            // Calculate stats
            calculateStats()

            // Persist to local cache
            saveToCache()

        } catch {
            self.error = .dataProcessing(error.localizedDescription)
            self.showError = true
        }
    }

    /// Processes benefit utilizations from transactions
    func processUtilizations(from transactions: [Transaction]) async {
        guard let userId = authService.user?.uid else {
            benLog("⚠️ No authenticated user for utilization processing")
            return
        }

        // Load existing utilizations
        await utilizationService.loadUtilizations(for: userId)

        // Process transactions to calculate utilizations
        let _ = await utilizationService.processTransactions(
            transactions,
            userCards: userCards,
            userId: userId,
            cardMatches: cardMatches
        )

        // Save utilizations to Firestore
        do {
            try await utilizationService.saveAllUtilizations(userId: userId)
        } catch {
            benLog("❌ Failed to save utilizations: \(error)")
        }

        // Recalculate stats with utilization data
        calculateStats()

        // Persist to local cache
        saveToCache()

        // Notify for any newly auto-matched benefit credits.
        await NotificationManager.shared.notifyNewlyMatchedBenefits(
            utilizations: utilizationService.utilizations,
            userCards: userCards,
            transactions: transactions
        )

        // Detect wrong-card spend (a different card's benefit covers it).
        refreshMissedOpportunities(transactions: transactions)
        await NotificationManager.shared.notifyMissedBenefits(missedOpportunities)

        benLog("✅ Processed utilizations for \(userCards.count) cards")
    }

    // MARK: - Missed Benefit Opportunities

    /// Recomputes wrong-card suggestions from the given transactions.
    func refreshMissedOpportunities(transactions: [Transaction]) {
        let dismissed = Set(
            CacheManager.shared.load([String].self, for: .dismissedOpportunities) ?? []
        )
        missedOpportunities = MissedBenefitDetector.detect(
            transactions: transactions,
            userCards: userCards,
            cardMatches: cardMatches,
            utilizations: utilizationService.utilizations,
            dismissedKeys: dismissed
        )
        if !missedOpportunities.isEmpty {
            benLog("💡 Missed-benefit opportunities: \(missedOpportunities.count)")
        }
    }

    // MARK: - Expiring Benefit Reminders

    /// Unused (or partially used) benefit credits whose current period is
    /// about to reset. Time-based and self-expiring, so no persistence or
    /// dismissal is needed. Window is tiered by period type: a flat 30-day
    /// rule would keep every unused MONTHLY credit flagged all month long.
    var expiringReminders: [BenefitReminder] {
        let now = Date()
        return utilizationService.utilizations.compactMap { util -> BenefitReminder? in
            guard util.periodStart <= now, now <= util.periodEnd,
                  util.periodType != .oneTime,
                  util.amountRemaining > 0,
                  let benefit = CreditCardsData.getBenefit(by: util.benefitId),
                  let card = userCards.first(where: { $0.id == util.cardId })
            else { return nil }

            let daysLeft = util.daysUntilExpiry
            let window = util.periodType == .monthly ? 7 : 30
            guard daysLeft > 0, daysLeft <= window else { return nil }

            return BenefitReminder(
                utilization: util,
                benefit: benefit,
                card: card,
                daysLeft: daysLeft,
                remaining: util.amountRemaining
            )
        }
        .sorted {
            ($0.daysLeft, -$0.remaining) < ($1.daysLeft, -$1.remaining)
        }
    }

    /// Permanently hides a wrong-card suggestion (per benefit + merchant).
    func dismissOpportunity(_ opportunity: MissedBenefitOpportunity) {
        var dismissed = CacheManager.shared.load(
            [String].self, for: .dismissedOpportunities
        ) ?? []
        if !dismissed.contains(opportunity.key) {
            dismissed.append(opportunity.key)
            CacheManager.shared.save(dismissed, for: .dismissedOpportunities)
        }
        missedOpportunities.removeAll { $0.key == opportunity.key }
    }

    /// Refreshes all data from Plaid (server-side sync; the live listener then
    /// updates plaidService.transactions, which the UI observes).
    func refreshData() async {
        await plaidService.refreshTransactions()
        loadData(from: plaidService.transactions)
    }

    /// Calculates statistics and generates recommendations
    private func calculateStats() {
        let monthlyTotal = subscriptions.reduce(0.0) { sum, sub in
            sum + sub.monthlyAmount
        }

        let totalSavings = BenefitMatcher.calculateTotalSavings(benefitMatches)
        let totalFees = userCards.reduce(0.0) { $0 + $1.annualFee }
        let totalBenefits = userCards.reduce(0.0) { $0 + $1.totalBenefitsValue }

        // Utilization stats
        let totalUtilized = utilizationService.totalUtilized
        let utilizationPct = utilizationService.overallUtilizationPercentage
        let expiringSoon = utilizationService.benefitsExpiringSoon.count
        let needingAction = utilizationService.benefitsRequiringAction.count

        stats = UserStats(
            totalSubscriptions: subscriptions.count,
            monthlySubscriptionCost: round(monthlyTotal * 100) / 100,
            annualSubscriptionCost: round(monthlyTotal * 12 * 100) / 100,
            potentialSavings: totalSavings,
            activeCards: userCards.count,
            totalAnnualFees: totalFees,
            totalBenefitsValue: totalBenefits,
            totalBenefitsUtilized: round(totalUtilized * 100) / 100,
            utilizationPercentage: utilizationPct,
            benefitsExpiringSoon: expiringSoon,
            benefitsRequiringAction: needingAction
        )
        
        // Generate recommendations
        recommendations = RecommendationEngine.generateRecommendations(
            userCards: userCards,
            subscriptions: subscriptions,
            benefitMatches: benefitMatches,
            utilizations: utilizationService.utilizations,
            transactions: plaidService.transactions
        )

        // Reschedule notification reminders
        Task {
            await NotificationManager.shared.scheduleReminders(
                utilizations: utilizationService.utilizations,
                userCards: userCards,
                cardMatches: cardMatches
            )
        }
    }

    // MARK: - Benefit Utilization

    /// Manually marks a benefit as used
    func markBenefitUsed(benefitId: String, cardId: String, amount: Double, note: String?) async {
        guard let userId = authService.user?.uid else { return }

        do {
            try await utilizationService.markBenefitUsed(
                benefitId: benefitId,
                cardId: cardId,
                amount: amount,
                note: note,
                userId: userId
            )
            calculateStats()
        } catch {
            self.error = .dataProcessing("Failed to mark benefit: \(error.localizedDescription)")
            self.showError = true
        }
    }

    /// Gets utilizations for a specific card
    func getUtilizations(for card: CreditCard) -> [BenefitUtilization] {
        utilizationService.utilizationsForCard(card.id)
    }

    /// Gets utilization for a specific benefit
    func getUtilization(for benefit: CreditCardBenefit, cardId: String) -> BenefitUtilization? {
        utilizationService.utilizationForBenefit(benefit.id, cardId: cardId)
    }
    
    /// Gets matches for a specific card
    func getMatches(for card: CreditCard) -> [BenefitMatch] {
        benefitMatches.filter { $0.card.id == card.id }
    }
    
    /// Adds a new card
    func addCard(_ card: CreditCard) {
        userCards.append(card)
        // Recalculate matches
        do {
            benefitMatches = try BenefitMatcher.matchBenefits(
                subscriptions: subscriptions,
                userCards: userCards
            )
            calculateStats()
        } catch {
            self.error = .dataProcessing("Failed to add card: \(error.localizedDescription)")
            self.showError = true
        }
    }
    
    /// Removes a card
    func removeCard(_ card: CreditCard) {
        userCards.removeAll { $0.id == card.id }
        // Recalculate matches
        do {
            benefitMatches = try BenefitMatcher.matchBenefits(
                subscriptions: subscriptions,
                userCards: userCards
            )
            calculateStats()
        } catch {
            self.error = .dataProcessing("Failed to remove card: \(error.localizedDescription)")
            self.showError = true
        }
    }

    // MARK: - Card Selection

    /// Processes Plaid accounts and prepares for user card selection
    /// No auto-detection - user explicitly picks which card each account is
    func processPlaidAccounts() async {
        guard let userId = authService.user?.uid else {
            benLog("⚠️ No authenticated user for card processing")
            return
        }

        benLog("🔄 Processing Plaid accounts...")
        benLog("📊 Total accounts from Plaid: \(plaidService.accounts.count)")
        for account in plaidService.accounts {
            benLog("   - \(account.name) (type: \(account.type), subtype: \(account.subtype ?? "nil"))")
        }

        // Load existing mappings from Firestore
        await cardMappingService.loadMappings(for: userId)
        benLog("📋 Loaded \(cardMappingService.mappings.count) saved card mappings")

        // Create match entries for all credit card accounts
        cardMatches = CardDetector.createMatches(from: plaidService.accounts)

        var confirmedCards: [CreditCard] = []
        var hasUnconfirmedAccounts = false

        // Check each match against saved mappings
        for i in 0..<cardMatches.count {
            let plaidAccountId = cardMatches[i].plaidAccount.id

            if let existingMapping = cardMappingService.mappings[plaidAccountId],
               let cardId = existingMapping.creditCardId,
               let card = CreditCardsData.getCard(by: cardId) {
                // Found saved mapping - apply it
                cardMatches[i].creditCard = card
                cardMatches[i].isConfirmed = true
                cardMatches[i].anniversaryDate = existingMapping.anniversaryDate
                confirmedCards.append(card)
                benLog("✅ Restored mapping: \(cardMatches[i].plaidAccount.name) → \(card.name)")
            } else {
                // No mapping - needs user selection
                hasUnconfirmedAccounts = true
                benLog("❓ Needs selection: \(cardMatches[i].plaidAccount.name)")
            }
        }

        // Deduplicate cards (same card linked to multiple accounts)
        var uniqueCards: [String: CreditCard] = [:]
        for card in confirmedCards {
            uniqueCards[card.id] = card
        }
        userCards = Array(uniqueCards.values)

        // Show card selection if any accounts need confirmation
        needsCardConfirmation = hasUnconfirmedAccounts

        // Reload data with confirmed cards
        loadData(from: plaidService.transactions)

        benLog("✅ Processed \(cardMatches.count) accounts, \(userCards.count) confirmed cards")
        if hasUnconfirmedAccounts {
            benLog("📋 Card selection needed for \(cardMatches.filter { !$0.isConfirmed }.count) accounts")
        }
    }

    /// User manually assigns a card to a Plaid account
    func assignCard(_ creditCard: CreditCard?, to plaidAccount: PlaidAccount, anniversaryDate: Date?) async {
        guard let userId = authService.user?.uid else { return }

        let now = Date()
        let mapping = CardMapping(
            plaidAccountId: plaidAccount.id,
            creditCardId: creditCard?.id,
            plaidAccountName: plaidAccount.name,
            plaidAccountMask: plaidAccount.mask,
            isAutoDetected: false,
            createdAt: now,
            updatedAt: now,
            anniversaryDate: anniversaryDate
        )

        do {
            try await cardMappingService.saveMapping(mapping, userId: userId)

            // Update the cardMatches array
            if let index = cardMatches.firstIndex(where: { $0.plaidAccount.id == plaidAccount.id }) {
                cardMatches[index].creditCard = creditCard
                cardMatches[index].isConfirmed = true
                cardMatches[index].anniversaryDate = anniversaryDate
            }

            // Add card to userCards if not already present
            if let card = creditCard, !userCards.contains(where: { $0.id == card.id }) {
                userCards.append(card)
            }

            // Check if all accounts are now confirmed
            needsCardConfirmation = cardMatches.contains { !$0.isConfirmed }

            // Recalculate
            loadData(from: plaidService.transactions)

            // Persist to local cache
            saveToCache()

            benLog("✅ User assigned \(plaidAccount.name) → \(creditCard?.name ?? "Not in database")")
        } catch {
            self.error = .dataProcessing("Failed to save card mapping: \(error.localizedDescription)")
            self.showError = true
        }
    }
    
    /// Updates the anniversary date for a card
    func updateAnniversaryDate(_ date: Date, for plaidAccount: PlaidAccount) async {
        guard let userId = authService.user?.uid else { return }

        // Update in cardMatches
        if let index = cardMatches.firstIndex(where: { $0.plaidAccount.id == plaidAccount.id }) {
            cardMatches[index].anniversaryDate = date

            // Persist anniversary date to Firestore via CardMapping
            if var existingMapping = cardMappingService.mappings[plaidAccount.id] {
                existingMapping.anniversaryDate = date
                try? await cardMappingService.saveMapping(existingMapping, userId: userId)
            }

            // Refresh benefit calculations with new anniversary date
            let _ = await utilizationService.processTransactions(
                plaidService.transactions,
                userCards: userCards,
                userId: userId,
                cardMatches: cardMatches
            )

            // Update local cache
            saveToCache()

            benLog("✅ Updated anniversary date for \(plaidAccount.name) to \(date)")
        }
    }

    /// Clears all data (used when disconnecting)
    func clearAllData() async {
        userCards = []
        cardMatches = []
        subscriptions = []
        benefitMatches = []
        recommendations = []
        missedOpportunities = []
        needsCardConfirmation = false
        // Stop the live listener and reset in-memory Plaid state.
        plaidService.stopTransactionsListener()
        plaidService.transactions = []
        plaidService.accounts = []
        plaidService.itemStatuses = []
        plaidService.isLinked = false
        plaidService.dataSource = .none
        cardMappingService.clearAllMappings()
        utilizationService.clearAllUtilizations()
        calculateStats()
        CacheManager.shared.clearAll()
        clearGeneration += 1
    }

    /// Signs out and clears all local data first, so the UI empties instantly
    /// rather than waiting on a reactive auth-state change to propagate.
    func signOut() async {
        await clearAllData()
        do {
            try authService.signOut()
        } catch {
            benLog("❌ Sign out error: \(error.localizedDescription)")
        }
    }

    /// Permanently deletes the user's account. The server unlinks all Plaid
    /// items, removes every Firestore record, and deletes the Firebase Auth
    /// user (Admin SDK — no recent-login reauth needed). Locally we then wipe
    /// state and end the session. Throws so the UI can surface failures.
    func deleteAccount() async throws {
        _ = try await Functions.functions().httpsCallable("deleteAccount").call()
        await clearAllData()
        try? authService.signOut()
        benLog("✅ Account deleted")
    }
    
    // MARK: - Onboarding
    
    /// Marks onboarding as complete
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // Request notification permission after onboarding
        Task {
            let _ = await NotificationManager.shared.requestPermission()
        }
    }
    
    /// Handles successful Plaid connection
    func handlePlaidSuccess(publicToken: String) async {
        // Exchange public token for access token. exchangePublicToken also
        // fetches accounts, starts the transactions listener, and triggers a
        // server-side sync, so no explicit transaction fetch is needed here.
        await plaidService.exchangePublicToken(publicToken)

        // Process the new data
        await restoreState()
    }
}

// MARK: - Benefit Reminder

/// An unused benefit credit whose current period resets soon.
struct BenefitReminder: Identifiable {
    let utilization: BenefitUtilization
    let benefit: CreditCardBenefit
    let card: CreditCard
    let daysLeft: Int
    let remaining: Double

    var id: String { utilization.id }
}

// MARK: - Error Handling

enum AppError: LocalizedError {
    case dataProcessing(String)
    case network(String)
    case authentication(String)
    
    var errorDescription: String? {
        switch self {
        case .dataProcessing(let message):
            return "Data Processing Error: \(message)"
        case .network(let message):
            return "Network Error: \(message)"
        case .authentication(let message):
            return "Authentication Error: \(message)"
        }
    }
}
