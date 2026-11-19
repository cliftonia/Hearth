import Foundation
@testable import HearthDomain
import Testing

/// A site's icon is fetched once and kept, a site with none is not asked twice, and one that could not be reached is.
struct SiteIconCacheTests {
    /// Counts the fetches made, and stands in for the device's storage.
    private actor Device {
        var fetchCount = 0
        var kept: [String: Data]

        init(kept: [String: Data] = [:]) {
            self.kept = kept
        }

        func fetched() { fetchCount += 1 }
        func keep(_ host: String, _ data: Data) { kept[host] = data }
    }

    /// A box the cache can read at once, as it reads the device's files.
    private final class Shelf: @unchecked Sendable {
        private let lock = NSLock()
        private var kept: [String: Data]

        init(_ kept: [String: Data]) {
            self.kept = kept
        }

        func read(_ host: String) -> Data? { lock.withLock { kept[host] } }
        func keep(_ host: String, _ data: Data) { lock.withLock { kept[host] = data } }
    }

    private func makeTestSubject(device: Device, answer: SiteIconAnswer, kept: [String: Data] = [:]) -> SiteIconCache {
        let shelf = Shelf(kept)
        return SiteIconCache(
            fetch: { _ in
                await device.fetched()
                return answer
            },
            read: { shelf.read($0) },
            write: { host, data in
                shelf.keep(host, data)
                await device.keep(host, data)
            }
        )
    }

    @Test func `an icon is fetched once, kept, and read back after that`() async {
        let device = Device()
        let icon = Data([1, 2, 3])
        let subject = makeTestSubject(device: device, answer: .found(icon))

        let first = await subject.icon(for: "News.Example.com")
        let second = await subject.icon(for: "news.example.com")

        #expect(first == icon)
        #expect(second == icon)
        #expect(await device.fetchCount == 1)
        #expect(await device.kept == ["news.example.com": icon])
    }

    @Test func `a site with no icon is not asked twice, until that is forgotten`() async {
        let device = Device()
        let subject = makeTestSubject(device: device, answer: .none)

        #expect(await subject.icon(for: "quiet.example") == nil)
        #expect(await subject.icon(for: "quiet.example") == nil)
        #expect(await device.fetchCount == 1)

        await subject.forget()
        #expect(await subject.icon(for: "quiet.example") == nil)
        #expect(await device.fetchCount == 2)
    }

    @Test func `a site that could not be reached is asked again the next time`() async {
        let device = Device()
        let subject = makeTestSubject(device: device, answer: .unanswered)

        #expect(await subject.icon(for: "offline.example") == nil)
        #expect(await subject.icon(for: "offline.example") == nil)
        #expect(await device.fetchCount == 2)
    }

    @Test func `an icon already kept on the device is not fetched`() async {
        let device = Device()
        let kept = Data([9])
        let subject = makeTestSubject(device: device, answer: .found(Data([1])), kept: ["kept.example": kept])

        #expect(await subject.icon(for: "kept.example") == kept)
        #expect(await device.fetchCount == 0)
    }

    @Test func `two askers at once share one fetch`() async {
        let device = Device()
        let icon = Data([4])
        let subject = makeTestSubject(device: device, answer: .found(icon))

        async let first = subject.icon(for: "busy.example")
        async let second = subject.icon(for: "busy.example")

        #expect(await first == icon)
        #expect(await second == icon)
        #expect(await device.fetchCount == 1)
    }

    @Test(arguments: ["", "localhost", "../etc/passwd", "a/b.example", "exa mple.com", ".example.com", "a..b", "ex\u{e4}mple.com"])
    func `a name that could not be a site's is answered with nothing and asks no one`(name: String) async {
        let device = Device()
        let subject = makeTestSubject(device: device, answer: .found(Data([1])))

        #expect(await subject.icon(for: name) == nil)
        #expect(await device.fetchCount == 0)
    }

    @Test func `icons are asked for only while they are allowed`() async {
        let subject = SiteIconProvider { _ in Data([1]) }

        #expect(await subject.onlyWhen { false }.load("news.example") == nil)
        #expect(await subject.onlyWhen { true }.load("news.example") == Data([1]))
    }
}
