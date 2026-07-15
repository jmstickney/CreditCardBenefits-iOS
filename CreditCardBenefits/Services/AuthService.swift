//
//  AuthService.swift
//  CreditCardBenefits
//
//  Firebase Authentication Service (Sign in with Apple + Google)
//

import Foundation
import Combine
import UIKit
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

class AuthService: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var error: String?

    /// Raw nonce for the in-flight Apple request; consumed on completion.
    private var currentNonce: String?

    init() {
        // Listen for auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.isAuthenticated = user != nil
            benLog("Auth state changed. Authenticated: \(user != nil)")
        }
    }

    // MARK: - Sign Out

    func signOut() throws {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            self.user = nil
            self.isAuthenticated = false
            benLog("✅ User signed out")
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    // MARK: - Google

    @MainActor
    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.missingClientID
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presenter = UIApplication.shared.rootViewController else {
            throw AuthError.noPresenter
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presenter
            )
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.missingIDToken
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            let authResult = try await Auth.auth().signIn(with: credential)
            self.user = authResult.user
            self.isAuthenticated = true
            benLog("✅ Signed in with Google: \(authResult.user.uid)")
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    // MARK: - Apple

    /// Configure the Apple ID request: requested scopes + a hashed nonce. The
    /// raw nonce is stashed and passed to Firebase on completion.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    @MainActor
    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) async throws {
        switch result {
        case .failure(let error):
            throw error
        case .success(let authorization):
            guard
                let appleIDCredential =
                    authorization.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce,
                let appleIDToken = appleIDCredential.identityToken,
                let idTokenString = String(data: appleIDToken, encoding: .utf8)
            else {
                throw AuthError.missingIDToken
            }

            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )

            do {
                let authResult = try await Auth.auth().signIn(with: credential)
                self.user = authResult.user
                self.isAuthenticated = true
                self.currentNonce = nil
                benLog("✅ Signed in with Apple: \(authResult.user.uid)")
            } catch {
                self.error = error.localizedDescription
                throw error
            }
        }
    }

    // MARK: - Nonce helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(
            kSecRandomDefault, randomBytes.count, &randomBytes
        )
        if status != errSecSuccess {
            fatalError("SecRandomCopyBytes failed with OSStatus \(status)")
        }
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    enum AuthError: LocalizedError {
        case missingClientID
        case noPresenter
        case missingIDToken

        var errorDescription: String? {
            switch self {
            case .missingClientID:
                return "Missing Google client ID."
            case .noPresenter:
                return "Unable to present sign-in."
            case .missingIDToken:
                return "Sign-in failed: missing identity token."
            }
        }
    }
}
