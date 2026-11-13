import Foundation
import HearthData

/// How the domain has pictures made.
public struct ImageDataProvider: Sendable {
    /// What the picture server at the address can do.
    public let fetchCapabilities: @Sendable (URL) async throws -> ImageCapabilities
    /// What `render` is given to report progress through.
    public typealias ProgressHandler = @Sendable (ImageProgress) -> Void

    /// Server, request and model in; the picture out, as PNG data. Progress is reported as it is learned.
    public let render: @Sendable (URL, ImageRequest, ImageModelKind, @escaping ProgressHandler) async throws -> Data
    /// Tells the picture server to give back the memory it used.
    public let free: @Sendable (URL) async -> Void
    /// Tells the chat server at the address to unload its models, making room for a picture.
    public let unloadChatModels: @Sendable (URL) async -> Void

    public init(
        fetchCapabilities: @escaping @Sendable (URL) async throws -> ImageCapabilities,
        render: @escaping @Sendable (URL, ImageRequest, ImageModelKind, @escaping ProgressHandler) async throws -> Data,
        free: @escaping @Sendable (URL) async -> Void = { _ in },
        unloadChatModels: @escaping @Sendable (URL) async -> Void = { _ in }
    ) {
        self.fetchCapabilities = fetchCapabilities
        self.render = render
        self.free = free
        self.unloadChatModels = unloadChatModels
    }
}

public extension ImageDataProvider {
    /// The size, in megapixels, a picture is enlarged to: that of a 4K screen.
    private static let enlargedMegapixels = 8.3

    /// Backed by a ComfyUI server for pictures and an Ollama server for chat.
    static func live(service: ImageService = ImageService(), ollama: OllamaService = OllamaService()) -> ImageDataProvider {
        ImageDataProvider(
            fetchCapabilities: { baseURL in
                let files = try await service.fetchFiles(baseURL: baseURL)
                return ImageCapabilities(
                    models: ImageModelKind.allCases.filter { files.engines.contains($0.engine) },
                    canEdit: files.canEdit,
                    canEnlarge: files.canEnlarge
                )
            },
            render: { baseURL, request, model, onProgress in
                do {
                    return try await service.render(baseURL: baseURL, job: job(for: request, model: model)) { progress in
                        switch progress {
                        case .waiting(let ahead):
                            onProgress(.waiting(ahead: ahead))
                        case .working:
                            onProgress(.working)
                        }
                    }
                } catch ImageServiceError.failed(let message) {
                    throw ImageError.failed(message: message)
                } catch ImageServiceError.noPicture {
                    throw ImageError.failed(message: "")
                } catch ImageServiceError.timedOut {
                    throw ImageError.timedOut
                }
            },
            free: { baseURL in
                await service.free(baseURL: baseURL)
            },
            unloadChatModels: { baseURL in
                // If the chat server cannot be asked, the picture is still tried; it may only be slower.
                try? await ollama.unloadModels(baseURL: baseURL)
            }
        )
    }

    private static func job(for request: ImageRequest, model: ImageModelKind) -> ImageJobDTO {
        switch request {
        case .create(let prompt, let width, let height):
            .create(engine: model.engine, prompt: prompt, width: width, height: height)
        case .edit(let imageJPEG, let instruction):
            .edit(image: imageJPEG, instruction: instruction)
        case .enlarge(let imageJPEG):
            .enlarge(image: imageJPEG, megapixels: enlargedMegapixels)
        }
    }
}

private extension ImageModelKind {
    /// The same model as the data layer names it.
    var engine: ImageEngineDTO {
        switch self {
        case .zImageTurbo:
            .zImageTurbo
        case .krea2Turbo:
            .krea2Turbo
        case .juggernautXL:
            .juggernautXL
        }
    }
}
