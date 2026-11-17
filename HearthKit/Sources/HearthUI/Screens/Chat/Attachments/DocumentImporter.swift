import HearthDomain
import SwiftUI
import UniformTypeIdentifiers

extension View {
    /// Presents the system's file picker for PDFs and text files, several at a time, and hands back the text read
    /// from those it could read, with the number it could not.
    ///
    /// - Parameter importAction: Given the files read and how many of those picked could not be read.
    func documentImporter(
        isPresented: Binding<Bool>,
        importAction: @escaping @MainActor ([AttachedDocument], _ unreadableCount: Int) -> Void
    ) -> some View {
        fileImporter(isPresented: isPresented, allowedContentTypes: [.pdf, .text], allowsMultipleSelection: true) { result in
            // Cancelling the picker reports a failure; there is nothing to read either way.
            let urls = (try? result.get()) ?? []
            Task {
                let documents = await DocumentLoader.documents(from: urls)
                importAction(documents, urls.count - documents.count)
            }
        }
    }
}
