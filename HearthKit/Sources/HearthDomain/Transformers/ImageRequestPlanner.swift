import Foundation

/// Works out which kind of picture a message asks for.
///
/// Words alone ask for a new picture. A photo with words asks for that photo to be changed, unless the words ask
/// only for it to be made bigger or sharper, or there are no words at all, in which case it is enlarged.
///
/// Words that carry on from the last picture made, such as "make it photorealistic", ask for that picture to be
/// changed or enlarged, as though it had been attached.
public struct ImageRequestPlanner: Sendable {
    /// Words that ask for a picture to be made larger or sharper, not changed.
    private static let enlargeWords = [
        "4k", "8k", "upscale", "upscaling", "enlarge", "bigger", "larger", "higher resolution", "high resolution", "hi-res", "hires",
        "sharpen", "sharper", "enhance", "more detail"
    ]
    private static let wideWords = ["landscape", "wide", "widescreen", "panorama", "panoramic", "16:9", "banner", "wallpaper"]
    private static let tallWords = ["portrait orientation", "tall", "vertical", "9:16", "phone wallpaper", "poster"]

    /// How a request that carries on from the last picture begins.
    private static let followUpOpenings = [
        "make it", "make this", "make that", "make them", "make the", "now ", "change", "add ", "remove", "turn ", "put ", "replace",
        "give ", "more ", "less ", "same ", "again", "also ", "but ", "and ", "try ", "redo", "swap", "without", "with ", "in the style"
    ]
    /// Words that point back at the last picture wherever they fall.
    private static let followUpWords = [" it ", " it.", " this ", " that ", " them ", " instead", "the picture", "the image", "the photo"]

    public init() {}

    /// - Parameter previousPictureJPEG: The last picture made in the conversation, if there is one.
    public func request(text: String, imagesJPEG: [Data], previousPictureJPEG: Data? = nil) -> ImageRequest {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let image = imagesJPEG.first ?? (carriesOn(words) ? previousPictureJPEG : nil) else {
            let size = size(for: words)
            return .create(prompt: words, width: size.width, height: size.height)
        }
        if words.isEmpty || asksOnlyToEnlarge(words) {
            return .enlarge(imageJPEG: image)
        }
        return .edit(imageJPEG: image, instruction: words)
    }

    /// Whether the words read as a change to a picture already made, not as a description of a new one.
    private func carriesOn(_ words: String) -> Bool {
        let lowered = words.lowercased()
        guard !lowered.isEmpty else {
            return false
        }
        return Self.followUpOpenings.contains { lowered.hasPrefix($0) }
            || Self.followUpWords.contains { (" " + lowered + " ").contains($0) }
            || asksOnlyToEnlarge(lowered)
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
