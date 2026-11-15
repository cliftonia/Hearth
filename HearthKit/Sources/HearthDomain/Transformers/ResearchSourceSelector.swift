import Foundation

/// Chooses which of the pages found are read: no page twice, a share for every search, and no site crowding out the rest.
public struct ResearchSourceSelector: Sendable {
    /// Parts of an address that only say where a visitor came from, and so do not make a different page.
    private static let trackingNames: Set<String> = ["fbclid", "gclid", "msclkid", "mc_cid", "mc_eid", "ref", "ref_src", "igshid"]

    public init() {}

    /// The pages to read, in the order they are numbered.
    ///
    /// The searches take turns: the best result of each, then the next best of each, until the limit is reached.
    ///
    /// - Parameters:
    ///   - results: What each search found, best first.
    ///   - limit: The most pages to choose.
    ///   - taken: Pages chosen earlier, which are not chosen again and count towards their sites' share.
    ///   - isReadable: Whether a page at this address could be read at all; one that could not is left out.
    public func select(
        from results: [[SearchSource]],
        limit: Int,
        taken: [SearchSource] = [],
        isReadable: (URL) -> Bool = { _ in true }
    ) -> [SearchSource] {
        var seen = Set(taken.map { Self.normalisedAddress(of: $0.url) })
        var perSite: [String: Int] = [:]
        for source in taken {
            perSite[Self.site(of: source.url), default: 0] += 1
        }
        var chosen: [SearchSource] = []
        let deepest = results.map(\.count).max() ?? 0
        for rank in 0..<deepest {
            for found in results where rank < found.count {
                guard chosen.count < limit else {
                    return chosen
                }
                let source = found[rank]
                let site = Self.site(of: source.url)
                guard isReadable(source.url), perSite[site, default: 0] < ResearchLimits.maximumSourcesPerSite,
                      seen.insert(Self.normalisedAddress(of: source.url)).inserted else {
                    continue
                }
                perSite[site, default: 0] += 1
                chosen.append(source)
            }
        }
        return chosen
    }

    /// The address with everything taken out that does not change which page it is: the scheme, a leading `www.`,
    /// the case of the name, a closing slash, the fragment and anything that only tracks the visitor.
    public static func normalisedAddress(of url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString.lowercased()
        }
        components.fragment = nil
        let kept = (components.queryItems ?? [])
            .filter { item in
                let name = item.name.lowercased()
                return !name.hasPrefix("utm_") && !trackingNames.contains(name)
            }
            .sorted { ($0.name, $0.value ?? "") < ($1.name, $1.value ?? "") }
        components.queryItems = kept.isEmpty ? nil : kept
        var path = components.percentEncodedPath
        while path.hasSuffix("/") {
            path.removeLast()
        }
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
        return site(of: url) + path + query
    }

    /// The site a page belongs to: its host in lower case, without a leading `www.`.
    public static func site(of url: URL) -> String {
        let host = url.host(percentEncoded: false)?.lowercased() ?? ""
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
