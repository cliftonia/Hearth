import Foundation

/// Decides which addresses a page may be read from.
///
/// The addresses come from search results, which anyone can influence. A phone sits on networks with
/// unguarded services (a router, a home server, a tailnet), so only public web addresses are read.
public enum PageAddressPolicy {
    private static let privateSuffixes = [".local", ".localhost", ".internal", ".lan", ".home", ".home.arpa", ".ts.net", ".onion"]

    /// Whether the URL, by its form alone, names a page on the public web: HTTPS, and a real domain name rather than a number.
    public static func isAllowedForm(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host(percentEncoded: false)?.lowercased(), url.user == nil else {
            return false
        }
        let isName = host.contains(".") && host.contains(where: \.isLetter) && !host.contains(":")
        return isName && !privateSuffixes.contains { host.hasSuffix($0) }
    }

    /// Whether the URL has an allowed form and its name leads only to public addresses.
    public static func isAllowed(_ url: URL) -> Bool {
        guard isAllowedForm(url), let host = url.host(percentEncoded: false) else {
            return false
        }
        let addresses = resolve(host)
        return !addresses.isEmpty && addresses.allSatisfy(isPublic(address:))
    }

    /// Whether an address, as 4 or 16 bytes, is out on the public internet.
    public static func isPublic(address bytes: [UInt8]) -> Bool {
        switch bytes.count {
        case 4:
            return isPublicIPv4(bytes)
        case 16:
            let mappedPrefix: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFF, 0xFF]
            let translatedPrefix: [UInt8] = [0, 0x64, 0xFF, 0x9B, 0, 0, 0, 0, 0, 0, 0, 0]
            // An IPv4 address carried in the mapped or NAT64 form is judged as the IPv4 address it is.
            // NAT64 is how a phone on an IPv6-only mobile network reaches the IPv4 web.
            if Array(bytes.prefix(12)) == mappedPrefix || Array(bytes.prefix(12)) == translatedPrefix {
                return isPublicIPv4(Array(bytes.suffix(4)))
            }
            // Everything else must be ordinary global unicast, 2000::/3. That alone rules out loopback,
            // unique-local, link-local, site-local, multicast and every other carried-IPv4 form.
            guard bytes[0] & 0xE0 == 0x20 else {
                return false
            }
            let isSixToFour = bytes[0] == 0x20 && bytes[1] == 0x02
            let isTeredo = bytes[0] == 0x20 && bytes[1] == 0x01 && bytes[2] == 0 && bytes[3] == 0
            let isDocumentation = bytes[0] == 0x20 && bytes[1] == 0x01 && bytes[2] == 0x0D && bytes[3] == 0xB8
            return !(isSixToFour || isTeredo || isDocumentation)
        default:
            return false
        }
    }

    /// Whether an address written out as text, as a connection reports it, is out on the public internet.
    public static func isPublic(addressText: String) -> Bool {
        // A scoped address such as fe80::1%en0 is local by definition.
        guard !addressText.contains("%") else {
            return false
        }
        var ipv4 = in_addr()
        if inet_pton(AF_INET, addressText, &ipv4) == 1 {
            return isPublic(address: withUnsafeBytes(of: ipv4) { Array($0) })
        }
        var ipv6 = in6_addr()
        if inet_pton(AF_INET6, addressText, &ipv6) == 1 {
            return isPublic(address: withUnsafeBytes(of: ipv6) { Array($0) })
        }
        return false
    }

    private static func isPublicIPv4(_ bytes: [UInt8]) -> Bool {
        let (first, second) = (bytes[0], bytes[1])
        let isPrivate = first == 10 || (first == 172 && (16...31).contains(second)) || (first == 192 && second == 168)
        let isCarrierGrade = first == 100 && (64...127).contains(second)
        let isLocal = first == 0 || first == 127 || (first == 169 && second == 254)
        let isReserved = (first == 192 && second == 0 && bytes[2] == 0) || (first == 198 && (18...19).contains(second)) || first >= 224
        return !(isPrivate || isCarrierGrade || isLocal || isReserved)
    }

    /// Every address the name resolves to, each as 4 or 16 bytes.
    private static func resolve(_ host: String) -> [[UInt8]] {
        var hints = addrinfo()
        hints.ai_socktype = SOCK_STREAM
        var first: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &first) == 0 else {
            return []
        }
        defer { freeaddrinfo(first) }
        var addresses: [[UInt8]] = []
        var next = first
        while let info = next {
            if info.pointee.ai_family == AF_INET {
                info.pointee.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { pointer in
                    addresses.append(withUnsafeBytes(of: pointer.pointee.sin_addr) { Array($0) })
                }
            } else if info.pointee.ai_family == AF_INET6 {
                info.pointee.ai_addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { pointer in
                    addresses.append(withUnsafeBytes(of: pointer.pointee.sin6_addr) { Array($0) })
                }
            }
            next = info.pointee.ai_next
        }
        return addresses
    }
}
