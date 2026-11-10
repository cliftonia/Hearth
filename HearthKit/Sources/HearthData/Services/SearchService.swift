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

    /// - Parameter category: A SearXNG category such as `news`; `nil` searches the general web.
    public func search(baseURL: URL, query: String, category: String? = nil) async throws -> [SearchResultDTO] {
        var items = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "format", value: "json")]
        if let category {
            items.append(URLQueryItem(name: "categories", value: category))
        }
        let url = baseURL.appending(path: "search").appending(queryItems: items)
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        return try await session.decoded(SearchResponseDTO.self, for: request).results
    }
}
