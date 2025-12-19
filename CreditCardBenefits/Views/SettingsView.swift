//
//  SettingsView.swift
//  CreditCardBenefits
//
//  Settings and test view for Firebase/Plaid integration
//

import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @StateObject private var authService = AuthService()
    @StateObject private var plaidService = PlaidService()

    @State private var email = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var shouldPresentPlaid = false

    // Helper to get view controller
    @State private var rootViewController: UIViewController?

    var body: some View {
        NavigationView {
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
                                .foregroundColor(.green)
                            Text("Bank Connected")
                                .foregroundColor(.green)
                        }

                        Text("\(plaidService.transactions.count) transactions loaded")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button("Refresh Transactions") {
                            Task {
                                await plaidService.fetchTransactions()
                                alertMessage = "Loaded \(plaidService.transactions.count) transactions"
                                showingAlert = true
                            }
                        }
                    } else {
                        Button("Connect Bank Account") {
                            shouldPresentPlaid = true
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

                // Test Functions Section
                Section(header: Text("Test Functions")) {
                    Button("Test Firebase Connection") {
                        testFirebaseConnection()
                    }

                    Button("Test Cloud Functions") {
                        Task {
                            await testCloudFunctions()
                        }
                    }
                    .disabled(!authService.isAuthenticated)
                }
            }
            .navigationTitle("Settings")
            .alert("Message", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                // Get root view controller once on appear
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    rootViewController = windowScene.windows.first?.rootViewController
                }
            }
            .onChange(of: shouldPresentPlaid) {
                if shouldPresentPlaid {
                    shouldPresentPlaid = false
                    connectPlaidBank()
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func connectPlaidBank() {
        guard let vc = rootViewController else {
            print("❌ No root view controller available")
            return
        }

        Task {
            await plaidService.presentPlaidLink(from: vc)
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
}
