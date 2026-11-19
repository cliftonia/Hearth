import Foundation

/// The picture models the app can ask for, in the order they are offered.
public enum ImageModelKind: String, Codable, Sendable, CaseIterable {
    /// Quick and good at most things.
    case zImageTurbo
    /// The most photographic, and the slowest; the one used until another is chosen.
    case krea2Turbo
    /// An older, painterly model.
    case juggernautXL

    /// The model used where none has been chosen: Krea 2 Turbo if the server offers it, otherwise the first it offers.
    public static func preferred(among models: [ImageModelKind]) -> ImageModelKind? {
        models.contains(.krea2Turbo) ? .krea2Turbo : models.first
    }

    /// The model a new picture is made with: the chosen one if the server offers it, otherwise the preferred one of
    /// those it does; `nil` when it offers none.
    public static func resolved(chosen: ImageModelKind?, among models: [ImageModelKind]) -> ImageModelKind? {
        chosen.flatMap { models.contains($0) ? $0 : nil } ?? preferred(among: models)
    }
}

/// What the picture server can do.
public struct ImageCapabilities: Hashable, Sendable {
    /// The models it can make a picture with.
    public let models: [ImageModelKind]
    /// Whether it can change a picture it is shown.
    public let canEdit: Bool
    /// Whether it can make a picture larger.
    public let canEnlarge: Bool

    public init(models: [ImageModelKind] = [], canEdit: Bool = false, canEnlarge: Bool = false) {
        self.models = models
        self.canEdit = canEdit
        self.canEnlarge = canEnlarge
    }
}

/// A picture the user asked for.
public enum ImageRequest: Hashable, Sendable {
    /// A new picture from a description, at the given size in pixels.
    case create(prompt: String, width: Int, height: Int)
    /// The picture changed as the instruction asks.
    case edit(imageJPEG: Data, instruction: String)
    /// The picture made larger and sharper.
    case enlarge(imageJPEG: Data)
}

/// How a picture stands while it is being made.
public enum ImageProgress: Hashable, Sendable {
    /// The picture server is busy; this many jobs come first.
    case waiting(ahead: Int)
    /// The picture is being made now.
    case working
}

/// Why a picture could not be made.
public enum ImageError: Error, Sendable, Equatable {
    /// No usable address has been given for the picture server.
    case serverNotConfigured
    /// The server has none of the models the app can make a picture with.
    case noModel
    /// The server lacks what it needs to change a picture.
    case cannotEdit
    /// The server lacks what it needs to enlarge a picture.
    case cannotEnlarge
    /// The server tried and failed; the message is its own.
    case failed(message: String)
    case timedOut
}
