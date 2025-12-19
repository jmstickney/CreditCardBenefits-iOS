//
//  AuthService.swift
//  CreditCardBenefits
//
//  Firebase Authentication Service
//

import Foundation
import FirebaseAuth
import Combine

class AuthService: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var error: String?

    init() {
        // Listen for auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.isAuthenticated = user != nil
            print("Auth state changed. Authenticated: \(user != nil)")
        }
    }

    // Sign up with email and password
    func signUp(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            await MainActor.run {
                self.user = result.user
                self.isAuthenticated = true
                print("✅ User signed up: \(result.user.uid)")
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
            throw error
        }
    }

    // Sign in with email and password
    func signIn(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            await MainActor.run {
                self.user = result.user
                self.isAuthenticated = true
                print("✅ User signed in: \(result.user.uid)")
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
            throw error
        }
    }

    // Sign out
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            self.user = nil
            self.isAuthenticated = false
            print("✅ User signed out")
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    // Anonymous sign in (for testing)
    func signInAnonymously() async throws {
        do {
            let result = try await Auth.auth().signInAnonymously()
            await MainActor.run {
                self.user = result.user
                self.isAuthenticated = true
                print("✅ User signed in anonymously: \(result.user.uid)")
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
            throw error
        }
    }
}
