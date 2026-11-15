import Foundation

/// Who the user is, as far as they have said: their name in full and what they like to be called.
public struct UserProfile: Hashable, Sendable {
    public let fullName: String
    public let nickname: String

    public init(fullName: String = "", nickname: String = "") {
        self.fullName = Self.singleLine(fullName)
        self.nickname = Self.singleLine(nickname)
    }

    /// Whether neither name has been given.
    public var isEmpty: Bool { fullName.isEmpty && nickname.isEmpty }

    /// What to call the user: the nickname, or failing that the first word of the full name. `nil` when neither is given.
    public var preferredName: String? {
        if !nickname.isEmpty {
            return nickname
        }
        return fullName.split(separator: " ").first.map(String.init)
    }

    /// The name to show beside the avatar: the full name, or failing that the nickname. `nil` when neither is given.
    public var displayName: String? {
        [fullName, nickname].first { !$0.isEmpty }
    }

    /// Up to two letters for the avatar: the first of the first and last words of the full name, or of the
    /// nickname when there is no full name. Empty when neither is given.
    public var initials: String {
        let words = (fullName.isEmpty ? nickname : fullName).split(separator: " ")
        let letters = words.count > 1 ? [words.first, words.last] : [words.first]
        return letters.compactMap { $0?.first }.map { String($0).uppercased() }.joined()
    }

    /// A name trimmed and on one line, so that it reads as a name wherever it is put.
    private static func singleLine(_ name: String) -> String {
        name.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }
}
