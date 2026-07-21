//
//  SignInView.swift
//  CreditCardBenefits
//
//  Sign-in sheet (Sign in with Apple + Google), presented on demand when the
//  user takes an account-bound action.
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var dataManager: AppDataManager
    @Environment(\.dismiss) private var dismiss

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
                Text("🔒 We use Plaid — the same connection trusted by Venmo and Robinhood.")
                    .font(Ben.Font.sans(14, weight: .regular))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            Spacer()

            SignInButtonsView(onSignedIn: { dismiss() })
                .padding(.horizontal, 24)

            Spacer(minLength: 24)
        }
        .padding()
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Sign-In Buttons (shared)

/// The Apple + Google sign-in buttons with shared busy/error handling — used
/// by the SignInView sheet and the onboarding sign-in step.
struct SignInButtonsView: View {
    @EnvironmentObject var dataManager: AppDataManager
    @Environment(\.colorScheme) private var colorScheme
    let onSignedIn: () -> Void

    @State private var isWorking = false
    @State private var errorMessage: String?

    /// Sign in with Apple button visibility. Required ON for App Store review
    /// (Guideline 4.8 — mandatory when offering Google sign-in). Needs the
    /// "Sign in with Apple" capability in Xcode + the Apple provider enabled in
    /// Firebase console to actually work.
    private let appleSignInEnabled = true

    private var authService: AuthService { dataManager.authService }

    var body: some View {
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

            // Custom button (not GoogleSignInSwift's): the SDK button draws
            // its own chrome with a fixed small corner radius, so it can't
            // visually match the Apple button above. Same 50pt height,
            // 10pt corners, official G mark drawn from the logo geometry.
            GoogleStyleSignInButton {
                run { try await authService.signInWithGoogle() }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .disabled(isWorking)
        .overlay {
            if isWorking { ProgressView() }
        }
    }

    /// Runs an async sign-in action: report success, stay silent on user
    /// cancellation, otherwise surface the error.
    private func run(_ action: @escaping () async throws -> Void) {
        Task { @MainActor in
            isWorking = true
            errorMessage = nil
            do {
                try await action()
                isWorking = false
                onSignedIn()
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

// MARK: - Google Sign-In Button (custom)

/// "Sign in with Google" button styled to exactly match the Apple button above
/// it (50pt tall, 10pt corners). Google's SDK button draws its own fixed
/// chrome, so it can't be restyled — this replicates the branding (official
/// colors + G geometry) in SwiftUI instead.
struct GoogleStyleSignInButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                GoogleGMark()
                    .frame(width: 20, height: 20)
                Text("Sign in with Google")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(.black.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// The Google "G", drawn from the official logo geometry (48×48 viewBox:
/// ring mid-radius 17.6, stroke 8.75, four brand-color arcs + the blue
/// crossbar). Angles are screen-space degrees (0° = right, clockwise).
private struct GoogleGMark: View {
    private static let blue = Color(red: 0.259, green: 0.522, blue: 0.957)   // #4285F4
    private static let green = Color(red: 0.204, green: 0.659, blue: 0.325)  // #34A853
    private static let yellow = Color(red: 0.984, green: 0.737, blue: 0.020) // #FBBC05
    private static let red = Color(red: 0.918, green: 0.263, blue: 0.208)    // #EA4335

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: s / 2, y: s / 2)
            let midRadius = s * (17.625 / 48)
            let lineWidth = s * (8.75 / 48)

            ZStack {
                arc(center, midRadius, from: 211, to: 312).stroke(Self.red, lineWidth: lineWidth)
                arc(center, midRadius, from: 153, to: 211).stroke(Self.yellow, lineWidth: lineWidth)
                arc(center, midRadius, from: 45, to: 153).stroke(Self.green, lineWidth: lineWidth)
                arc(center, midRadius, from: 11.8, to: 45).stroke(Self.blue, lineWidth: lineWidth)

                // Crossbar: from the center out to the right edge of the ring.
                Path { path in
                    path.addRect(CGRect(
                        x: s * 0.5,
                        y: s * (20.0 / 48),
                        width: s * ((45.12 - 24.0) / 48),
                        height: s * ((28.51 - 20.0) / 48)
                    ))
                }
                .fill(Self.blue)
            }
        }
    }

    private func arc(_ center: CGPoint, _ radius: CGFloat, from: Double, to: Double) -> Path {
        Path { path in
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(from),
                endAngle: .degrees(to),
                clockwise: false
            )
        }
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
