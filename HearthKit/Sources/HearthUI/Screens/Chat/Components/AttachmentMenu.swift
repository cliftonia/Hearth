import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// The plus button: photos from the library or the camera for models that can see, files for any model,
/// the switch that makes the next message ask for a picture, a scheduled task asking what is being written, and a
/// new project.
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
            Divider()
            if presenter.isPictureAvailable {
                Button(action: presenter.togglePictureModeAction) {
                    Label(Strings.pictureMode, systemImage: isPictureMode ? "checkmark" : "paintbrush")
                }
                .accessibilityAddTraits(isPictureMode ? .isSelected : [])
            }
            Button(action: presenter.scheduleTaskAction) {
                Label(Strings.scheduleTask, systemImage: "calendar.badge.clock")
            }
            .accessibilityLabel(Strings.scheduleTask)
            Button(action: presenter.newProjectAction) {
                Label(Strings.newProject, systemImage: "folder.badge.plus")
            }
            .accessibilityLabel(Strings.newProject)
        } label: {
            // The label carries the menu's name, and the menu keeps to its size, so VoiceOver finds one element the
            // size of the button and nothing beside it.
            Label(Strings.addMenu, systemImage: "plus")
                .labelStyle(.iconOnly)
                .font(.hearth(.footnote).weight(.semibold))
                .iconGlyphSize()
                .foregroundStyle(HearthColor.mute)
                .frame(size: HearthSize.composerControl)
                .capsuleOutline()
                .minimumHitTarget()
                .hoverHighlight(Capsule())
        }
        .fixedSize()
        .accessibilityLabel(Strings.addMenu)
        .largeContentLabel(Strings.addMenu, systemImage: "plus")
        // Read top to bottom as written, with New project last, rather than turned around when the menu opens upwards.
        .menuOrder(.fixed)
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
        .documentImporter(isPresented: $isFileImporterPresented) { documents, unreadableCount in
            presenter.addDocumentsAction(documents, unreadableCount: unreadableCount)
        }
    }
}
