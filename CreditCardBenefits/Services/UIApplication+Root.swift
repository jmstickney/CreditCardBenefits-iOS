//
//  UIApplication+Root.swift
//  CreditCardBenefits
//
//  Helper to find a presenting view controller (used by Google Sign-In).
//

import UIKit

extension UIApplication {
    /// The root view controller of the active, foreground key window.
    var rootViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
