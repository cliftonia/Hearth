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
            // An IPv4 address carried inside an IPv6 one is judged as the IPv4 address it is.
            if Array(bytes.prefix(12)) == mappedPrefix || Array(bytes.prefix(12)) == translatedPrefix {
                return isPublicIPv4(Array(bytes.suffix(4)))
            }
            let isUnspecifiedOrLoopback = bytes.dropLast().allSatisfy { $0 == 0 } && bytes[15] <= 1
            let isUniqueLocal = bytes[0] & 0xFE == 0xFC
            let isLinkLocal = bytes[0] == 0xFE && bytes[1] & 0xC0 == 0x80
            let isMulticast = bytes[0] == 0xFF
            return !(isUnspecifiedOrLoopback || isUniqueLocal || isLinkLocal || isMulticast)
        default:
            return false
        }
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
