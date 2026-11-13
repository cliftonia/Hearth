import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// The plus button: photos from the library or the camera for models that can see, files for any model,
/// and the switch that makes the next message ask for a picture.
struct AttachmentMenu: View {
    private static let maximumPhotoCount = 4

    let presenter: ChatPresenter

    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var isPhotoPickerPresented = false
    @State private var isCameraPresented = false
    @State private var isFileImporterPresented = false

    var body: some View {
        let isPictureMode = presenter.viewModel.isPictureMode
        // A photo can be shown to a model that sees, or handed to the picture server to change or enlarge.
        let canSee = presenter.viewModel.selectedModel?.canSee == true || isPictureMode
        Menu {
            if presenter.isPictureAvailable {
                Button(action: presenter.togglePictureModeAction) {
                    Label(Strings.pictureMode, systemImage: isPictureMode ? "checkmark" : "paintbrush")
                }
                .accessibilityAddTraits(isPictureMode ? .isSelected : [])
            }
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
                .frame(size: HearthSize.composerControl)
                .capsuleOutline()
        }
        .accessibilityLabel(Strings.attach)
        .photosPicker(isPresented: $isPhotoPickerPresented, selection: $pickedItems, maxSelectionCount: Self.maximumPhotoCount, matching: .images)
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
