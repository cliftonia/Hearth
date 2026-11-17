import UIKit
import UniformTypeIdentifiers

/// What the share sheet runs when Hearth is chosen. It leaves what was shared where the app will find it, says so,
/// and closes. The app takes it into the message being written the next time it comes to the front.
///
/// An extension has no public way to open its app, so it does not try to.
final class ShareViewController: UIViewController {
    private static let padding: CGFloat = 24
    /// How long the note stays up once what was shared has been saved, or could not be.
    private static let noteDuration: Duration = .seconds(2)

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

    /// Saves what was shared, says where it will be found, and closes the sheet.
    private func shareAction() async {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let isSaved = await SharedItemWriter.write(items)
        note.text = isSaved
            ? String(localized: "share.added", defaultValue: "Added to Hearth. It will be in the composer next time you open Hearth.")
            : String(localized: "share.failed", defaultValue: "Hearth could not take that.")
        UIAccessibility.post(notification: .announcement, argument: note.text)
        try? await Task.sleep(for: Self.noteDuration)
        extensionContext?.completeRequest(returningItems: nil)
    }
}
