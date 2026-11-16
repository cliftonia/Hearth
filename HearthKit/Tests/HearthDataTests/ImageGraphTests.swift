@testable import HearthData
import Testing

/// How the node graphs ComfyUI runs are put together.
struct ImageGraphTests {
    /// The kind of the numbered node.
    private func kind(_ id: String, in nodes: ImageGraph.Nodes) -> String? {
        nodes[id]?["class_type"] as? String
    }

    /// One input of the numbered node.
    private func input(_ name: String, of id: String, in nodes: ImageGraph.Nodes) -> Any? {
        (nodes[id]?["inputs"] as? [String: Any])?[name]
    }

    /// Where an input that comes from another node is taken from.
    private func link(_ name: String, of id: String, in nodes: ImageGraph.Nodes) -> String? {
        guard let link = input(name, of: id, in: nodes) as? [Any], let from = link.first as? String, let slot = link.last as? Int else {
            return nil
        }
        return "\(from):\(slot)"
    }

    @Test(arguments: ImageEngineDTO.allCases)
    func `a new picture is sampled from the words and ends in a preview`(engine: ImageEngineDTO) {
        let nodes = ImageGraph.create(engine: engine, prompt: "a lighthouse", width: 1024, height: 768, seed: 7)

        #expect(input("text", of: "2", in: nodes) as? String == "a lighthouse")
        #expect(kind("5", in: nodes) == "KSampler")
        #expect(input("seed", of: "5", in: nodes) as? Int == 7)
        #expect(link("positive", of: "5", in: nodes) == "2:0")
        #expect(input("width", of: "4", in: nodes) as? Int == 1024)
        #expect(input("height", of: "4", in: nodes) as? Int == 768)
        #expect(kind("7", in: nodes) == "PreviewImage")
        #expect(link("images", of: "7", in: nodes) == "6:0")
        #expect(!nodes.values.contains { $0["class_type"] as? String == "SaveImage" })
    }

    @Test func `the classic model loads one checkpoint and is steered away from clutter`() {
        let nodes = ImageGraph.create(engine: .juggernautXL, prompt: "a lighthouse", width: 1024, height: 1024, seed: 1)

        #expect(kind("10", in: nodes) == "CheckpointLoaderSimple")
        #expect(input("ckpt_name", of: "10", in: nodes) as? String == ImageEngineDTO.juggernautXL.modelFile)
        #expect(link("clip", of: "2", in: nodes) == "10:1")
        #expect(kind("3", in: nodes) == "CLIPTextEncode")
        #expect(input("steps", of: "5", in: nodes) as? Int == 30)
    }

    @Test func `the fast models load their own parts and take no guidance`() {
        let nodes = ImageGraph.create(engine: .zImageTurbo, prompt: "a lighthouse", width: 1024, height: 1024, seed: 1)

        #expect(input("unet_name", of: "10", in: nodes) as? String == ImageEngineDTO.zImageTurbo.modelFile)
        #expect(kind("3", in: nodes) == "ConditioningZeroOut")
        #expect(link("model", of: "5", in: nodes) == "13:0")
        #expect(input("steps", of: "5", in: nodes) as? Int == 8)
    }

    @Test func `a change is made to the uploaded picture as instructed`() {
        let nodes = ImageGraph.edit(imageName: "photo.png", instruction: "make it night", seed: 3)

        #expect(input("image", of: "1", in: nodes) as? String == "photo.png")
        #expect(input("text", of: "20", in: nodes) as? String == "make it night")
        #expect(input("unet_name", of: "10", in: nodes) as? String == ImageToolFile.editModel)
        #expect(input("noise_seed", of: "33", in: nodes) as? Int == 3)
        #expect(kind("37", in: nodes) == "PreviewImage")
        #expect(link("images", of: "37", in: nodes) == "36:0")
    }

    @Test func `an enlargement upscales the uploaded picture, then brings it to the asked size`() {
        let nodes = ImageGraph.enlarge(imageName: "photo.png", megapixels: 8)

        #expect(input("image", of: "1", in: nodes) as? String == "photo.png")
        #expect(input("model_name", of: "2", in: nodes) as? String == ImageToolFile.enlargeModel)
        #expect(link("image", of: "4", in: nodes) == "3:0")
        #expect(input("megapixels", of: "4", in: nodes) as? Double == 8)
        #expect(kind("5", in: nodes) == "PreviewImage")
    }
}
