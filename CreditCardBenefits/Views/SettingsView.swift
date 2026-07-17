//
//  SettingsView.swift
//  CreditCardBenefits
//
//  Consumer-facing settings. Anything technical/diagnostic lives in the
//  #if DEBUG "Developer" section so it never ships to TestFlight / the App
//  Store (those are Release builds, where DEBUG is not defined).
//

import SwiftUI
import StoreKit
import FirebaseAuth
#if DEBUG
import FirebaseFunctions
#endif

struct SettingsView: View {
    @EnvironmentObject var dataManager: AppDataManager

    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showSignIn = false
    @State private var showDeleteConfirm = false
    @State private var isDeletingAccount = false
    @State private var showManageSubscriptions = false

    @AppStorage(NotificationManager.benefitMatchNotificationsKey)
    private var notifyOnBenefitMatch = true

    @AppStorage(NotificationManager.missedBenefitNotificationsKey)
    private var notifyOnMissedBenefit = true

    #if DEBUG
    @State private var plaidLinkToken: PlaidLinkToken?
    @State private var showConnectSignIn = false

    struct PlaidLinkToken: Identifiable {
        let id = UUID()
        let token: String
    }
    #endif

    private var authService: AuthService {
        dataManager.authService
    }

    private var plaidService: PlaidService {
        dataManager.plaidService
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                connectedBankSection
                subscriptionSection
                notificationsSection
                aboutSection

                #if DEBUG
                developerSection
                #endif
            }
            .navigationTitle("Settings")
            .alert("Message", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .alert("Delete your account?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Account", role: .destructive) {
                    Task { await performAccountDeletion() }
                }
            } message: {
                Text("This permanently deletes your account, disconnects your bank, and erases all of your data. This cannot be undone.\n\nNote: this does not cancel any App Store subscription — manage that in Settings → Apple ID → Subscriptions.")
            }
            #if DEBUG
            .fullScreenCover(item: $plaidLinkToken) { linkToken in
                PlaidLinkView(
                    linkToken: linkToken.token,
                    onSuccess: { publicToken in
                        plaidLinkToken = nil
                        Task {
                            await plaidService.exchangePublicToken(publicToken)
                            await dataManager.processPlaidAccounts()
                        }
                    },
                    onExit: {
                        plaidLinkToken = nil
                    }
                )
                .ignoresSafeArea()
            }
            #endif
        }
    }

    // MARK: - Account

    @ViewBuilder
    private var accountSection: some View {
        Section(header: Text("Account")) {
            if authService.isAuthenticated {
                if let user = authService.user {
                    if let name = user.displayName, !name.isEmpty {
                        Text(name)
                            .font(.system(size: 16, weight: .medium))
                    }
                    if let email = user.email, !email.isEmpty {
                        Text(email)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }

                Button("Sign Out") {
                    Task {
                        await dataManager.signOut()
                        alertMessage = "Signed out successfully"
                        showingAlert = true
                    }
                }
                .foregroundColor(.red)

                if isDeletingAccount {
                    HStack {
                        ProgressView()
                        Text("Deleting account…")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Button("Delete Account", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            } else {
                Button("Sign In") {
                    showSignIn = true
                }
                .sheet(isPresented: $showSignIn) {
                    SignInView()
                        .environmentObject(dataManager)
                }
            }
        }
    }

    // MARK: - Connected Bank

    /// Lets a user unlink their bank. Only place to do so, so it stays in the
    /// production build — but worded plainly, with none of the technical
    /// status (transaction counts, data source, etc.).
    @ViewBuilder
    private var connectedBankSection: some View {
        if authService.isAuthenticated && plaidService.isLinked {
            Section(header: Text("Connected Bank")) {
                Button(role: .destructive) {
                    Task {
                        await plaidService.disconnect()
                        await dataManager.clearAllData()
                        alertMessage = "Your bank has been disconnected."
                        showingAlert = true
                    }
                } label: {
                    Text("Disconnect Bank Account")
                }
            }
        }
    }

    // MARK: - Account Deletion

    private func performAccountDeletion() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        do {
            try await dataManager.deleteAccount()
            alertMessage = "Your account and all data have been deleted."
        } catch {
            alertMessage = "Couldn't delete your account: \(error.localizedDescription)\n\nPlease check your connection and try again."
        }
        showingAlert = true
    }

    // MARK: - Subscription

    @ViewBuilder
    private var subscriptionSection: some View {
        Section(header: Text("Subscription")) {
            HStack {
                Text("Status")
                Spacer()
                Text(dataManager.subscriptionService.isSubscribed ? "Active" : "Not subscribed")
                    .foregroundColor(dataManager.subscriptionService.isSubscribed ? .green : .secondary)
            }

            Button("Manage Subscription") {
                showManageSubscriptions = true
            }
            .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        }
    }

    // MARK: - Notifications

    @ViewBuilder
    private var notificationsSection: some View {
        Section {
            Toggle("Benefit auto-tracked alerts", isOn: $notifyOnBenefitMatch)
            Toggle("Wrong-card alerts", isOn: $notifyOnMissedBenefit)
        } header: {
            Text("Notifications")
        } footer: {
            Text("Benefit alerts fire when Ben detects a credit was used. Wrong-card alerts fire when a purchase could have been covered by a benefit on a different card.")
        }
    }

    // MARK: - About

    @ViewBuilder
    private var aboutSection: some View {
        Section(header: Text("About")) {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Developer (DEBUG only — never ships)

    #if DEBUG
    @ViewBuilder
    private var developerSection: some View {
        // Bank connection + status
        Section(header: Text("Plaid Integration")) {
            if plaidService.isLinked {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(plaidService.dataSource == .demo ? .orange : .green)
                    Text(plaidService.dataSource == .demo ? "Demo Data Active" : "Bank Connected")
                        .foregroundColor(plaidService.dataSource == .demo ? .orange : .green)
                }

                Text("\(plaidService.transactions.count) transactions loaded (\(plaidService.dataSource.displayName))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Refresh Transactions") {
                    Task {
                        await plaidService.refreshTransactions()
                        alertMessage = "Refresh requested — new transactions will appear shortly"
                        showingAlert = true
                    }
                }
            } else {
                Button("Connect Bank Account") {
                    if authService.isAuthenticated {
                        startBankConnection()
                    } else {
                        showConnectSignIn = true
                    }
                }
                .authGate(
                    isPresented: $showConnectSignIn,
                    dataManager: dataManager
                ) {
                    startBankConnection()
                }
            }

            if plaidService.isLoading {
                HStack {
                    ProgressView()
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }
            }
        }

        // Raw transactions dump
        if !plaidService.transactions.isEmpty {
            Section(header: Text("Transactions (\(plaidService.transactions.count))")) {
                ForEach(plaidService.transactions.prefix(10)) { transaction in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(transaction.merchant)
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Text(String(format: "$%.2f", transaction.amount))
                                .font(.system(size: 14, weight: .medium))
                        }

                        HStack {
                            Text(transaction.dateString)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if let category = transaction.category {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(category)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                if plaidService.transactions.count > 10 {
                    Text("Showing first 10 of \(plaidService.transactions.count) transactions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }

        // Card matching internals
        if !dataManager.cardMatches.isEmpty {
            Section(header: Text("Credit Cards (\(dataManager.cardMatches.count))")) {
                ForEach(dataManager.cardMatches) { match in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: match.isConfirmed ? "checkmark.circle.fill" : "questionmark.circle.fill")
                                .foregroundColor(match.isConfirmed ? .green : .orange)

                            VStack(alignment: .leading, spacing: 2) {
                                if let card = match.creditCard {
                                    Text(card.name)
                                        .font(.system(size: 14, weight: .semibold))
                                } else {
                                    Text("Card not selected")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.orange)
                                }

                                HStack {
                                    Text(match.plaidAccount.name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if let mask = match.plaidAccount.mask {
                                        Text("•••• \(mask)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            Spacer()

                            if match.isConfirmed, let card = match.creditCard {
                                Text("\(card.benefits.count) benefits")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Button("Re-process Accounts") {
                    Task {
                        await dataManager.processPlaidAccounts()
                        alertMessage = "Found \(dataManager.cardMatches.count) credit card accounts"
                        showingAlert = true
                    }
                }

                if dataManager.cardMatches.contains(where: { !$0.isConfirmed }) {
                    Button("Select Card Types") {
                        dataManager.needsCardConfirmation = true
                    }
                    .foregroundColor(.blue)
                }
            }
        }

        // Developer tools
        Section(header: Text("Developer Tools")) {
            if let user = authService.user {
                Text("User ID: \(user.uid)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Button("Load Demo Data (No Plaid)") {
                Task {
                    do {
                        try await plaidService.populateDemoData()
                        alertMessage = "✅ Demo data loaded!\n\nThis is simulated transaction data for testing, split between your Chase Reserve and Amex Blue Preferred cards.\n\nCheck the Home tab to see your demo subscriptions."
                        showingAlert = true
                    } catch {
                        alertMessage = "Error: \(error.localizedDescription)"
                        showingAlert = true
                    }
                }
            }
            .disabled(!authService.isAuthenticated)

            Button("Test Firebase Connection") {
                testFirebaseConnection()
            }

            Button("Test Cloud Functions") {
                Task {
                    await testCloudFunctions()
                }
            }
            .disabled(!authService.isAuthenticated)

            Button("Fire Test Webhook") {
                Task {
                    await fireTestWebhook()
                }
            }
            .disabled(!authService.isAuthenticated)

            Toggle("Show Onboarding Every Launch", isOn: Binding(
                get: { UserDefaults.standard.bool(forKey: "alwaysShowOnboarding") },
                set: { newValue in
                    UserDefaults.standard.set(newValue, forKey: "alwaysShowOnboarding")
                    if newValue {
                        dataManager.hasCompletedOnboarding = false
                        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                    }
                }
            ))

            Button("Reset Onboarding Once") {
                dataManager.hasCompletedOnboarding = false
                UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                alertMessage = "Onboarding reset! Close and reopen the app."
                showingAlert = true
            }
            .foregroundColor(.orange)

            Button("Clear All Data") {
                Task {
                    await plaidService.disconnect()
                    await dataManager.clearAllData()
                    alertMessage = "All data cleared"
                    showingAlert = true
                }
            }
            .foregroundColor(.red)
        }
    }

    // MARK: - Bank Connection (DEBUG)

    private func startBankConnection() {
        Task {
            do {
                let token = try await plaidService.createLinkToken()
                await MainActor.run {
                    plaidLinkToken = PlaidLinkToken(token: token)
                }
            } catch {
                alertMessage = "Error: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }

    // MARK: - Test Functions (DEBUG)

    private func testFirebaseConnection() {
        if authService.isAuthenticated {
            alertMessage = "✅ Firebase is connected!\nAuthenticated user: \(authService.user?.uid ?? "unknown")"
        } else {
            alertMessage = "⚠️ Firebase initialized but no user signed in"
        }
        showingAlert = true
    }

    private func fireTestWebhook() async {
        do {
            let result = try await Functions.functions().httpsCallable("fireTestWebhook").call()
            if let data = result.data as? [String: Any],
               let message = data["message"] as? String {
                alertMessage = "✅ \(message)"
            } else {
                alertMessage = "✅ Webhook fired"
            }
            showingAlert = true
        } catch {
            alertMessage = "❌ Webhook error:\n\(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func testCloudFunctions() async {
        do {
            let linkToken = try await plaidService.createLinkToken()
            alertMessage = "✅ Cloud Functions working!\nLink token created: \(linkToken.prefix(20))..."
            showingAlert = true
        } catch {
            alertMessage = "❌ Cloud Functions error:\n\(error.localizedDescription)"
            showingAlert = true
        }
    }
    #endif
}

#Preview {
    SettingsView()
        .environmentObject(AppDataManager())
}
