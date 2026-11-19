import PhotosUI
import SwiftUI

/// Opens the system's photo picker and adds what is picked to the message being written.
private struct PhotoAttaching: ViewModifier {
    /// The most photos added at once.
    private static let maximumPhotoCount = 4

    @Binding var isPresented: Bool
    let presenter: ChatPresenter

    @State private var pickedItems: [PhotosPickerItem] = []

    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: $isPresented, selection: $pickedItems, maxSelectionCount: Self.maximumPhotoCount, matching: .images)
            .onChange(of: pickedItems) {
                let items = pickedItems
                guard !items.isEmpty else {
                    return
                }
                pickedItems = []
                Task { presenter.addImagesAction(await PhotoLoader.jpegData(from: items)) }
            }
    }
}

extension View {
    /// Shows the photo picker while `isPresented` is set, and adds the photos picked to the presenter's message.
    func photoAttaching(isPresented: Binding<Bool>, presenter: ChatPresenter) -> some View {
        modifier(PhotoAttaching(isPresented: isPresented, presenter: presenter))
    }
}
