//
//  Log.swift
//  CreditCardBenefits
//
//  Lightweight logging that is compiled out of release builds.
//

import Foundation

/// Debug-only logging helper. In release builds the body is compiled out, so no
/// console output — and therefore no tokens, account data, or other PII — can
/// leak from a shipped app. Mirrors the signature of `Swift.print`, so it is a
/// drop-in replacement for the `print` calls throughout the app.
func benLog(
    _ items: Any...,
    separator: String = " ",
    terminator: String = "\n"
) {
    #if DEBUG
    let message = items.map { String(describing: $0) }.joined(separator: separator)
    Swift.print(message, terminator: terminator)
    #endif
}
