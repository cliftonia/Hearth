import Foundation
import HearthData

public struct SearchDataProvider: Sendable {
    public let search: @Sendable (URL, String) async throws -> [SearchSource]

    public init(search: @escaping @Sendable (URL, String) async throws -> [SearchSource]) {
        self.search = search
    }
}

public extension SearchDataProvider {
    static func live(service: SearchService = SearchService()) -> SearchDataProvider {
        SearchDataProvider { baseURL, query in
            try await service.search(baseURL: baseURL, query: query).compactMap(SearchSource.init(from:))
        }
    }
}

extension SearchSource {
    /// Fails for results without a usable link.
    init?(from dto: SearchResultDTO) {
        guard let address = dto.url, let url = URL(string: address), url.host() != nil else {
            return nil
        }
        self.init(title: dto.title ?? address, url: url, snippet: dto.content ?? "")
    }
}
