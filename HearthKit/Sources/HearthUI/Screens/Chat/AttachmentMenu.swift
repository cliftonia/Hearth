import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// The plus button: photos from the library or the camera for models that can see, and files for any model.
struct AttachmentMenu: View {
    let presenter: ChatPresenter

    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var isPhotoPickerPresented = false
    @State private var isCameraPresented = false
    @State private var isFileImporterPresented = false

    var body: some View {
        let canSee = presenter.viewModel.selectedModel?.canSee == true
        Menu {
            Button(action: { isFileImporterPresented = true }, label: {
                Label(Strings.chooseFile, systemImage: "doc")
            })
            if CameraPicker.isAvailable {
                Button(action: { isCameraPresented = true }, label: {
                    Label(Strings.takePhoto, systemImage: "camera")
                })
                .disabled(!canSee)
            }
            Button(action: { isPhotoPickerPresented = true }, label: {
                Label(Strings.photoLibrary, systemImage: "photo.on.rectangle")
            })
            .disabled(!canSee)
        } label: {
            Image(systemName: "plus")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(HearthColor.mute)
                .frame(width: 34, height: 32)
                .overlay { Capsule().strokeBorder(HearthColor.line, lineWidth: 1) }
        }
        .accessibilityLabel(Strings.attach)
        .photosPicker(isPresented: $isPhotoPickerPresented, selection: $pickedItems, maxSelectionCount: 4, matching: .images)
        .onChange(of: pickedItems) {
            let items = pickedItems
            guard !items.isEmpty else {
                return
            }
            pickedItems = []
            Task { presenter.addImagesAction(await PhotoLoader.jpegData(from: items)) }
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraPicker { imageData in
                presenter.addImagesAction([imageData])
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.pdf, .text], allowsMultipleSelection: true) { result in
            // Cancelling the picker reports a failure; there is nothing to attach either way.
            let urls = (try? result.get()) ?? []
            Task {
                let documents = await DocumentLoader.documents(from: urls)
                presenter.addDocumentsAction(documents, unreadableCount: urls.count - documents.count)
            }
        }
    }
}
