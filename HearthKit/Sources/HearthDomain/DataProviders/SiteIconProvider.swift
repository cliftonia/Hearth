import Foundation
import HearthData

/// How the app gets the small picture a web site shows for itself, to stand beside a source of a reply.
public struct SiteIconProvider: Sendable {
    /// The icon of the site with the given host name, as the site serves it; `nil` when it has none that can be had.
    public let load: @Sendable (String) async -> Data?

    public init(load: @escaping @Sendable (String) async -> Data?) {
        self.load = load
    }
}

public extension SiteIconProvider {
    /// Asks for nothing and has no icons: for tests, and wherever the sites should not be visited.
    static let none = SiteIconProvider { _ in nil }

    /// Fetched from each site itself, once, and then kept among the device's caches, which the system may clear.
    static func live(pages: PageService = PageService()) -> SiteIconProvider {
        let files = FileStoreService(directoryURL: URL.cachesDirectory.appending(path: "SiteIcons", directoryHint: .isDirectory))
        let cache = SiteIconCache(
            fetch: { host in try? await pages.fetchIcon(host: host) },
            read: { host in files.loadNow(name: host) },
            write: { host, data in try? await files.save(data, name: host) }
        )
        return SiteIconProvider { host in await cache.icon(for: host) }
    }
}

/// Remembers each site's icon, or that it has none, so a site is asked at most once while the app runs, and one
/// that answered is not asked again until the device clears its caches.
///
/// An actor, since every reply on screen asks it at once and the answers must not be fetched twice.
public actor SiteIconCache {
    private let fetch: @Sendable (String) async -> Data?
    private let read: @Sendable (String) -> Data?
    private let write: @Sendable (String, Data) async -> Void
    /// What each host was found to have; a host with none is kept too, as `nil`, so it is not asked again.
    private var known: [String: Data?] = [:]
    /// The fetches under way, so that a second asker waits for the first's answer.
    private var pending: [String: Task<Data?, Never>] = [:]

    public init(
        fetch: @escaping @Sendable (String) async -> Data?,
        read: @escaping @Sendable (String) -> Data?,
        write: @escaping @Sendable (String, Data) async -> Void
    ) {
        self.fetch = fetch
        self.read = read
        self.write = write
    }

    /// The icon for a host name. Names that could not be a site's are answered with `nil` without asking anyone.
    public func icon(for host: String) async -> Data? {
        let host = host.lowercased()
        guard Self.isHostName(host) else {
            return nil
        }
        if let answer = known[host] {
            return answer
        }
        if let task = pending[host] {
            return await task.value
        }
        let task = Task { [fetch, read, write] () -> Data? in
            if let kept = read(host) {
                return kept
            }
            guard let fetched = await fetch(host) else {
                return nil
            }
            await write(host, fetched)
            return fetched
        }
        pending[host] = task
        let answer = await task.value
        pending[host] = nil
        known[host] = .some(answer)
        return answer
    }

    /// Whether the text is a plain host name: letters, digits, dots and hyphens, with at least one dot. It becomes
    /// a file's name, so nothing else is let through.
    static func isHostName(_ text: String) -> Bool {
        text.contains(".") && text.count <= 253 && text.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "-") }
            && !text.hasPrefix(".") && !text.contains("..")
    }
}
