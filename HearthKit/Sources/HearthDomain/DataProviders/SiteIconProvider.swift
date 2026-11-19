import Foundation
import HearthData

/// How the app gets the small picture a web site shows for itself, to stand beside a source of a reply.
public struct SiteIconProvider: Sendable {
    /// The icon of the site with the given host name, as the site serves it; `nil` when it has none that can be had.
    public let load: @Sendable (String) async -> Data?
    /// Forgets every icon kept, as erasing everything does.
    public let clear: @Sendable () async -> Void

    public init(load: @escaping @Sendable (String) async -> Data?, clear: @escaping @Sendable () async -> Void = {}) {
        self.load = load
        self.clear = clear
    }

    /// The same icons, asked for only while `isAllowed` says so, and otherwise none. Fetching an icon tells the site
    /// that this device read about it, so it is done only where reading the pages themselves is.
    public func onlyWhen(_ isAllowed: @escaping @Sendable () async -> Bool) -> SiteIconProvider {
        SiteIconProvider(load: { host in await isAllowed() ? await load(host) : nil }, clear: clear)
    }
}

public extension SiteIconProvider {
    /// Asks for nothing and has no icons: for tests, and wherever the sites should not be visited.
    static let none = SiteIconProvider { _ in nil }

    /// Fetched from each site itself, once, and then kept among the device's caches, which the system may clear.
    static func live(pages: PageService = PageService()) -> SiteIconProvider {
        let files = FileStoreService(directoryURL: URL.cachesDirectory.appending(path: "SiteIcons", directoryHint: .isDirectory))
        let cache = SiteIconCache(
            fetch: { host in
                do {
                    return .found(try await pages.fetchIcon(host: host))
                } catch is PageError {
                    return .none
                } catch HTTPError.invalidResponse {
                    return .none
                } catch {
                    // Offline, or the site was slow: nothing is concluded, and it is asked again another time.
                    return .unanswered
                }
            },
            read: { host in files.loadNow(name: host) },
            write: { host, data in try? await files.save(data, name: host) }
        )
        return SiteIconProvider(
            load: { host in await cache.icon(for: host) },
            clear: {
                try? await files.deleteAll()
                await cache.forget()
            }
        )
    }
}

/// What asking a site for its icon came to.
public enum SiteIconAnswer: Sendable {
    case found(Data)
    /// The site answered, and has no icon that can be used.
    case none
    /// The site could not be reached, so whether it has one is not known.
    case unanswered
}

/// Asks each site for its icon at most once at a time, keeps what it answers on the device, and remembers which
/// sites have none, so those are not asked again while the app runs. A site that could not be reached is asked
/// again the next time.
///
/// An actor, since every reply on screen asks it at once and the answers must not be fetched twice.
public actor SiteIconCache {
    private let fetch: @Sendable (String) async -> SiteIconAnswer
    private let read: @Sendable (String) -> Data?
    private let write: @Sendable (String, Data) async -> Void
    /// The hosts found to have no icon. The icons themselves are read back from the device, not held here.
    private var withoutIcon: Set<String> = []
    /// The fetches under way, so that a second asker waits for the first's answer.
    private var pending: [String: Task<Data?, Never>] = [:]

    public init(
        fetch: @escaping @Sendable (String) async -> SiteIconAnswer,
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
        guard Self.isHostName(host), !withoutIcon.contains(host) else {
            return nil
        }
        if let kept = read(host) {
            return kept
        }
        if let task = pending[host] {
            return await task.value
        }
        let task = Task { [fetch, write] () -> Data? in
            switch await fetch(host) {
            case .found(let data):
                await write(host, data)
                return data
            case .none:
                self.markWithoutIcon(host)
                return nil
            case .unanswered:
                return nil
            }
        }
        pending[host] = task
        let answer = await task.value
        pending[host] = nil
        return answer
    }

    /// Forgets which sites have no icon, as when everything is erased.
    public func forget() {
        withoutIcon = []
    }

    private func markWithoutIcon(_ host: String) {
        withoutIcon.insert(host)
    }

    /// Whether the text is a plain host name: letters, digits, dots and hyphens, with at least one dot. It becomes
    /// a file's name, so nothing else is let through.
    static func isHostName(_ text: String) -> Bool {
        text.contains(".") && text.count <= 253 && text.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "-") }
            && !text.hasPrefix(".") && !text.contains("..")
    }
}
