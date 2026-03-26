//
//  SettingsView.swift
//  CreditCardBenefits
//
//  Settings and test view for Firebase/Plaid integration
//

import SwiftUI
import FirebaseAuth
import FirebaseFunctions

struct SettingsView: View {
    @EnvironmentObject var dataManager: AppDataManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var plaidLinkToken: PlaidLinkToken?

    struct PlaidLinkToken: Identifiable {
        let id = UUID()
        let token: String
    }
    
    private var authService: AuthService {
        dataManager.authService
    }
    
    private var plaidService: PlaidService {
        dataManager.plaidService
    }

    var body: some View {
        NavigationStack {
            Form {
                // Firebase Authentication Section
                Section(header: Text("Firebase Authentication")) {
                    if authService.isAuthenticated {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Connected")
                                .foregroundColor(.green)
                        }

                        if let user = authService.user {
                            Text("User ID: \(user.uid)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Button("Sign Out") {
                            do {
                                try authService.signOut()
                                alertMessage = "Signed out successfully"
                                showingAlert = true
                            } catch {
                                alertMessage = "Error: \(error.localizedDescription)"
                                showingAlert = true
                            }
                        }
                        .foregroundColor(.red)
                    } else {
                        TextField("Email", text: $email)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)

                        SecureField("Password", text: $password)

                        Button("Sign In") {
                            Task {
                                do {
                                    try await authService.signIn(email: email, password: password)
                                    alertMessage = "Signed in successfully!"
                                    showingAlert = true
                                } catch {
                                    alertMessage = "Error: \(error.localizedDescription)"
                                    showingAlert = true
                                }
                            }
                        }

                        Button("Sign Up") {
                            Task {
                                do {
                                    try await authService.signUp(email: email, password: password)
                                    alertMessage = "Account created successfully!"
                                    showingAlert = true
                                } catch {
                                    alertMessage = "Error: \(error.localizedDescription)"
                                    showingAlert = true
                                }
                            }
                        }

                        Button("Sign In Anonymously (Test)") {
                            Task {
                                do {
                                    try await authService.signInAnonymously()
                                    alertMessage = "Signed in anonymously!"
                                    showingAlert = true
                                } catch {
                                    alertMessage = "Error: \(error.localizedDescription)"
                                    showingAlert = true
                                }
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                }

                // Plaid Integration Section
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
                                await plaidService.fetchTransactions()
                                alertMessage = "Loaded \(plaidService.transactions.count) transactions"
                                showingAlert = true
                            }
                        }

                        Button("Disconnect Bank") {
                            Task {
                                await plaidService.disconnect()
                                await dataManager.clearAllData()
                                alertMessage = "Bank disconnected"
                                showingAlert = true
                            }
                        }
                        .foregroundColor(.red)
                    } else {
                        Button("Connect Bank Account") {
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
                        .disabled(!authService.isAuthenticated)

                        if !authService.isAuthenticated {
                            Text("Sign in first to connect bank")
                                .font(.caption)
                                .foregroundColor(.secondary)
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

                // Transactions Section
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

                // Credit Cards Section - shows deduplicated cards from cardMatches
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

                #if DEBUG
                // Developer Tools Section (only visible in debug builds)
                Section(header: Text("Developer Tools")) {
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
                                // Also reset it now
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
                #endif
            }
            .navigationTitle("Settings")
            .alert("Message", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .fullScreenCover(item: $plaidLinkToken) { linkToken in
                PlaidLinkView(
                    linkToken: linkToken.token,
                    onSuccess: { publicToken in
                        plaidLinkToken = nil
                        Task {
                            await plaidService.exchangePublicToken(publicToken)
                            // Process accounts and detect cards after linking
                            await dataManager.processPlaidAccounts()
                        }
                    },
                    onExit: {
                        plaidLinkToken = nil
                    }
                )
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Test Functions

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
}

#Preview {
    SettingsView()
        .environmentObject(AppDataManager())
}
