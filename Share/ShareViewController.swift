import UIKit
import UniformTypeIdentifiers

/// What the share sheet runs when Hearth is chosen. It leaves what was shared where the app will find it,
/// then opens the app, which puts it into the message being written.
final class ShareViewController: UIViewController {
    private static let padding: CGFloat = 24
    /// How long the note stays up when the app could not be opened from here.
    private static let noteDuration: Duration = .seconds(1.6)

    private let note = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        note.text = String(localized: "share.saving", defaultValue: "Sending to Hearth…")
        note.font = .preferredFont(forTextStyle: .headline)
        note.adjustsFontForContentSizeCategory = true
        note.textAlignment = .center
        note.numberOfLines = 0
        note.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(note)
        NSLayoutConstraint.activate([
            note.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            note.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Self.padding),
            note.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Self.padding)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await shareAction() }
    }

    /// Saves what was shared, opens the app, and closes the sheet.
    private func shareAction() async {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let isSaved = await SharedItemWriter.write(items)
        if isSaved, openApp() {
            extensionContext?.completeRequest(returningItems: nil)
            return
        }
        note.text = isSaved
            ? String(localized: "share.saved", defaultValue: "Added. Open Hearth to carry on.")
            : String(localized: "share.failed", defaultValue: "Hearth could not take that.")
        try? await Task.sleep(for: Self.noteDuration)
        extensionContext?.completeRequest(returningItems: nil)
    }

    /// An extension has no direct way to open its app, so the request is handed up the responder chain to the
    /// application it runs within, by the name of the method that opens a link.
    private func openApp() -> Bool {
        typealias OpenLink = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, AnyObject?) -> Void
        guard let url = NSURL(string: "hearth://share") else {
            return false
        }
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        var responder: UIResponder? = self
        while let current = responder {
            if current.responds(to: selector), let method = class_getInstanceMethod(type(of: current), selector) {
                let open = unsafeBitCast(method_getImplementation(method), to: OpenLink.self)
                open(current, selector, url, NSDictionary(), nil)
                return true
            }
            responder = current.next
        }
        return false
    }
}
