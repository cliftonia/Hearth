import Foundation
@testable import HearthDomain
import Testing

/// A site's icon is fetched once, kept, and never asked for under a name that could not be a site's.
struct SiteIconCacheTests {
    /// Counts the fetches made, and holds what was written.
    private actor Record {
        var fetchCount = 0
        var written: [String: Data] = [:]

        func fetched() { fetchCount += 1 }
        func wrote(_ host: String, _ data: Data) { written[host] = data }
    }

    private func makeTestSubject(record: Record, icon: Data?, kept: [String: Data] = [:]) -> SiteIconCache {
        SiteIconCache(
            fetch: { _ in
                await record.fetched()
                return icon
            },
            read: { kept[$0] },
            write: { await record.wrote($0, $1) }
        )
    }

    @Test func `an icon is fetched once, kept, and answered from memory after that`() async {
        let record = Record()
        let icon = Data([1, 2, 3])
        let subject = makeTestSubject(record: record, icon: icon)

        let first = await subject.icon(for: "News.Example.com")
        let second = await subject.icon(for: "news.example.com")

        #expect(first == icon)
        #expect(second == icon)
        #expect(await record.fetchCount == 1)
        #expect(await record.written == ["news.example.com": icon])
    }

    @Test func `a site with no icon is not asked twice`() async {
        let record = Record()
        let subject = makeTestSubject(record: record, icon: nil)

        #expect(await subject.icon(for: "quiet.example") == nil)
        #expect(await subject.icon(for: "quiet.example") == nil)
        #expect(await record.fetchCount == 1)
        #expect(await record.written.isEmpty)
    }

    @Test func `an icon already kept on the device is not fetched`() async {
        let record = Record()
        let kept = Data([9])
        let subject = makeTestSubject(record: record, icon: Data([1]), kept: ["kept.example": kept])

        #expect(await subject.icon(for: "kept.example") == kept)
        #expect(await record.fetchCount == 0)
    }

    @Test(arguments: ["", "localhost", "../etc/passwd", "a/b.example", "exa mple.com", ".example.com", "a..b", "ex\u{e4}mple.com"])
    func `a name that could not be a site's is answered with nothing and asks no one`(name: String) async {
        let record = Record()
        let subject = makeTestSubject(record: record, icon: Data([1]))

        #expect(await subject.icon(for: name) == nil)
        #expect(await record.fetchCount == 0)
    }
}
