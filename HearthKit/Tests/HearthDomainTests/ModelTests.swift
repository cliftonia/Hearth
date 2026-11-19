import Foundation
@testable import HearthDomain
import Testing

/// How addresses are read, and how settings survive saving, updating and older saved forms.
struct ServerSettingsTests {
    @Test(arguments: [
        ("https://server.example.ts.net", "https://server.example.ts.net"),
        ("server.example.ts.net:8888", "https://server.example.ts.net:8888"),
        ("  http://100.64.0.1:8880  ", "http://100.64.0.1:8880")
    ])
    func `an address is read with or without a scheme`(address: String, expected: String) {
        #expect(ServerSettings(ollamaAddress: address).ollamaURL?.absoluteString == expected)
    }

    @Test(arguments: ["", "   ", "https://"])
    func `an address with no host is no address`(address: String) {
        #expect(ServerSettings(ollamaAddress: address).ollamaURL == nil)
    }

    @Test func `settings saved before the theme existed keep their addresses and follow the system`() throws {
        let json = #"{"ollamaAddress":"https://a.example","searchAddress":"","speechAddress":"http://b.example.ts.net:8880","voice":"af_heart"}"#

        let settings = try JSONDecoder().decode(ServerSettings.self, from: Data(json.utf8))

        #expect(settings.ollamaAddress == "https://a.example")
        #expect(settings.speechAddress == "http://b.example.ts.net:8880")
        #expect(settings.voice == "af_heart")
        #expect(settings.appearance == .system)
        #expect(settings.customInstructions.isEmpty)
        #expect(!settings.isAutoReadEnabled)
        #expect(!settings.isLockEnabled)
        #expect(settings.isFollowUpsEnabled)
        #expect(settings.thinkingLevel == .medium)
        #expect(settings.isPageReadingEnabled)
    }

    @Test(arguments: ThinkingLevelKind.allCases)
    func `the thinking level survives a round trip and other updates`(level: ThinkingLevelKind) throws {
        let settings = ServerSettings(ollamaAddress: "https://a.example").updating(thinkingLevel: level)

        let decoded = try JSONDecoder().decode(ServerSettings.self, from: JSONEncoder().encode(settings)).updating(isAutoReadEnabled: true)

        #expect(decoded.thinkingLevel == level)
        #expect(decoded.ollamaAddress == "https://a.example")
    }

    @Test func `switching reading aloud leaves the other settings as they were`() {
        let settings = ServerSettings(ollamaAddress: "https://a.example", isLockEnabled: true, isFollowUpsEnabled: false)

        let reading = settings.updating(isAutoReadEnabled: true)

        #expect(reading.isAutoReadEnabled)
        #expect(reading.isLockEnabled)
        #expect(!reading.isFollowUpsEnabled)
        #expect(reading.ollamaAddress == "https://a.example")
    }

    @Test func `the lock and reading aloud survive a round trip and a change of theme`() throws {
        let settings = ServerSettings(customInstructions: "Be brief.", isAutoReadEnabled: true, isLockEnabled: true)

        let decoded = try JSONDecoder().decode(ServerSettings.self, from: JSONEncoder().encode(settings)).updating(appearance: .dark)

        #expect(decoded.isLockEnabled)
        #expect(decoded.isAutoReadEnabled)
        #expect(decoded.customInstructions == "Be brief.")
    }

    @Test(arguments: AppearanceKind.allCases)
    func `the theme survives a round trip and a change of model`(appearance: AppearanceKind) throws {
        let settings = ServerSettings(ollamaAddress: "https://a.example", appearance: appearance)

        let decoded = try JSONDecoder().decode(ServerSettings.self, from: JSONEncoder().encode(settings))

        #expect(decoded == settings)
        #expect(decoded.updating(defaultModelID: ChatModel.ID("gemma4")).appearance == appearance)
    }

    @Test func `changing the theme leaves everything else as it was`() {
        let settings = ServerSettings(ollamaAddress: "https://a.example", voice: "af_heart", defaultModelID: ChatModel.ID("gemma4"))

        let dark = settings.updating(appearance: .dark)

        #expect(dark.appearance == .dark)
        #expect(dark.ollamaAddress == "https://a.example")
        #expect(dark.voice == "af_heart")
        #expect(dark.defaultModelID == ChatModel.ID("gemma4"))
    }
}

/// How a model's name is shown.
struct ChatModelTests {
    @Test(arguments: [
        ("gemma4:latest", "gemma4"),
        ("kimi-k3:cloud", "kimi-k3"),
        ("qwen3.6:35b-a3b", "qwen3.6:35b-a3b"),
        ("huihui_ai/gemma-4-abliterated:latest", "gemma-4-abliterated")
    ])
    func `the display name drops the tags that say nothing`(name: String, displayName: String) {
        #expect(ChatModel(id: ChatModel.ID(name)).displayName == displayName)
    }
}

/// Which links count as web pages.
struct SearchSourceTests {
    @Test(arguments: [
        ("https://docs.example.com/ps", true),
        ("HTTP://example.com", true),
        ("tel:+15550100", false),
        ("javascript:alert(1)", false),
        ("otherapp://open?item=1", false),
        ("file:///etc/hosts", false),
        ("https:///no-host", false)
    ])
    func `only links to web pages are accepted`(address: String, isAccepted: Bool) throws {
        #expect(SearchSource.isWebLink(try #require(URL(string: address))) == isAccepted)
    }
}
