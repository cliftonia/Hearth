import Foundation
@testable import HearthData
import Testing

struct PageAddressPolicyTests {
    @Test(arguments: [
        "https://docs.example.com/page",
        "https://www.abc.net.au/news/2026-11-10/story"
    ])
    func `a public HTTPS page has an allowed form`(address: String) throws {
        #expect(PageAddressPolicy.isAllowedForm(try #require(URL(string: address))))
    }

    @Test(arguments: [
        "http://docs.example.com/page",
        "https://192.168.1.1/admin",
        "https://100.74.3.68:8123/",
        "https://[::1]/",
        "https://[fd7a:115c:a1e0::1]/",
        "https://localhost/",
        "https://router/",
        "https://printer.local/",
        "https://my-server.tailnet.ts.net/api/tags",
        "https://nas.lan/",
        "https://user:secret@docs.example.com/",
        "https://2130706433/",
        "file:///etc/hosts",
        "ftp://docs.example.com/file"
    ])
    func `private, numeric and non-HTTPS addresses are refused by form alone`(address: String) throws {
        #expect(!PageAddressPolicy.isAllowedForm(try #require(URL(string: address))))
    }

    @Test(arguments: [
        [8, 8, 8, 8], [1, 1, 1, 1], [203, 0, 114, 5], [172, 32, 0, 1], [100, 128, 0, 1]
    ] as [[UInt8]])
    func `public IPv4 addresses are public`(address: [UInt8]) {
        #expect(PageAddressPolicy.isPublic(address: address))
    }

    @Test(arguments: [
        [10, 0, 0, 1], [172, 16, 5, 4], [172, 31, 255, 255], [192, 168, 1, 1], [127, 0, 0, 1], [169, 254, 169, 254],
        [100, 64, 0, 1], [100, 74, 3, 68], [100, 127, 255, 255], [0, 0, 0, 0], [224, 0, 0, 1], [255, 255, 255, 255], [198, 18, 0, 1]
    ] as [[UInt8]])
    func `private, loopback, link-local and carrier-grade IPv4 addresses are not public`(address: [UInt8]) {
        #expect(!PageAddressPolicy.isPublic(address: address))
    }

    private func ipv6(_ leading: [UInt8], last: [UInt8] = []) -> [UInt8] {
        leading + Array(repeating: 0, count: 16 - leading.count - last.count) + last
    }

    @Test func `IPv6 addresses are judged by their range, and a carried IPv4 address by its own`() {
        #expect(PageAddressPolicy.isPublic(address: ipv6([0x26, 0x06, 0x47, 0x00], last: [0x11, 0x11])))
        #expect(!PageAddressPolicy.isPublic(address: ipv6([], last: [1])))
        #expect(!PageAddressPolicy.isPublic(address: ipv6([])))
        #expect(!PageAddressPolicy.isPublic(address: ipv6([0xFD, 0x7A, 0x11, 0x5C])))
        #expect(!PageAddressPolicy.isPublic(address: ipv6([0xFE, 0x80])))
        #expect(!PageAddressPolicy.isPublic(address: ipv6([0xFF, 0x02])))
        // IPv4-mapped and NAT64 forms carry an IPv4 address in their last four bytes.
        let mapped: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFF, 0xFF]
        let translated: [UInt8] = [0, 0x64, 0xFF, 0x9B, 0, 0, 0, 0, 0, 0, 0, 0]
        #expect(!PageAddressPolicy.isPublic(address: mapped + [192, 168, 1, 1]))
        #expect(PageAddressPolicy.isPublic(address: mapped + [8, 8, 8, 8]))
        #expect(!PageAddressPolicy.isPublic(address: translated + [10, 0, 0, 1]))
        #expect(PageAddressPolicy.isPublic(address: translated + [8, 8, 8, 8]))
    }

    @Test func `an address of the wrong length is not public`() {
        #expect(!PageAddressPolicy.isPublic(address: [1, 2, 3]))
    }
}
