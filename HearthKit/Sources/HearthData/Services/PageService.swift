import Foundation

public enum PageError: Error, Sendable, Equatable {
    case notHTML
    /// The address is not a page on the public web, so it is not read.
    case addressNotAllowed
}

/// Fetches a public web page so that its text can be read. Nothing is kept: no cookies, no cache.
public struct PageService: Sendable {
    /// Pages are cut off here; what a reader needs is near the top, and some pages never end.
    private static let maximumBytes = 1_000_000

    private let session: URLSession

    public init(session: URLSession = .pages) {
        self.session = session
    }

    public func fetchHTML(url: URL) async throws -> String {
        guard PageAddressPolicy.isAllowed(url) else {
            throw PageError.addressNotAllowed
        }
        var request = URLRequest(url: url)
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        let fetchGuard = PageFetchGuard()
        // A refused redirect leaves the redirect response itself, which fails the status check below.
        let (bytes, response) = try await session.bytes(for: request, delegate: fetchGuard)
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
        // The name was checked before connecting, but a name can be made to answer differently a moment
        // later. What counts is where the connection actually went: unless every hop is known to have
        // reached a public address, what came back is thrown away unread.
        guard await fetchGuard.connectedOnlyToPublicAddresses() else {
            throw PageError.addressNotAllowed
        }
        return String(decoding: data, as: UTF8.self)
    }
}

/// Watches one page fetch: follows a redirect only to another public web page, and records where each connection went.
private final class PageFetchGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var remoteAddresses: [String?]?

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        guard let url = request.url, PageAddressPolicy.isAllowed(url) else {
            return nil
        }
        return request
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        let addresses = metrics.transactionMetrics.map(\.remoteAddress)
        lock.withLock { remoteAddresses = addresses }
    }

    /// Whether every connection of the fetch is known to have reached a public address.
    /// The record arrives as the fetch ends; if it has not come within a second, the answer is no.
    func connectedOnlyToPublicAddresses() async -> Bool {
        for _ in 0..<20 {
            if let addresses = lock.withLock({ remoteAddresses }) {
                return !addresses.isEmpty && addresses.allSatisfy { address in
                    address.map(PageAddressPolicy.isPublic(addressText:)) ?? false
                }
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return false
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
