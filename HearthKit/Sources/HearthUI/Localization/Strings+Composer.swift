import Foundation

// What the composer says about talking to it by holding it down.
extension Strings {
    static let composerReplyPlaceholder = String(localized: "composer.placeholder.reply", defaultValue: "Reply or hold to talk", bundle: .module)
    static let composerRestingPlaceholder = String(localized: "composer.placeholder.resting", defaultValue: "Type or hold to talk", bundle: .module)
    static let releaseToStop = String(localized: "composer.holdToTalk.release", defaultValue: "Release to stop", bundle: .module)
}
