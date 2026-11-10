import Foundation

public enum PageError: Error, Sendable, Equatable {
    case notHTML
}

/// Fetches a web page so that its text can be read. Nothing is kept: no cookies, no cache.
public struct PageService: Sendable {
    /// Pages are cut off here; what a reader needs is near the top, and some pages never end.
    private static let maximumBytes = 1_500_000

    private let session: URLSession

    public init(session: URLSession = .pages) {
        self.session = session
    }

    public func fetchHTML(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw HTTPError.invalidResponse
        }
        guard http.value(forHTTPHeaderField: "Content-Type")?.lowercased().contains("html") == true else {
            throw PageError.notHTML
        }
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            if data.count >= Self.maximumBytes {
                break
            }
        }
        return String(decoding: data, as: UTF8.self)
    }
}

extension URLSession {
    /// A session for reading pages: short timeouts, and no cookies or cache carried from one page to the next.
    public static let pages: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 6
        configuration.timeoutIntervalForResource = 8
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        return URLSession(configuration: configuration)
    }()
}
