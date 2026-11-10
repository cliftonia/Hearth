import Foundation
import HearthData

/// Which part of the web a search covers.
public enum SearchKind: Sendable, Equatable {
    case general
    /// Current events and headlines.
    case news
}

/// A web search a model asked for.
public struct SearchRequest: Sendable, Equatable {
    public let query: String
    public let kind: SearchKind

    public init(query: String, kind: SearchKind = .general) {
        self.query = query
        self.kind = kind
    }
}

public struct SearchDataProvider: Sendable {
    /// The raw HTML of a page, for reading what a result actually says.
    public let fetchPage: @Sendable (URL) async throws -> String
    public let search: @Sendable (URL, SearchRequest) async throws -> [SearchSource]

    public init(
        fetchPage: @escaping @Sendable (URL) async throws -> String = { _ in "" },
        search: @escaping @Sendable (URL, SearchRequest) async throws -> [SearchSource]
    ) {
        self.fetchPage = fetchPage
        self.search = search
    }
}

public extension SearchDataProvider {
    static func live(service: SearchService = SearchService(), pages: PageService = PageService()) -> SearchDataProvider {
        SearchDataProvider(
            fetchPage: { url in try await pages.fetchHTML(url: url) },
            search: { baseURL, request in
                let category = request.kind == .news ? OllamaToolDTO.newsCategory : nil
                return try await service.search(baseURL: baseURL, query: request.query, category: category)
                    .compactMap(SearchSource.init(from:))
            }
        )
    }
}

extension SearchSource {
    /// Fails for results whose link is missing or is not a web page.
    init?(from dto: SearchResultDTO) {
        guard let address = dto.url, let url = URL(string: address), Self.isWebLink(url) else {
            return nil
        }
        self.init(title: dto.title ?? address, url: url, snippet: dto.content ?? "")
    }
}
