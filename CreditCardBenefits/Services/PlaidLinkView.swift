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
        print("🔗 PlaidLinkViewController init with token: \(linkToken.prefix(30))...")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔗 PlaidLinkViewController viewDidLoad")
        view.backgroundColor = .systemBackground
    }

    override func viewDidAppear(_ animated: Bool) {
        print("🔗 PlaidLinkViewController viewDidAppear")
        super.viewDidAppear(animated)

        // Only present once
        guard linkHandler == nil else { return }

        print("🔗 Creating Plaid Link with token: \(linkToken.prefix(30))...")

        // Create Link configuration
        var linkConfiguration = LinkTokenConfiguration(
            token: linkToken
        ) { [weak self] success in
            print("✅ Plaid Link success: \(success.publicToken)")
            self?.onSuccess(success.publicToken)
        }

        linkConfiguration.onExit = { [weak self] exit in
            if let error = exit.error {
                print("❌ Plaid Link exit with error: \(error)")
            } else {
                print("ℹ️ User exited Plaid Link: \(String(describing: exit.metadata.status))")
            }
            self?.onExit()
        }

        // Create and open Plaid Link
        print("🔗 Calling Plaid.create()...")
        let result = Plaid.create(linkConfiguration)
        switch result {
        case .success(let handler):
            print("🔗 Plaid handler created, opening...")
            self.linkHandler = handler
            handler.open(presentUsing: .viewController(self))
        case .failure(let error):
            print("❌ Plaid Link creation failed: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            onExit()
        }
    }
}
