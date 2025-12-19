//
//  CreditCardBenefitsApp.swift
//  CreditCardBenefits
//
//  Created for Credit Card Benefits Tracker POC
//

import SwiftUI
import FirebaseCore

@main
struct CreditCardBenefitsApp: App {

    init() {
        // Initialize Firebase when app launches
        FirebaseApp.configure()
        print("✅ Firebase initialized successfully")
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
