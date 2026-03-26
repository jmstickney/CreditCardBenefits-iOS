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

@MainActor
class AppDataManager: ObservableObject {
    // Services
    @Published var plaidService = PlaidService()
    @Published var authService = AuthService()
    @Published var cardMappingService = CardMappingService()
    @Published var utilizationService = BenefitUtilizationService()

    // Core Data
    @Published var userCards: [CreditCard] = []
    @Published var cardMatches: [CardMatch] = []
    @Published var subscriptions: [Subscription] = []
    @Published var benefitMatches: [BenefitMatch] = []
    @Published var recommendations: [Recommendation] = []
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
    }

    // MARK: - State Restoration

    /// Restores app state on launch — loads cache instantly, then refreshes from network
    func restoreState() async {
        // Phase 1: Load cached data immediately (synchronous, sub-100ms)
        loadFromCache()

        let hasCachedData = !plaidService.transactions.isEmpty

        guard authService.isAuthenticated else {
            print("ℹ️ User not authenticated, showing cached data only")
            return
        }

        guard let userId = authService.user?.uid else {
            print("⚠️ No user ID available for state restoration")
            return
        }

        // Phase 2: Silent network refresh
        // Only show loading indicator if there's no cached data to display
        if !hasCachedData {
            isRestoring = true
        }

        print("🔄 Refreshing from network...")

        let hasConnection = await plaidService.checkExistingConnection()

        if hasConnection {
            await plaidService.fetchTransactions()
            await processPlaidAccounts()
            await utilizationService.loadUtilizations(for: userId)

            // Persist fresh data to cache
            saveToCache()

            print("✅ State restored: \(plaidService.transactions.count) transactions, \(userCards.count) cards")
        } else {
            print("ℹ️ No existing connection to restore")
        }

        isRestoring = false
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
            userCards = cards
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
            print("✅ Loaded cached data: \(plaidService.transactions.count) transactions, \(userCards.count) cards")
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
            print("⚠️ No authenticated user for utilization processing")
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
            print("❌ Failed to save utilizations: \(error)")
        }

        // Recalculate stats with utilization data
        calculateStats()

        // Persist to local cache
        saveToCache()

        print("✅ Processed utilizations for \(userCards.count) cards")
    }

    /// Refreshes all data from Plaid
    func refreshData() async {
        await plaidService.fetchTransactions()
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
            print("⚠️ No authenticated user for card processing")
            return
        }

        print("🔄 Processing Plaid accounts...")
        print("📊 Total accounts from Plaid: \(plaidService.accounts.count)")
        for account in plaidService.accounts {
            print("   - \(account.name) (type: \(account.type), subtype: \(account.subtype ?? "nil"))")
        }

        // Load existing mappings from Firestore
        await cardMappingService.loadMappings(for: userId)
        print("📋 Loaded \(cardMappingService.mappings.count) saved card mappings")

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
                confirmedCards.append(card)
                print("✅ Restored mapping: \(cardMatches[i].plaidAccount.name) → \(card.name)")
            } else {
                // No mapping - needs user selection
                hasUnconfirmedAccounts = true
                print("❓ Needs selection: \(cardMatches[i].plaidAccount.name)")
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

        print("✅ Processed \(cardMatches.count) accounts, \(userCards.count) confirmed cards")
        if hasUnconfirmedAccounts {
            print("📋 Card selection needed for \(cardMatches.filter { !$0.isConfirmed }.count) accounts")
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
            updatedAt: now
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

            print("✅ User assigned \(plaidAccount.name) → \(creditCard?.name ?? "Not in database")")
        } catch {
            self.error = .dataProcessing("Failed to save card mapping: \(error.localizedDescription)")
            self.showError = true
        }
    }
    
    /// Updates the anniversary date for a card
    func updateAnniversaryDate(_ date: Date, for plaidAccount: PlaidAccount) async {
        // Update in cardMatches
        if let index = cardMatches.firstIndex(where: { $0.plaidAccount.id == plaidAccount.id }) {
            cardMatches[index].anniversaryDate = date
            
            // Refresh benefit calculations with new anniversary date
            let _ = await utilizationService.processTransactions(
                plaidService.transactions,
                userCards: userCards,
                userId: authService.user?.uid ?? "",
                cardMatches: cardMatches
            )
            
            print("✅ Updated anniversary date for \(plaidAccount.name) to \(date)")
        }
    }

    /// Clears all data (used when disconnecting)
    func clearAllData() async {
        userCards = []
        cardMatches = []
        subscriptions = []
        benefitMatches = []
        needsCardConfirmation = false
        cardMappingService.clearAllMappings()
        utilizationService.clearAllUtilizations()
        calculateStats()
        CacheManager.shared.clearAll()
    }
    
    // MARK: - Onboarding
    
    /// Marks onboarding as complete
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
    
    /// Handles successful Plaid connection
    func handlePlaidSuccess(publicToken: String) async {
        // Exchange public token for access token
        await plaidService.exchangePublicToken(publicToken)
        
        // Fetch accounts and transactions
        await plaidService.fetchAccounts()
        await plaidService.fetchTransactions()
        
        // Process the new data
        await restoreState()
    }
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
