import Foundation
import UniformTypeIdentifiers

/// Writes shared text, links, pictures and files into the folder the app and its extensions share.
///
/// Each share gets a folder of its own under `Inbox`. Text and links go into `shared.txt`; pictures and files
/// are copied beside it. The app reads the folder and removes it.
enum SharedItemWriter {
    /// The name of the file that holds shared text and links.
    static let textFileName = "shared.txt"

    /// False when there was nowhere to write to, or nothing that could be written.
    static func write(_ items: [NSExtensionItem]) async -> Bool {
        guard let inbox = inboxURL else {
            return false
        }
        let folder = inbox.appendingPathComponent(UUID().uuidString, isDirectory: true)
        guard (try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)) != nil else {
            return false
        }
        var lines: [String] = []
        var fileCount = 0
        for provider in items.flatMap({ $0.attachments ?? [] }) {
            if let line = await text(from: provider) {
                lines.append(line)
            } else if await copyFile(from: provider, into: folder, index: fileCount) {
                fileCount += 1
            }
        }
        let text = lines.joined(separator: "\n")
        if !text.isEmpty {
            try? Data(text.utf8).write(to: folder.appendingPathComponent(textFileName))
        }
        guard !text.isEmpty || fileCount > 0 else {
            try? FileManager.default.removeItem(at: folder)
            return false
        }
        return true
    }

    /// The shared folder's inbox, named by the app group in Info.plist.
    private static var inboxURL: URL? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "HearthAppGroup") as? String, !group.isEmpty else {
            return nil
        }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent("Inbox", isDirectory: true)
    }

    /// A web link or a piece of plain text, when that is what was shared. A file is not text, even a text file.
    private static func text(from provider: NSItemProvider) async -> String? {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            return nil
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
            return url.absoluteString
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
           let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
            return text
        }
        return nil
    }

    /// Copies a shared picture or file into the folder under a numbered name that keeps its kind.
    private static func copyFile(from provider: NSItemProvider, into folder: URL, index: Int) async -> Bool {
        for type in [UTType.image, .pdf, .text, .data] where provider.hasItemConformingToTypeIdentifier(type.identifier) {
            guard let data = try? await provider.loadDataRepresentation(for: type) else {
                continue
            }
            let suggested = provider.suggestedName.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
            let registered = provider.registeredContentTypes.first { $0.conforms(to: type) } ?? type
            let fileExtension = registered.preferredFilenameExtension ?? type.preferredFilenameExtension ?? "dat"
            let name = "\(index)-\(suggested ?? "shared").\(fileExtension)"
            return (try? data.write(to: folder.appendingPathComponent(name))) != nil
        }
        return false
    }
}

private extension NSItemProvider {
    /// The item's data in the given form.
    func loadDataRepresentation(for type: UTType) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            _ = loadDataRepresentation(for: type) { data, error in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown))
                }
            }
        }
    }
}
