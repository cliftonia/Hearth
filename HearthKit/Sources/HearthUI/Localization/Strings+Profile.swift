import Foundation

// The profile page: the avatar, the names, the instructions, and erasing everything.
// swiftlint:disable line_length
extension Strings {
    static let profile = String(localized: "profile.title", defaultValue: "Profile", bundle: .module)
    static let profileNoName = String(localized: "profile.noName", defaultValue: "Add your name", bundle: .module)
    static let profileEditPhoto = String(localized: "profile.editPhoto", defaultValue: "Edit photo", bundle: .module)
    static let profileChoosePhoto = String(localized: "profile.choosePhoto", defaultValue: "Choose from library", bundle: .module)
    static let profileRemovePhoto = String(localized: "profile.removePhoto", defaultValue: "Remove photo", bundle: .module)
    static let profilePhotoFailed = String(localized: "profile.photoFailed", defaultValue: "The photo could not be saved.", bundle: .module)
    static let profileFullName = String(localized: "profile.fullName", defaultValue: "Full name", bundle: .module)
    static let profileNickname = String(localized: "profile.nickname", defaultValue: "Nickname", bundle: .module)
    static let profileNamesFooter = String(localized: "profile.namesFooter", defaultValue: "Hearth calls you by your nickname.", bundle: .module)
    static let profileInstructions = String(localized: "profile.instructions", defaultValue: "Instructions", bundle: .module)
    static let profileInstructionsFooter = String(localized: "profile.instructionsFooter", defaultValue: "Instructions apply to every conversation.", bundle: .module)
    static let followUpsFooter = String(localized: "profile.followUpsFooter", defaultValue: "Suggestions cost one extra short request per reply.", bundle: .module)
    static let eraseAll = String(localized: "profile.eraseAll", defaultValue: "Erase all data on this device", bundle: .module)
    static let eraseAllFooter = String(localized: "profile.eraseAllFooter", defaultValue: "This removes everything Hearth keeps on this device and turns sync off. Your hub and your other devices keep their copies; nothing is deleted there.", bundle: .module)
    static let eraseAllQuestion = String(localized: "profile.eraseAllQuestion", defaultValue: "Erase all data on this device?", bundle: .module)
    static let eraseAllMessage = String(localized: "profile.eraseAllMessage", defaultValue: "Your chats, projects, memories, profile and saved settings will be erased from this device, server addresses and sync included. Hearth will be as it was when first opened. Your hub and other devices are not changed. This cannot be undone.", bundle: .module)
    static let eraseAllConfirm = String(localized: "profile.eraseAllConfirm", defaultValue: "Erase everything", bundle: .module)
    static let eraseAllFailed = String(localized: "profile.eraseAllFailed", defaultValue: "Not everything could be erased. Try again.", bundle: .module)
}
// swiftlint:enable line_length
