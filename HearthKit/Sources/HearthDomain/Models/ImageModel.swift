import Foundation

/// The picture models the app can ask for, in the order they are offered.
public enum ImageModelKind: String, Codable, Sendable, CaseIterable {
    /// Quick and good at most things; the one to start with.
    case zImageTurbo
    /// The most photographic, and the slowest.
    case krea2Turbo
    /// An older, painterly model.
    case juggernautXL
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
