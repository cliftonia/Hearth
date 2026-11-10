import Foundation

public struct SearchResponseDTO: Decodable, Sendable {
    public let results: [SearchResultDTO]
}

public struct SearchResultDTO: Decodable, Sendable, Equatable {
    public let title: String?
    public let url: String?
    public let content: String?
}

/// Queries a SearXNG instance through its JSON format.
public struct SearchService: Sendable {
    private let session: URLSession

    public init(session: URLSession = .hearth) {
        self.session = session
    }

    public func search(baseURL: URL, query: String) async throws -> [SearchResultDTO] {
        let url = baseURL.appending(path: "search").appending(queryItems: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "json")
        ])
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        return try await session.decoded(SearchResponseDTO.self, for: request).results
    }
}
