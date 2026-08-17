import UIKit

/// Hands an EPUB off to Apple Books (or whatever other app claims the EPUB
/// document type) via the system "Open In" menu, skipping our own share/
/// preview UI. Retains the `UIDocumentInteractionController` for the
/// duration of the interaction since nothing else holds a strong reference
/// to it.
@MainActor
final class EPUBOpener: NSObject, UIDocumentInteractionControllerDelegate {
    static let shared = EPUBOpener()

    private var controller: UIDocumentInteractionController?

    /// Presents the "Open In" menu for `url`, filtered to apps that handle
    /// EPUBs (typically just Books). Returns `false` if no such app is
    /// installed, so callers can fall back to their own preview/share flow.
    @discardableResult
    func open(_ url: URL) -> Bool {
        guard let rootViewController else { return false }
        let controller = UIDocumentInteractionController(url: url)
        controller.delegate = self
        self.controller = controller

        let anchor = CGRect(
            x: rootViewController.view.bounds.midX,
            y: rootViewController.view.bounds.maxY,
            width: 1,
            height: 1
        )
        return controller.presentOpenInMenu(from: anchor, in: rootViewController.view, animated: true)
    }

    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        rootViewController ?? UIViewController()
    }

    private var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}
