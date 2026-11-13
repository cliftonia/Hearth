import Foundation

/// Has pictures made, changed and enlarged, and keeps the servers' memory clear around the work.
public final class ImageInteractor: Sendable {
    private let provider: ImageDataProvider

    public init(provider: ImageDataProvider) {
        self.provider = provider
    }

    /// What the picture server in the settings can do.
    public func capabilities(settings: ServerSettings) async throws -> ImageCapabilities {
        guard let baseURL = settings.imageURL else {
            throw ImageError.serverNotConfigured
        }
        return try await provider.fetchCapabilities(baseURL)
    }

    /// The picture as PNG data.
    ///
    /// The chat server is asked to unload its models first, since both servers share one graphics card, and the
    /// picture server is asked to free its memory afterwards, whether the picture was made or not.
    ///
    /// - Parameter onProgress: Told whether the picture is waiting behind other work or being made.
    public func make(
        _ request: ImageRequest,
        settings: ServerSettings,
        onProgress: @escaping ImageDataProvider.ProgressHandler = { _ in }
    ) async throws -> Data {
        guard let baseURL = settings.imageURL else {
            throw ImageError.serverNotConfigured
        }
        let capabilities = try await provider.fetchCapabilities(baseURL)
        let model = try model(for: request, settings: settings, capabilities: capabilities)
        if let chatURL = settings.ollamaURL {
            await provider.unloadChatModels(chatURL)
        }
        do {
            let picture = try await provider.render(baseURL, request, model, onProgress)
            await provider.free(baseURL)
            return picture
        } catch {
            // Stopping a picture cancels this task, and a cancelled task cannot make requests; freeing goes in its own.
            let free = provider.free
            await Task.detached { await free(baseURL) }.value
            throw error
        }
    }

    /// The model to use: the chosen one if the server has it, otherwise the first it offers.
    /// Changing and enlarging use tools of their own, and only need those to be there.
    private func model(for request: ImageRequest, settings: ServerSettings, capabilities: ImageCapabilities) throws -> ImageModelKind {
        switch request {
        case .create:
            let chosen = settings.imageModel.flatMap { capabilities.models.contains($0) ? $0 : nil }
            guard let model = chosen ?? capabilities.models.first else {
                throw ImageError.noModel
            }
            return model
        case .edit:
            guard capabilities.canEdit else {
                throw ImageError.cannotEdit
            }
            return settings.imageModel ?? .zImageTurbo
        case .enlarge:
            guard capabilities.canEnlarge else {
                throw ImageError.cannotEnlarge
            }
            return settings.imageModel ?? .zImageTurbo
        }
    }
}
