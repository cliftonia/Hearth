import Foundation

/// Works out which kind of picture a message asks for.
///
/// Words alone ask for a new picture. A photo with words asks for that photo to be changed, unless the words ask
/// only for it to be made bigger or sharper, or there are no words at all, in which case it is enlarged.
///
/// Once a picture has been made in the conversation, words are taken to be about that picture, as though it had
/// been attached: "make it photorealistic", "improve the photo again", "brighter". Only words that plainly set out
/// a new picture, such as "a dog on a beach" or "draw a castle", start afresh.
public struct ImageRequestPlanner: Sendable {
    /// Words that ask for a picture to be made larger or sharper, not changed.
    private static let enlargeWords = [
        "4k", "8k", "upscale", "upscaling", "enlarge", "bigger", "larger", "higher resolution", "high resolution", "hi-res", "hires",
        "sharpen", "sharper", "enhance", "more detail"
    ]
    private static let wideWords = ["landscape", "wide", "widescreen", "panorama", "panoramic", "16:9", "banner", "wallpaper"]
    private static let tallWords = ["portrait orientation", "tall", "vertical", "9:16", "phone wallpaper", "poster"]
    /// How a request for a new picture begins, when one has already been made: with the thing itself, or with
    /// a word for making one.
    private static let freshOpenings = [
        "a ", "an ", "draw", "create", "generate", "paint ", "sketch", "photo of", "picture of", "image of", "portrait of",
        "make a ", "make an ", "make me a", "make another", "new ", "another ", "a new", "show me a", "give me a", "i want a", "i'd like a",
        "can you draw", "can you make a", "can you create", "please draw", "please make a", "please create", "now draw", "now make a",
        "next,", "next "
    ]

    public init() {}

    /// - Parameter previousPictureJPEG: The last picture made in the conversation, if there is one.
    /// - Parameter previousPictureJPEG: The last picture made in the conversation, if there is one.
    public func request(text: String, imagesJPEG: [Data], previousPictureJPEG: Data? = nil) -> ImageRequest {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let image = imagesJPEG.first ?? (startsAfresh(words) ? nil : previousPictureJPEG) else {
            let size = size(for: words)
            return .create(prompt: words, width: size.width, height: size.height)
        }
        if words.isEmpty || asksOnlyToEnlarge(words) {
            return .enlarge(imageJPEG: image)
        }
        return .edit(imageJPEG: image, instruction: words)
    }

    /// Whether the words set out a new picture, and are not about one already made. No words at all cannot be
    /// about the last picture either: that is a message with nothing to act on it.
    private func startsAfresh(_ words: String) -> Bool {
        let lowered = words.lowercased()
        return lowered.isEmpty || Self.freshOpenings.contains { lowered.hasPrefix($0) }
    }

    /// A short request that names enlarging is taken at its word; a long one is more likely a change that mentions quality.
    private func asksOnlyToEnlarge(_ words: String) -> Bool {
        let lowered = words.lowercased()
        return lowered.split(separator: " ").count <= 8 && Self.enlargeWords.contains { lowered.contains($0) }
    }

    /// About a megapixel in every shape, which is what the models are made for.
    private func size(for words: String) -> (width: Int, height: Int) {
        let lowered = words.lowercased()
        if Self.tallWords.contains(where: { lowered.contains($0) }) {
            return (832, 1216)
        }
        if Self.wideWords.contains(where: { lowered.contains($0) }) {
            return (1216, 832)
        }
        return (1024, 1024)
    }
}
