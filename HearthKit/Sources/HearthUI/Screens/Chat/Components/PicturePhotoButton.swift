import SwiftUI

/// Beside the picture chip while a picture is being asked for: adds a photo for the picture server to change, so
/// that it is plain a photo can be changed and there is no need to go back to the plus button for one.
struct PicturePhotoButton: View {
    let presenter: ChatPresenter

    @State private var isPickerPresented = false

    var body: some View {
        Button(action: { isPickerPresented = true }, label: {
            OptionChip(systemImage: "photo.badge.plus", isOn: false)
        })
        .buttonStyle(.plain)
        .accessibilityLabel(Strings.picturePhoto)
        .largeContentLabel(Strings.picturePhoto, systemImage: "photo.badge.plus")
        .photoAttaching(isPresented: $isPickerPresented, presenter: presenter)
    }
}
