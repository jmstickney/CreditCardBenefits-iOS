//
//  AppCheckConfig.swift
//  CreditCardBenefits
//
//  Firebase App Check setup (device attestation).
//

import FirebaseAppCheck
import FirebaseCore

/// Supplies the App Check attestation provider for release builds. App Attest is
/// available on every OS version this app supports (deployment target is iOS 18),
/// so no DeviceCheck fallback is required.
final class BenAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        AppAttestProvider(app: app)
    }
}

/// Installs the App Check provider factory. MUST be called *before*
/// `FirebaseApp.configure()`.
///
/// In DEBUG builds — including the simulator, where App Attest is unavailable —
/// the debug provider is used. On first launch it prints a debug token to the
/// Xcode console; register that token in the Firebase console under
/// App Check → Apps → (this app) → Manage debug tokens so debug builds pass.
func configureAppCheck() {
    #if DEBUG
    AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
    #else
    AppCheck.setAppCheckProviderFactory(BenAppCheckProviderFactory())
    #endif
}
