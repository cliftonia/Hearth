import Foundation

/// What the server says of how much one model can read at once.
public struct ModelContext: Sendable, Equatable {
    /// The most tokens the model itself can take in; `nil` when the server does not say.
    public let limit: Int?
    /// The size the model's own settings fix on the server, when whoever made it chose one.
    public let fixed: Int?

    public init(limit: Int?, fixed: Int?) {
        self.limit = limit
        self.fixed = fixed
    }
}

/// How much room a conversation needs in a model's memory, and how much to ask the server for.
///
/// Left to itself, a server with an ordinary graphics card gives a model room for about 4,000 tokens and quietly
/// drops whatever does not fit, the start of the conversation first. A chat that has searched the web or run long
/// is past that within a few turns, and the model answers without having read all of it. So the app works out what
/// a request needs and asks for a size that holds it.
public enum ContextRoom {
    /// The sizes asked for, up to 128k. Each change of size makes the server load the model afresh, so there are few
    /// of them and the smallest already holds most chats. A larger size costs the server memory and speed, so a chat
    /// is given a large one only once it has grown to need it.
    public static let sizes = [8192, 16_384, 32_768, 65_536, 131_072]

    /// Roughly how many characters of English make one token. Kept low, so that the estimate errs on the large side.
    static let charactersPerToken = 3
    /// What one picture costs a model that can see, as near as makes no difference.
    static let tokensPerImage = 800
    /// What the description of the tools costs when any are offered.
    static let tokensForTools = 600
    /// Room left for the reply itself, and more of it for a model that thinks first.
    static let tokensForReply = 2048
    static let tokensForThinkingReply = 4096

    /// Roughly how many tokens the request will take up, its reply included.
    public static func tokensNeeded(for request: ChatRequest) -> Int {
        let characters = request.messages.reduce(0) { $0 + $1.text.count }
        let images = request.messages.reduce(0) { $0 + $1.imagesJPEG.count }
        let isOfferingTools = request.model.canUseTools && (request.isWebSearchOffered || request.isMemoryOffered)
        let isThinking = request.model.canThink && request.thinking != .off
        return characters / charactersPerToken
            + images * tokensPerImage
            + (isOfferingTools ? tokensForTools : 0)
            + (isThinking ? tokensForThinkingReply : tokensForReply)
    }

    /// The size to ask the server for, or `nil` to ask for none.
    ///
    /// None is asked for a cloud model, which always has its full size; for a model whose own settings fix a size,
    /// which is someone's choice to respect; or when the server said nothing about the model. Otherwise it is the
    /// smallest of `sizes` that holds what is needed, never smaller than `floor` and never larger than the model
    /// can take.
    public static func size(for request: ChatRequest, context: ModelContext?, floor: Int = 0) -> Int? {
        guard !request.model.isCloud, let context, context.fixed == nil, let limit = context.limit else {
            return nil
        }
        let needed = max(tokensNeeded(for: request), floor)
        let size = sizes.first { $0 >= needed } ?? sizes[sizes.count - 1]
        return min(size, limit)
    }
}

/// Remembers what the server said of each model, and the largest size asked for it so far.
///
/// A size once asked for a model is asked for again by every later request to it, the short side requests for a
/// title or for follow-up questions included: the server loads a model afresh whenever the size changes, and a
/// chat would otherwise wait for that after every reply.
actor ContextRoomCache {
    private struct Key: Hashable {
        let server: URL
        let model: ChatModel.ID
    }

    private let describe: @Sendable (URL, ChatModel.ID) async throws -> ModelContext
    private var contexts: [Key: ModelContext] = [:]
    private var largest: [Key: Int] = [:]

    init(describe: @escaping @Sendable (URL, ChatModel.ID) async throws -> ModelContext) {
        self.describe = describe
    }

    /// The size to ask for with this request; `nil` to ask for none.
    func room(for request: ChatRequest, on server: URL) async -> Int? {
        guard !request.model.isCloud else {
            return nil
        }
        let key = Key(server: server, model: request.model.id)
        if contexts[key] == nil {
            // A server that will not describe the model is asked again with the next request; the chat goes on
            // meanwhile at the server's own size.
            contexts[key] = try? await describe(server, request.model.id)
        }
        guard let size = ContextRoom.size(for: request, context: contexts[key], floor: largest[key] ?? 0) else {
            return nil
        }
        largest[key] = size
        return size
    }
}
