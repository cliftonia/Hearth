import Foundation
import HearthDomain
import PDFKit

/// Reads the text out of picked files: PDFs through PDFKit, anything else as plain text.
enum DocumentLoader {
    /// Files that cannot be read, or hold no text, are left out of the result.
    static func documents(from urls: [URL]) async -> [AttachedDocument] {
        urls.compactMap { url in
            guard let text = text(at: url)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                return nil
            }
            return AttachedDocument(name: url.lastPathComponent, text: text)
        }
    }

    private static func text(at url: URL) -> String? {
        // Files chosen from outside the app's own folder are only readable inside this access window.
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        if url.pathExtension.lowercased() == "pdf" {
            return PDFDocument(url: url)?.string
        }
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return String(bytes: data, encoding: .utf8) ?? String(bytes: data, encoding: .isoLatin1)
    }
}
