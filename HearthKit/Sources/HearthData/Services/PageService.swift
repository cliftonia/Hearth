import Foundation

/// Why a page was not read.
public enum PageError: Error, Sendable, Equatable {
    /// The address answered with something other than a web page, such as a file or an image.
    case notHTML
    /// The address answered with something other than a picture where a site's icon was asked for.
    case notAnImage
    /// The address is not a page on the public web, so it is not read.
    case addressNotAllowed
}

/// Fetches a public web page so that its text can be read, or a site's icon. Nothing is kept: no cookies, no cache.
public struct PageService: Sendable {
    /// Pages are cut off here; what a reader needs is near the top, and some pages never end.
    private static let maximumBytes = 1_000_000
    /// An icon larger than this is not one worth drawing in a small circle, so it is refused.
    private static let maximumIconBytes = 300_000

    private let session: URLSession

    public init(session: URLSession = .pages) {
        self.session = session
    }

    /// The page's markup, up to the size limit. Fails unless the address, every redirect and every connection is public.
    public func fetchHTML(url: URL) async throws -> String {
        let data = try await fetch(url: url, accept: "text/html,application/xhtml+xml", maximumBytes: Self.maximumBytes) { contentType in
            guard contentType.contains("html") else {
                throw PageError.notHTML
            }
        }
        return String(decoding: data, as: UTF8.self)
    }

    /// The icon a site keeps at its root, as the site serves it. Fails unless the site is on the public web, answers
    /// with a picture, and the picture is small.
    public func fetchIcon(host: String) async throws -> Data {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/favicon.ico"
        guard let url = components.url else {
            throw PageError.addressNotAllowed
        }
        let data = try await fetch(url: url, accept: "image/*", maximumBytes: Self.maximumIconBytes + 1) { contentType in
            // Some sites send their icon as plain bytes without naming it a picture.
            guard contentType.hasPrefix("image/") || contentType.contains("octet-stream") else {
                throw PageError.notAnImage
            }
        }
        guard !data.isEmpty, data.count <= Self.maximumIconBytes else {
            throw PageError.notAnImage
        }
        return data
    }

    /// What a public address answers with, up to a size limit. `checkContentType` is given the kind of content the
    /// answer says it is, in lower case, and throws to refuse it before any of it is read.
    private func fetch(url: URL, accept: String, maximumBytes: Int, checkContentType: (String) throws -> Void) async throws -> Data {
        guard PageAddressPolicy.isAllowed(url) else {
            throw PageError.addressNotAllowed
        }
        var request = URLRequest(url: url)
        request.setValue(accept, forHTTPHeaderField: "Accept")
        let fetchGuard = PageFetchGuard()
        // A refused redirect leaves the redirect response itself, which fails the status check below.
        let (bytes, response) = try await session.bytes(for: request, delegate: fetchGuard)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw HTTPError.invalidResponse
        }
        try checkContentType(http.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? "")
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            if data.count >= maximumBytes {
                break
            }
        }
        // The name was checked before connecting, but a name can be made to answer differently a moment
        // later. What counts is where the connection actually went: unless every hop is known to have
        // reached a public address, what came back is thrown away unread.
        guard await fetchGuard.connectedOnlyToPublicAddresses() else {
            throw PageError.addressNotAllowed
        }
        return data
    }
}

/// Watches one page fetch: follows a redirect only to another public web page, and records where each connection went.
private final class PageFetchGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    /// Where each connection of the fetch went; `nil` until the fetch has ended and said so.
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
