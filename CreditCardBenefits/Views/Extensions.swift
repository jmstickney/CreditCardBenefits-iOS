//
//  Extensions.swift
//  CreditCardBenefits
//
//  Shared extensions and utilities
//

import Foundation
import SwiftUI

// MARK: - Double Extensions

extension Double {
    /// Formats the double as currency with customizable fraction digits
    /// - Parameter maximumFractionDigits: Maximum number of decimal places (default: 0)
    /// - Returns: Formatted currency string (e.g., "$1,234" or "$12.99")
    func asCurrency(maximumFractionDigits: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: self)) ?? "$0"
    }
}

// MARK: - Date Extensions

extension Date {
    /// Formats date as "Wednesday, February 4"
    var asDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: self)
    }
    
    /// Formats date as "Feb 4, 2024"
    var asShortDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: self)
    }
    
    /// Creates a date from string in format "yyyy-MM-dd"
    static func from(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}

// MARK: - Color Extensions

extension Color {
    // MARK: - Ben Color Theme
    static let benForest     = Color(red: 0.102, green: 0.239, blue: 0.169) // #1A3D2B
    static let benMint       = Color(red: 0.490, green: 0.749, blue: 0.604) // #7DBF9A
    static let benCream      = Color(red: 0.996, green: 0.988, blue: 0.969) // #FEFCF7
    static let benSand       = Color(red: 0.933, green: 0.914, blue: 0.875) // #EEE9DF
    static let benBark       = Color(red: 0.420, green: 0.388, blue: 0.337) // #6B6356
    static let benMute       = Color(red: 0.541, green: 0.498, blue: 0.431) // #8A7F6E
    static let benDark       = Color(red: 0.110, green: 0.102, blue: 0.082) // #1C1A15
    static let benWarn       = Color(red: 0.722, green: 0.361, blue: 0.039) // #B85C0A
    static let benGoodGreen  = Color(red: 0.102, green: 0.420, blue: 0.251) // #1A6B40
    static let benLightMint  = Color(red: 0.910, green: 0.961, blue: 0.933) // #E8F5EE
    
    /// Returns color for data source badge
    static func forDataSource(_ dataSource: DataSource) -> Color {
        switch dataSource.badgeColor {
        case "green":
            return .benGoodGreen
        case "orange":
            return .benWarn
        case "gray":
            return .benMute
        default:
            return .benMute
        }
    }
    
    /// Card gradient colors by issuer
    static func cardGradient(for issuer: CardIssuer) -> [Color] {
        switch issuer {
        case .amex:
            return [Color(red: 0.0, green: 0.4, blue: 0.7), Color(red: 0.0, green: 0.3, blue: 0.5)]
        case .chase:
            return [Color(red: 0.0, green: 0.2, blue: 0.5), Color(red: 0.0, green: 0.1, blue: 0.3)]
        case .capitalOne:
            return [Color(red: 0.8, green: 0.1, blue: 0.1), Color(red: 0.6, green: 0.0, blue: 0.0)]
        default:
            return [Color.gray, Color.gray.opacity(0.7)]
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies a card-style background
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
    }
    
    /// Applies horizontal padding
    func horizontalPadding(_ value: CGFloat = 16) -> some View {
        self.padding(.horizontal, value)
    }
}
