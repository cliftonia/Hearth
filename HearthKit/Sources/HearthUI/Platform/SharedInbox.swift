import Foundation
import HearthDomain

/// What was handed to the app from the share sheet.
struct SharedContent: Sendable {
    var text = ""
    var imagesJPEG: [Data] = []
    var documents: [AttachedDocument] = []
    /// Files that were shared but could not be read.
    var unreadableCount = 0

    var isEmpty: Bool {
        text.isEmpty && imagesJPEG.isEmpty && documents.isEmpty && unreadableCount == 0
    }
}

/// The folder where the share extension leaves things for the app. Each share is a folder of its own:
/// `shared.txt` holds text and links, and pictures and files sit beside it.
enum SharedInbox {
    private static let textFileName = "shared.txt"
    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff", "bmp"]

    /// Reads everything waiting in the inbox, oldest first, and empties it.
    static func take(from inbox: URL) async -> SharedContent {
        let manager = FileManager.default
        let keys: [URLResourceKey] = [.creationDateKey]
        let folders = (try? manager.contentsOfDirectory(at: inbox, includingPropertiesForKeys: keys)) ?? []
        let ordered = folders.sorted { created($0) < created($1) }
        var content = SharedContent()
        for folder in ordered {
            let files = ((try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            await read(files, into: &content)
            try? manager.removeItem(at: folder)
        }
        return content
    }

    private static func read(_ files: [URL], into content: inout SharedContent) async {
        for file in files {
            if file.lastPathComponent == textFileName {
                let text = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
                content.text = [content.text, text].filter { !$0.isEmpty }.joined(separator: "\n")
            } else if imageExtensions.contains(file.pathExtension.lowercased()) {
                if let data = try? Data(contentsOf: file), let jpeg = PhotoLoader.downscaledJPEG(from: data) {
                    content.imagesJPEG.append(jpeg)
                } else {
                    content.unreadableCount += 1
                }
            } else {
                let documents = await DocumentLoader.documents(from: [file])
                content.documents.append(contentsOf: documents)
                content.unreadableCount += documents.isEmpty ? 1 : 0
            }
        }
    }

    private static func created(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
    }
}
