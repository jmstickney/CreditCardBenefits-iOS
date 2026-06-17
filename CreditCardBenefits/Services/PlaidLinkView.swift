//
//  PlaidLinkView.swift
//  CreditCardBenefits
//
//  SwiftUI wrapper for Plaid Link
//

import SwiftUI
import LinkKit

struct PlaidLinkView: UIViewControllerRepresentable {
    let linkToken: String
    let onSuccess: (String) -> Void
    let onExit: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        return PlaidLinkViewController(
            linkToken: linkToken,
            onSuccess: onSuccess,
            onExit: onExit
        )
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}

class PlaidLinkViewController: UIViewController {
    private let linkToken: String
    private let onSuccess: (String) -> Void
    private let onExit: () -> Void
    private var linkHandler: Handler?

    init(linkToken: String, onSuccess: @escaping (String) -> Void, onExit: @escaping () -> Void) {
        self.linkToken = linkToken
        self.onSuccess = onSuccess
        self.onExit = onExit
        super.init(nibName: nil, bundle: nil)
        benLog("🔗 PlaidLinkViewController init")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        benLog("🔗 PlaidLinkViewController viewDidLoad")
        view.backgroundColor = .systemBackground
    }

    override func viewDidAppear(_ animated: Bool) {
        benLog("🔗 PlaidLinkViewController viewDidAppear")
        super.viewDidAppear(animated)

        // Only present once
        guard linkHandler == nil else { return }

        benLog("🔗 Creating Plaid Link")

        // Create Link configuration
        var linkConfiguration = LinkTokenConfiguration(
            token: linkToken
        ) { [weak self] success in
            benLog("✅ Plaid Link success (public token received)")
            self?.onSuccess(success.publicToken)
        }

        linkConfiguration.onExit = { [weak self] exit in
            if let error = exit.error {
                benLog("❌ Plaid Link exit with error: \(error)")
            } else {
                benLog("ℹ️ User exited Plaid Link: \(String(describing: exit.metadata.status))")
            }
            self?.onExit()
        }

        // Create and open Plaid Link
        benLog("🔗 Calling Plaid.create()...")
        let result = Plaid.create(linkConfiguration)
        switch result {
        case .success(let handler):
            benLog("🔗 Plaid handler created, opening...")
            self.linkHandler = handler
            handler.open(presentUsing: .viewController(self))
        case .failure(let error):
            benLog("❌ Plaid Link creation failed: \(error)")
            benLog("❌ Error details: \(error.localizedDescription)")
            onExit()
        }
    }
}
