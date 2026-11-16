import HearthDomain
import PhotosUI
import SwiftUI

/// The row at the top of the settings: the avatar and the name, leading to the profile page.
struct ProfileSection: View {
    private static let avatarDiameter: CGFloat = 44

    let presenter: SettingsPresenter
    /// Opens the page this row leads to.
    let openAction: (SettingsPageKind) -> Void

    var body: some View {
        let profile = presenter.viewModel.profile
        Section {
            SettingsLinkRow(action: { openAction(.profile) }, label: {
                HStack(spacing: HearthSpacing.s12) {
                    Avatar(photoJPEG: presenter.photoJPEG, initials: profile.initials, diameter: Self.avatarDiameter)
                    VStack(alignment: .leading, spacing: HearthSpacing.s2) {
                        Text(profile.displayName ?? Strings.profileNoName)
                            .font(.hearth(.body).weight(.medium))
                            .foregroundStyle(HearthColor.ink)
                            .lineLimit(1)
                        Text(Strings.profile)
                            .font(.hearth(.footnote))
                            .foregroundStyle(HearthColor.mute)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, HearthSpacing.s4)
            })
            .accessibilityElement(children: .combine)
        }
    }
}

/// Who the user is and how they like to be answered: the photo, the names and the instructions. What is typed is
/// kept as each field is left and as the page closes.
struct ProfilePage: View {
    private static let avatarDiameter: CGFloat = 96

    let presenter: SettingsPresenter

    @State private var pickedPhoto: PhotosPickerItem?
    @State private var isPhotoPickerPresented = false

    var body: some View {
        @Bindable var viewModel = presenter.viewModel
        SettingsPage(title: Strings.profile) {
            avatar(initials: viewModel.profile.initials)
            SettingsCard(footer: Strings.profileNamesFooter) {
                nameField(Strings.profileFullName, text: $viewModel.fullName, contentType: .name)
                Hairline()
                    .padding(.leading, HearthSpacing.s16)
                nameField(Strings.profileNickname, text: $viewModel.nickname, contentType: .nickname)
            }
            SettingsCard(header: Strings.profileInstructions, footer: Strings.profileInstructionsFooter) {
                TextField(Strings.instructionsPlaceholder, text: $viewModel.customInstructions, axis: .vertical)
                    .lineLimit(4...12)
                    .font(.hearth(.body))
                    .foregroundStyle(HearthColor.ink)
                    .padding(.horizontal, HearthSpacing.s16)
                    .padding(.vertical, HearthSpacing.s12)
                    .accessibilityLabel(Strings.profileInstructions)
                    .keepOnLeaving(presenter.keepAction)
            }
            photoError(viewModel.profileError)
        }
        .onDisappear(perform: presenter.keepAction)
        .photosPicker(isPresented: $isPhotoPickerPresented, selection: $pickedPhoto, matching: .images)
        .onChange(of: pickedPhoto) {
            guard let item = pickedPhoto else {
                return
            }
            pickedPhoto = nil
            Task { await presenter.setPhotoAction(await PhotoLoader.avatarJPEG(from: item)) }
        }
    }

    /// The avatar, with the control beneath it that chooses a photo or takes it away.
    private func avatar(initials: String) -> some View {
        let hasPhoto = presenter.photoJPEG != nil
        return VStack(spacing: HearthSpacing.s8) {
            Avatar(photoJPEG: presenter.photoJPEG, initials: initials, diameter: Self.avatarDiameter)
            Menu {
                Button(action: { isPhotoPickerPresented = true }, label: {
                    Label(Strings.profileChoosePhoto, systemImage: "photo.on.rectangle")
                })
                Button(role: .destructive, action: { Task { await presenter.removePhotoAction() } }, label: {
                    Label(Strings.profileRemovePhoto, systemImage: "trash")
                })
                .disabled(!hasPhoto)
            } label: {
                Text(Strings.profileEditPhoto)
                    .font(.hearth(.subheadline).weight(.medium))
                    .foregroundStyle(HearthColor.pine)
                    .padding(.horizontal, HearthSpacing.s12)
                    .padding(.vertical, HearthSpacing.s6)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Strings.profileEditPhoto)
        }
        .frame(maxWidth: .infinity)
    }

    /// A name under a small caption, typed without autocorrection.
    private func nameField(_ title: String, text: Binding<String>, contentType: UITextContentType) -> some View {
        VStack(alignment: .leading, spacing: HearthSpacing.s2) {
            Text(title)
                .font(.hearth(.caption))
                .foregroundStyle(HearthColor.mute)
                .accessibilityHidden(true)
            TextField(title, text: text)
                .font(.hearth(.body))
                .foregroundStyle(HearthColor.ink)
                .textContentType(contentType)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .accessibilityLabel(title)
                .keepOnLeaving(presenter.keepAction)
        }
        .padding(.horizontal, HearthSpacing.s16)
        .padding(.vertical, HearthSpacing.s10)
    }

    /// A photo that could not be kept, said beneath the cards; nothing while there is none.
    private func photoError(_ error: String?) -> some View {
        Label(error ?? "", systemImage: "exclamationmark.triangle.fill")
            .font(.hearth(.footnote))
            .foregroundStyle(HearthColor.danger)
            .padding(.horizontal, HearthSpacing.s4)
            .opacity(error == nil ? 0 : 1)
            .frame(height: error == nil ? 0 : nil)
            .accessibilityHidden(error == nil)
    }
}
