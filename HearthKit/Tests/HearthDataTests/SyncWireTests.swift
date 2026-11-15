import Foundation
@testable import HearthData
import Testing

/// The wire's times, raw JSON values, and giving back fields a newer client wrote.
struct SyncWireTests {
    @Test(arguments: [Int64(0), 1_794_821_412_345, 1_794_821_412_001, 1_794_821_412_999, 951_782_400_000])
    func `a time is written with milliseconds in UTC and read back exactly`(milliseconds: Int64) throws {
        let date = WireTime.date(milliseconds: milliseconds)
        let text = WireTime.string(from: date)

        #expect(text.count == 24)
        #expect(text.hasSuffix("Z"))
        #expect(WireTime.milliseconds(of: try #require(WireTime.date(from: text))) == milliseconds)
    }

    @Test func `the hub's form is the one written`() {
        #expect(WireTime.string(from: WireTime.date(milliseconds: 1_794_821_412_345)) == "2026-11-16T09:30:12.345Z")
    }

    @Test func `times without milliseconds, or with more digits, are read; anything else is not`() {
        #expect(WireTime.date(from: "2026-11-16T09:30:12Z") == WireTime.date(milliseconds: 1_794_821_412_000))
        #expect(WireTime.date(from: "2026-11-16T09:30:12.3456789Z") == WireTime.date(milliseconds: 1_794_821_412_345))
        for bad in ["2026-11-16T09:30:12.345+00:00", "2026-11-16 09:30:12Z", "soon", "", "2026-11-16T09:30Z"] {
            #expect(WireTime.date(from: bad) == nil)
        }
    }

    @Test func `raw JSON keeps whole numbers whole and every kind of value as it was`() throws {
        let text = #"{"big":9007199254740993,"half":0.5,"flag":true,"none":null,"list":["a",1],"nested":{"x":"y"}}"#
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
        let again = try JSONDecoder().decode(JSONValue.self, from: try JSONEncoder().encode(value))

        #expect(value.objectValue?["big"] == .integer(9_007_199_254_740_993))
        #expect(value.objectValue?["flag"] == .bool(true))
        #expect(value.objectValue?["half"] == .double(0.5))
        #expect(again == value)
    }

    @Test func `unknown fields at the body, in messages and in documents are given back, and known ones are not doubled`() {
        let documentID = "6d1f0e2a-3b4c-4d5e-8f60-718293a4b5c6"
        let received: JSONValue = .object([
            "schema": .integer(3),
            "title": .string("Old title"),
            "taskId": .string("T1"),
            "messages": .array([.object([
                "id": .string("ABC"),
                "text": .string("old"),
                "mood": .string("curious"),
                "documents": .array([.object(["id": .string(documentID), "name": .string("a"), "pages": .integer(4)])])
            ])])
        ])
        let kept = SyncUnknownFieldsDTO(from: received, known: SyncWire.conversationFields)
        let written: JSONValue = .object([
            "schema": .integer(1),
            "title": .string("New title"),
            "messages": .array([.object([
                "id": .string("abc"),
                "text": .string("new"),
                "documents": .array([.object(["id": .string(documentID), "name": .string("a")])])
            ])])
        ])

        let merged = kept.merged(into: written).objectValue ?? [:]
        let message = merged["messages"]?.arrayValue?.first?.objectValue ?? [:]

        #expect(kept.body == ["taskId": .string("T1")])
        #expect(merged["title"] == .string("New title"))
        #expect(merged["taskId"] == .string("T1"))
        #expect(merged["schema"] == .integer(3))
        #expect(message["text"] == .string("new"))
        #expect(message["mood"] == .string("curious"))
        #expect(message["documents"]?.arrayValue?.first?.objectValue?["pages"] == .integer(4))
    }

    @Test func `a body with nothing unknown keeps nothing`() {
        let kept = SyncUnknownFieldsDTO(from: .object(["schema": .integer(1), "text": .string("x")]), known: SyncWire.memoryFields)
        #expect(kept.isEmpty)
    }
}
