//
//  SignInView.swift
//  CreditCardBenefits
//
//  Sign-in sheet (Sign in with Apple + Google), presented on demand when the
//  user takes an account-bound action.
//

import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

struct SignInView: View {
    @EnvironmentObject var dataManager: AppDataManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var isWorking = false
    @State private var errorMessage: String?

    /// Sign in with Apple button visibility. Required ON for App Store review
    /// (Guideline 4.8 — mandatory when offering Google sign-in). Needs the
    /// "Sign in with Apple" capability in Xcode + the Apple provider enabled in
    /// Firebase console to actually work.
    private let appleSignInEnabled = true

    private var authService: AuthService { dataManager.authService }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("ben.")
                .font(Ben.Font.serif(34))
                .foregroundColor(Ben.Color.forest)

            VStack(spacing: 6) {
                Text("Sign in to continue")
                    .font(Ben.Font.sans(18, weight: .semibold))
                    .foregroundColor(Ben.Color.textPrimary)
                Text("Securely connect your accounts and sync your benefits.")
                    .font(Ben.Font.sans(14, weight: .regular))
                    .foregroundColor(Ben.Color.textMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                if appleSignInEnabled {
                    SignInWithAppleButton(.signIn) { request in
                        authService.prepareAppleRequest(request)
                    } onCompletion: { result in
                        run { try await authService.completeAppleSignIn(result) }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                    .cornerRadius(10)
                }

                GoogleSignInButton {
                    run { try await authService.signInWithGoogle() }
                }
                .frame(height: 50)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .disabled(isWorking)
            .overlay {
                if isWorking { ProgressView() }
            }

            Spacer(minLength: 24)
        }
        .padding()
        .presentationDetents([.medium, .large])
    }

    /// Runs an async sign-in action: dismiss on success, stay silent on user
    /// cancellation, otherwise surface the error.
    private func run(_ action: @escaping () async throws -> Void) {
        Task { @MainActor in
            isWorking = true
            errorMessage = nil
            do {
                try await action()
                isWorking = false
                dismiss()
            } catch {
                isWorking = false
                if isCancellation(error) { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        if let asError = error as? ASAuthorizationError {
            return asError.code == .canceled
        }
        // GoogleSignIn returns code -5 (canceled) in its error domain.
        let nsError = error as NSError
        return nsError.code == -5 && nsError.domain.contains("GIDSignIn")
    }
}

extension View {
    /// Presents the sign-in sheet when `isPresented` is set, then runs
    /// `onAuthed` once after the sheet dismisses — but only if the user ended up
    /// signed in. Use to gate account-bound actions (connect bank / add card).
    func authGate(
        isPresented: Binding<Bool>,
        dataManager: AppDataManager,
        onAuthed: @escaping () -> Void
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: {
            if dataManager.authService.isAuthenticated {
                onAuthed()
            }
        }) {
            SignInView()
                .environmentObject(dataManager)
        }
    }
}

#Preview {
    SignInView()
        .environmentObject(AppDataManager())
}
