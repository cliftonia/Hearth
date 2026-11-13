import Foundation
@testable import HearthDomain
import Testing

/// How a message is read as a request for a picture, and how the servers' memory is kept clear around making one.
struct ImageTests {
    private let photo = Data([1, 2, 3])
    private let settings = ServerSettings(ollamaAddress: "https://ollama.example", imageAddress: "http://pictures.example:8188")

    @Test func `words alone ask for a new picture, square unless they say otherwise`() {
        let planner = ImageRequestPlanner()

        #expect(planner.request(text: " a red fox ", imagesJPEG: []) == .create(prompt: "a red fox", width: 1024, height: 1024))
        #expect(planner.request(text: "a wide landscape of hills", imagesJPEG: []) == .create(prompt: "a wide landscape of hills", width: 1216, height: 832))
        #expect(planner.request(text: "a tall poster of a ship", imagesJPEG: []) == .create(prompt: "a tall poster of a ship", width: 832, height: 1216))
    }

    @Test(arguments: ["", "make this image 4k", "Upscale it", "enhance this photo", "higher resolution please"])
    func `a photo with no words, or with words that only ask for size, is enlarged`(text: String) {
        #expect(ImageRequestPlanner().request(text: text, imagesJPEG: [photo]) == .enlarge(imageJPEG: photo))
    }

    @Test func `a photo with any other words is changed as they ask`() {
        let planner = ImageRequestPlanner()
        let instruction = "Make the people in this picture look like they live in the 1800s"

        #expect(planner.request(text: instruction, imagesJPEG: [photo]) == .edit(imageJPEG: photo, instruction: instruction))
        // A long request that happens to mention quality is still a change.
        let long = "Put the dog on a beach at sunset with palm trees behind it and make it sharper too"
        #expect(planner.request(text: long, imagesJPEG: [photo]) == .edit(imageJPEG: photo, instruction: long))
    }

    @Test(arguments: ["Make it photo realistic", "now at night", "add a red hat", "Change the background to a beach", "can you turn it into a painting"])
    func `words that carry on from the last picture change that picture`(text: String) {
        let request = ImageRequestPlanner().request(text: text, imagesJPEG: [], previousPictureJPEG: photo)

        #expect(request == .edit(imageJPEG: photo, instruction: text))
    }

    @Test func `the last picture is enlarged when that is all that is asked, and left alone by a fresh description`() {
        let planner = ImageRequestPlanner()

        #expect(planner.request(text: "make it 4k", imagesJPEG: [], previousPictureJPEG: photo) == .enlarge(imageJPEG: photo))
        let fresh = planner.request(text: "a dog on a beach", imagesJPEG: [], previousPictureJPEG: photo)
        #expect(fresh == .create(prompt: "a dog on a beach", width: 1024, height: 1024))
        // A photo attached now always wins over the last picture made.
        let other = Data([7])
        #expect(planner.request(text: "make it blue", imagesJPEG: [other], previousPictureJPEG: photo) == .edit(imageJPEG: other, instruction: "make it blue"))
        // With no picture yet, the same words can only describe a new one.
        #expect(planner.request(text: "make it blue", imagesJPEG: []) == .create(prompt: "make it blue", width: 1024, height: 1024))
    }

    @Test func `the chat models are unloaded before a picture and the picture server is freed after it`() async throws {
        let steps = Recorder<String>()
        let subject = ImageInteractor(provider: ImageDataProvider(
            fetchCapabilities: { _ in ImageCapabilities(models: [.krea2Turbo, .zImageTurbo], canEdit: true, canEnlarge: false) },
            render: { _, _, model in
                steps.record("render \(model.rawValue)")
                return Data([9])
            },
            free: { _ in steps.record("free") },
            unloadChatModels: { _ in steps.record("unload") }
        ))

        let picture = try await subject.make(.create(prompt: "a fox", width: 1024, height: 1024), settings: settings)

        #expect(picture == Data([9]))
        // With no model chosen, the first the server offers is used.
        #expect(steps.values == ["unload", "render krea2Turbo", "free"])
    }

    @Test func `the picture server is freed even when the picture fails, and missing tools are reported`() async {
        let steps = Recorder<String>()
        let subject = ImageInteractor(provider: ImageDataProvider(
            fetchCapabilities: { _ in ImageCapabilities(models: [.zImageTurbo], canEdit: true, canEnlarge: false) },
            render: { _, _, _ in throw ImageError.failed(message: "out of memory") },
            free: { _ in steps.record("free") }
        ))

        await #expect(throws: ImageError.failed(message: "out of memory")) {
            try await subject.make(.edit(imageJPEG: photo, instruction: "x"), settings: settings)
        }
        await #expect(throws: ImageError.cannotEnlarge) {
            try await subject.make(.enlarge(imageJPEG: photo), settings: settings)
        }
        await #expect(throws: ImageError.serverNotConfigured) {
            try await subject.make(.enlarge(imageJPEG: photo), settings: ServerSettings())
        }
        #expect(steps.values == ["free"])
    }

    @Test func `settings saved before pictures existed still load, with no picture server`() throws {
        let old = Data(#"{"ollamaAddress":"https://ollama.example","imageModel":"gone"}"#.utf8)

        let decoded = try JSONDecoder().decode(ServerSettings.self, from: old)

        #expect(decoded.imageAddress.isEmpty)
        #expect(decoded.imageModel == nil)
    }
}
