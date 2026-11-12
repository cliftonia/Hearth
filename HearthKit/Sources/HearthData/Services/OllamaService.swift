import Foundation

/// Talks to an Ollama server: lists its models and runs chats.
public struct OllamaService: Sendable {
    private let session: URLSession

    public init(session: URLSession = .hearth) {
        self.session = session
    }

    /// Every model the server has, whether or not it can hold a conversation.
    public func fetchModels(baseURL: URL) async throws -> [OllamaModelDTO] {
        var request = URLRequest(url: baseURL.appending(path: "api/tags"))
        request.timeoutInterval = 15
        return try await session.decoded(OllamaTagsDTO.self, for: request).models
    }

    /// A single, non-streamed reply.
    public func chat(baseURL: URL, request: OllamaChatRequestDTO) async throws -> OllamaChatChunkDTO {
        let urlRequest = try URLRequest.jsonPost(url: baseURL.appending(path: "api/chat"), body: request)
        let chunk = try await session.decoded(OllamaChatChunkDTO.self, for: urlRequest)
        if let message = chunk.error {
            throw HTTPError.server(message: message)
        }
        return chunk
    }

    /// The reply as it is written, one chunk per streamed line.
    public func streamChat(baseURL: URL, request: OllamaChatRequestDTO) -> AsyncThrowingStream<OllamaChatChunkDTO, any Error> {
        let session = session
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let urlRequest = try URLRequest.jsonPost(url: baseURL.appending(path: "api/chat"), body: request)
                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    guard let http = response as? HTTPURLResponse else {
                        throw HTTPError.invalidResponse
                    }
                    for try await line in bytes.lines where !line.isEmpty {
                        guard (200..<300).contains(http.statusCode) else {
                            throw Self.failure(statusCode: http.statusCode, line: line)
                        }
                        let chunk = try OllamaChatChunkDTO(line: line)
                        if let message = chunk.error {
                            throw HTTPError.server(message: message)
                        }
                        continuation.yield(chunk)
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        throw HTTPError.status(code: http.statusCode, body: "")
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// The error for a line of a failed response: the server's own message when the line carries one, otherwise the status.
    private static func failure(statusCode: Int, line: String) -> HTTPError {
        if let message = (try? OllamaChatChunkDTO(line: line))?.error {
            return .server(message: message)
        }
        return .status(code: statusCode, body: String(line.prefix(500)))
    }
}
