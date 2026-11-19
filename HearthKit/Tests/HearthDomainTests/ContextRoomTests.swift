import Foundation
@testable import HearthDomain
import Testing

/// How much room in a model's memory the app asks the server for.
struct ContextRoomTests {
    private static let local = ChatModel(id: ChatModel.ID("gemma:latest"), canThink: true, canUseTools: true)
    private static let open = ModelContext(limit: 131_072, fixed: nil)

    private func request(characters: Int, model: ChatModel = local, thinking: ThinkingLevelKind = .off, images: Int = 0) -> ChatRequest {
        let message = PromptMessage(role: .user, text: String(repeating: "a", count: characters), imagesJPEG: Array(repeating: Data(), count: images))
        return ChatRequest(model: model, messages: [message], thinking: thinking)
    }

    @Test func `what a request needs counts its words, pictures, tools and the reply`() {
        let plain = ContextRoom.tokensNeeded(for: request(characters: 3000))
        let thinking = ContextRoom.tokensNeeded(for: request(characters: 3000, thinking: .medium))
        let pictured = ContextRoom.tokensNeeded(for: request(characters: 3000, images: 2))
        let searching = ContextRoom.tokensNeeded(
            for: ChatRequest(model: Self.local, messages: [PromptMessage(role: .user, text: "")], thinking: .off, isWebSearchOffered: true)
        )

        #expect(plain == 1000 + 2048)
        #expect(thinking == 1000 + 4096)
        #expect(pictured == plain + 1600)
        #expect(searching == 600 + 2048)
    }

    @Test(arguments: [(1000, 8192), (24_000, 16_384), (60_000, 32_768), (120_000, 65_536), (300_000, 131_072), (900_000, 131_072)])
    func `the smallest size that holds the chat is asked for, and never more than the largest`(characters: Int, expected: Int) {
        #expect(ContextRoom.size(for: request(characters: characters), context: Self.open) == expected)
    }

    @Test func `a size is never larger than the model can take, nor smaller than one already asked for`() {
        #expect(ContextRoom.size(for: request(characters: 100), context: ModelContext(limit: 4096, fixed: nil)) == 4096)
        #expect(ContextRoom.size(for: request(characters: 100), context: Self.open, floor: 16_384) == 16_384)
    }

    @Test func `no size is asked for a cloud model, a model with a size of its own, or one the server did not describe`() {
        let cloud = ChatModel(id: ChatModel.ID("big:cloud"), isCloud: true)

        #expect(ContextRoom.size(for: request(characters: 100, model: cloud), context: Self.open) == nil)
        #expect(ContextRoom.size(for: request(characters: 100), context: ModelContext(limit: 131_072, fixed: 65_536)) == nil)
        #expect(ContextRoom.size(for: request(characters: 100), context: ModelContext(limit: nil, fixed: nil)) == nil)
        #expect(ContextRoom.size(for: request(characters: 100), context: nil) == nil)
    }

    @Test func `a model is described once, and a short request after a long one keeps the larger size`() async throws {
        let asked = Box(0)
        let cache = ContextRoomCache { _, _ in
            asked.update { $0 += 1 }
            return Self.open
        }
        let server = try #require(URL(string: "http://server.example"))

        #expect(await cache.room(for: request(characters: 100), on: server) == 8192)
        #expect(await cache.room(for: request(characters: 24_000), on: server) == 16_384)
        #expect(await cache.room(for: request(characters: 100), on: server) == 16_384)
        #expect(asked.value == 1)
    }

    @Test func `a server that will not describe a model is asked again, and the chat goes on meanwhile`() async throws {
        struct Unreachable: Error {}
        let isReachable = Box(false)
        let cache = ContextRoomCache { _, _ in
            guard isReachable.value else {
                throw Unreachable()
            }
            return Self.open
        }
        let server = try #require(URL(string: "http://server.example"))

        #expect(await cache.room(for: request(characters: 100), on: server) == nil)
        isReachable.value = true
        #expect(await cache.room(for: request(characters: 100), on: server) == 8192)
    }
}
