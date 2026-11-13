import Foundation

/// The picture models the app knows how to drive through ComfyUI, each with the settings its makers recommend.
public enum ImageEngineDTO: String, Sendable, CaseIterable {
    case zImageTurbo
    case krea2Turbo
    case juggernautXL

    /// The file that holds the model on the server. The engine is offered only when the server has it.
    public var modelFile: String {
        switch self {
        case .zImageTurbo:
            "z_image_turbo_int8_convrot.safetensors"
        case .krea2Turbo:
            "krea2_turbo_fp8_scaled.safetensors"
        case .juggernautXL:
            "juggernautXL_v9.safetensors"
        }
    }

    /// Whether the model comes as one file with its text reader and decoder inside.
    var isCheckpoint: Bool {
        switch self {
        case .zImageTurbo, .krea2Turbo:
            false
        case .juggernautXL:
            true
        }
    }
}

/// The files that picture editing and enlarging need on the server.
public enum ImageToolFile {
    public static let editModel = "flux-2-klein-4b.safetensors"
    public static let enlargeModel = "RealESRGAN_x4plus.safetensors"
    static let editTextEncoder = "qwen_3_4b_fp4_flux2.safetensors"
    static let editVAE = "flux2-vae.safetensors"
}

/// Builds the node graphs ComfyUI runs. A graph is a dictionary of numbered nodes, each naming its kind and inputs;
/// an input that comes from another node is written as that node's number and output slot.
///
/// Every graph ends in a preview, not a save, so the finished picture sits in the server's temporary folder and is
/// gone when the server next restarts, instead of piling up in its output folder.
enum ImageGraph {
    typealias Nodes = [String: [String: Any]]

    /// A picture from words alone.
    static func create(engine: ImageEngineDTO, prompt: String, width: Int, height: Int, seed: Int) -> Nodes {
        var nodes: Nodes = [:]
        var model: [Any] = ["10", 0]
        var clip: [Any] = ["11", 0]
        var vae: [Any] = ["12", 0]
        var latentKind = "EmptyLatentImage"
        var sampling: [String: Any] = ["steps": 8, "cfg": 1.0, "sampler_name": "euler", "scheduler": "simple"]
        switch engine {
        case .zImageTurbo:
            nodes["10"] = node("UNETLoader", ["unet_name": engine.modelFile, "weight_dtype": "default"])
            nodes["11"] = node("CLIPLoader", ["clip_name": "qwen_3_4b_fp8_mixed.safetensors", "type": "lumina2", "device": "default"])
            nodes["12"] = node("VAELoader", ["vae_name": "ae.safetensors"])
            nodes["13"] = node("ModelSamplingAuraFlow", ["model": model, "shift": 3.0])
            model = ["13", 0]
            latentKind = "EmptySD3LatentImage"
            sampling["sampler_name"] = "res_multistep"
        case .krea2Turbo:
            nodes["10"] = node("UNETLoader", ["unet_name": engine.modelFile, "weight_dtype": "default"])
            nodes["11"] = node("CLIPLoader", ["clip_name": "qwen3vl_4b_fp8_scaled.safetensors", "type": "krea2", "device": "default"])
            nodes["12"] = node("VAELoader", ["vae_name": "qwen_image_vae.safetensors"])
            nodes["13"] = node("ModelSamplingFlux", ["model": model, "max_shift": 1.15, "base_shift": 0.5, "width": width, "height": height])
            model = ["13", 0]
        case .juggernautXL:
            nodes["10"] = node("CheckpointLoaderSimple", ["ckpt_name": engine.modelFile])
            clip = ["10", 1]
            vae = ["10", 2]
            sampling = ["steps": 30, "cfg": 6.5, "sampler_name": "dpmpp_2m", "scheduler": "karras"]
        }
        nodes["2"] = node("CLIPTextEncode", ["text": prompt, "clip": clip])
        // The fast models take no guidance, so what to avoid is left blank; the classic one is steered away from clutter.
        nodes["3"] = engine == .juggernautXL
            ? node("CLIPTextEncode", ["text": "text, watermark, low quality, deformed", "clip": clip])
            : node("ConditioningZeroOut", ["conditioning": ["2", 0]])
        nodes["4"] = node(latentKind, ["width": width, "height": height, "batch_size": 1])
        sampling.merge(["model": model, "positive": ["2", 0], "negative": ["3", 0], "latent_image": ["4", 0], "seed": seed, "denoise": 1.0]) { $1 }
        nodes["5"] = node("KSampler", sampling)
        nodes["6"] = node("VAEDecode", ["samples": ["5", 0], "vae": vae])
        nodes["7"] = node("PreviewImage", ["images": ["6", 0]])
        return nodes
    }

    /// An uploaded picture changed as the instruction asks, by FLUX.2 klein, at about a megapixel.
    static func edit(imageName: String, instruction: String, seed: Int) -> Nodes {
        var nodes: Nodes = [:]
        nodes["1"] = node("LoadImage", ["image": imageName])
        nodes["2"] = node("ImageScaleToTotalPixels", ["image": ["1", 0], "upscale_method": "lanczos", "megapixels": 1.0, "resolution_steps": 16])
        nodes["3"] = node("GetImageSize", ["image": ["2", 0]])
        nodes["10"] = node("UNETLoader", ["unet_name": ImageToolFile.editModel, "weight_dtype": "default"])
        nodes["11"] = node("CLIPLoader", ["clip_name": ImageToolFile.editTextEncoder, "type": "flux2", "device": "default"])
        nodes["12"] = node("VAELoader", ["vae_name": ImageToolFile.editVAE])
        nodes["20"] = node("CLIPTextEncode", ["text": instruction, "clip": ["11", 0]])
        nodes["21"] = node("ConditioningZeroOut", ["conditioning": ["20", 0]])
        nodes["22"] = node("VAEEncode", ["pixels": ["2", 0], "vae": ["12", 0]])
        // The picture is given to the model as a reference on both sides of its guidance.
        nodes["23"] = node("ReferenceLatent", ["conditioning": ["20", 0], "latent": ["22", 0]])
        nodes["24"] = node("ReferenceLatent", ["conditioning": ["21", 0], "latent": ["22", 0]])
        nodes["30"] = node("EmptyFlux2LatentImage", ["width": ["3", 0], "height": ["3", 1], "batch_size": 1])
        nodes["31"] = node("Flux2Scheduler", ["steps": 4, "width": ["3", 0], "height": ["3", 1]])
        nodes["32"] = node("KSamplerSelect", ["sampler_name": "euler"])
        nodes["33"] = node("RandomNoise", ["noise_seed": seed])
        nodes["34"] = node("CFGGuider", ["model": ["10", 0], "positive": ["23", 0], "negative": ["24", 0], "cfg": 1.0])
        nodes["35"] = node("SamplerCustomAdvanced", [
            "noise": ["33", 0], "guider": ["34", 0], "sampler": ["32", 0], "sigmas": ["31", 0], "latent_image": ["30", 0]
        ])
        nodes["36"] = node("VAEDecode", ["samples": ["35", 0], "vae": ["12", 0]])
        nodes["37"] = node("PreviewImage", ["images": ["36", 0]])
        return nodes
    }

    /// An uploaded picture made four times larger each way, then brought down to the asked size if that is smaller.
    static func enlarge(imageName: String, megapixels: Double) -> Nodes {
        var nodes: Nodes = [:]
        nodes["1"] = node("LoadImage", ["image": imageName])
        nodes["2"] = node("UpscaleModelLoader", ["model_name": ImageToolFile.enlargeModel])
        nodes["3"] = node("ImageUpscaleWithModel", ["upscale_model": ["2", 0], "image": ["1", 0]])
        nodes["4"] = node("ImageScaleToTotalPixels", ["image": ["3", 0], "upscale_method": "lanczos", "megapixels": megapixels, "resolution_steps": 1])
        nodes["5"] = node("PreviewImage", ["images": ["4", 0]])
        return nodes
    }

    private static func node(_ kind: String, _ inputs: [String: Any]) -> [String: Any] {
        ["class_type": kind, "inputs": inputs]
    }
}
