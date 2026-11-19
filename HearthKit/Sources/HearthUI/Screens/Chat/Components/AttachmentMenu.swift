import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// What the plus button offers.
enum AttachmentChoiceKind: Identifiable, Hashable {
    case file
    case camera
    case photoLibrary
    case pictureMode
    case readAloud
    case scheduleTask
    case newProject

    var id: Self { self }

    var title: String {
        switch self {
        case .file:
            Strings.chooseFile
        case .camera:
            Strings.takePhoto
        case .photoLibrary:
            Strings.photoLibrary
        case .pictureMode:
            Strings.pictureMode
        case .readAloud:
            Strings.readRepliesAloud
        case .scheduleTask:
            Strings.scheduleTask
        case .newProject:
            Strings.newProject
        }
    }

    var systemImage: String {
        switch self {
        case .file:
            "doc"
        case .camera:
            "camera"
        case .photoLibrary:
            "photo.on.rectangle"
        case .pictureMode:
            "paintbrush"
        case .readAloud:
            "speaker.wave.2"
        case .scheduleTask:
            "calendar.badge.clock"
        case .newProject:
            "folder.badge.plus"
        }
    }
}

/// The plus button: photos from the library or the camera for models that can see, files for any model,
/// the switches that make the next message ask for a picture and have replies read aloud, a scheduled task asking
/// what is being written, and a new project.
///
/// On a phone or a tablet it opens a sheet from the foot of the screen; on a Mac, a menu at the pointer.
struct AttachmentMenu: View {
    private static let maximumPhotoCount = 4

    let presenter: ChatPresenter

    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var isPhotoPickerPresented = false
    @State private var isCameraPresented = false
    @State private var isFileImporterPresented = false
    @State private var isSheetPresented = false
    /// What was chosen in the sheet, done once the sheet has gone: a picker cannot open while it is still closing.
    @State private var chosen: AttachmentChoiceKind?

    var body: some View {
        opener
            .fixedSize()
            .accessibilityLabel(Strings.addMenu)
            .largeContentLabel(Strings.addMenu, systemImage: "plus")
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

    // MARK: What is offered

    /// A photo can be shown to a model that sees, or handed to the picture server to change or enlarge.
    private var canSee: Bool {
        presenter.viewModel.selectedModel?.canSee == true || presenter.viewModel.isPictureMode
    }

    /// The switches: what the next message asks for, and how replies are given.
    private var switches: [AttachmentChoiceKind] {
        (presenter.isPictureAvailable ? [.pictureMode] : []) + (presenter.isSpeechAvailable ? [.readAloud] : [])
    }

    /// The things to make.
    private var makers: [AttachmentChoiceKind] { [.scheduleTask, .newProject] }

    private func isEnabled(_ choice: AttachmentChoiceKind) -> Bool {
        switch choice {
        case .camera, .photoLibrary:
            canSee
        case .file, .pictureMode, .readAloud, .scheduleTask, .newProject:
            true
        }
    }

    private func isOn(_ choice: AttachmentChoiceKind) -> Bool {
        switch choice {
        case .pictureMode:
            presenter.viewModel.isPictureMode
        case .readAloud:
            presenter.isAutoReadEnabled
        case .file, .camera, .photoLibrary, .scheduleTask, .newProject:
            false
        }
    }

    private func perform(_ choice: AttachmentChoiceKind) {
        switch choice {
        case .file:
            isFileImporterPresented = true
        case .camera:
            isCameraPresented = true
        case .photoLibrary:
            isPhotoPickerPresented = true
        case .pictureMode:
            presenter.togglePictureModeAction()
        case .readAloud:
            Task { await presenter.toggleAutoReadAction() }
        case .scheduleTask:
            presenter.scheduleTaskAction()
        case .newProject:
            presenter.newProjectAction()
        }
    }

    // MARK: The button

    private var plus: some View {
        // The label carries the button's name and keeps to its size, so VoiceOver finds one element the size of the
        // button and nothing beside it.
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

    #if targetEnvironment(macCatalyst)
    private var opener: some View {
        Menu {
            ForEach([AttachmentChoiceKind.file, .photoLibrary]) { menuButton($0) }
            Divider()
            ForEach(switches + makers) { menuButton($0) }
        } label: {
            plus
        }
        // Read top to bottom as written, with New project last, rather than turned around when the menu opens upwards.
        .menuOrder(.fixed)
    }

    private func menuButton(_ choice: AttachmentChoiceKind) -> some View {
        Button(action: { perform(choice) }, label: {
            Label(choice.title, systemImage: isOn(choice) ? "checkmark" : choice.systemImage)
        })
        .disabled(!isEnabled(choice))
        .accessibilityLabel(choice.title)
        .accessibilityAddTraits(isOn(choice) ? .isSelected : [])
    }
    #else
    private var opener: some View {
        Button(action: { isSheetPresented = true }, label: { plus })
            .buttonStyle(.plain)
            .sheet(isPresented: $isSheetPresented, onDismiss: performChosen) {
                // The photo library is a button in the sheet's heading, so the first card holds the camera and files.
                AttachmentSheet(
                    groups: [(CameraPicker.isAvailable ? [.camera] : []) + [.file], makers],
                    switches: switches,
                    isEnabled: isEnabled,
                    isOn: isOn,
                    chooseAction: { choice in
                        chosen = choice
                        isSheetPresented = false
                    },
                    toggleAction: perform
                )
            }
    }

    private func performChosen() {
        guard let choice = chosen else {
            return
        }
        chosen = nil
        perform(choice)
    }
    #endif
}
