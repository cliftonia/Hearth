import Foundation

/// The fields of a received item that this app does not know, kept so that they go back to the hub unchanged when
/// the item is uploaded again (docs/WIRE_FORMAT.md, section 9).
///
/// They are kept at three places: the top level of the body, each message (by its `id`) and each document (by its
/// `id`). Anything nested elsewhere is written whole by every client.
public struct SyncUnknownFieldsDTO: Codable, Sendable, Hashable {
    /// The schema of the body they were kept from; the higher of it and the app's own is written back.
    public var schema: Int
    public var body: [String: JSONValue]
    public var messages: [String: [String: JSONValue]]
    public var documents: [String: [String: JSONValue]]

    public init(
        schema: Int = 1,
        body: [String: JSONValue] = [:],
        messages: [String: [String: JSONValue]] = [:],
        documents: [String: [String: JSONValue]] = [:]
    ) {
        self.schema = schema
        self.body = body
        self.messages = messages
        self.documents = documents
    }

    /// Whether there is nothing to give back beyond what this app writes anyway.
    public var isEmpty: Bool {
        schema <= SyncWire.schema && body.isEmpty && messages.isEmpty && documents.isEmpty
    }

    /// The fields of a received body whose names are not among those the app knows for its kind.
    ///
    /// - Parameter known: The body-level fields of the item's kind, such as `SyncWire.conversationFields`.
    public init(from body: JSONValue, known: Set<String>) {
        let members = body.objectValue ?? [:]
        self.init(schema: Int(members["schema"]?.integerValue ?? Int64(SyncWire.schema)))
        self.body = Self.unknown(in: members, known: known)
        for message in members["messages"]?.arrayValue ?? [] {
            guard let fields = message.objectValue, let id = fields["id"]?.stringValue else {
                continue
            }
            let unknown = Self.unknown(in: fields, known: SyncWire.messageFields)
            if !unknown.isEmpty {
                messages[id.lowercased()] = unknown
            }
            collectDocuments(from: fields)
        }
        collectDocuments(from: members)
    }

    /// The body as this app wrote it, with the kept fields put back wherever the app did not write the same name.
    public func merged(into written: JSONValue) -> JSONValue {
        guard var members = written.objectValue else {
            return written
        }
        if let schema = members["schema"]?.integerValue, Int(schema) < self.schema {
            members["schema"] = .integer(Int64(self.schema))
        }
        members.merge(body) { mine, _ in mine }
        if let list = members["messages"]?.arrayValue {
            members["messages"] = .array(list.map { message in
                guard var fields = message.objectValue else {
                    return message
                }
                if let id = fields["id"]?.stringValue, let kept = messages[id.lowercased()] {
                    fields.merge(kept) { mine, _ in mine }
                }
                return .object(withDocuments(fields))
            })
        }
        return .object(withDocuments(members))
    }

    private mutating func collectDocuments(from fields: [String: JSONValue]) {
        for document in fields["documents"]?.arrayValue ?? [] {
            guard let documentFields = document.objectValue, let id = documentFields["id"]?.stringValue else {
                continue
            }
            let unknown = Self.unknown(in: documentFields, known: SyncWire.documentFields)
            if !unknown.isEmpty {
                documents[id.lowercased()] = unknown
            }
        }
    }

    private func withDocuments(_ fields: [String: JSONValue]) -> [String: JSONValue] {
        guard let list = fields["documents"]?.arrayValue, !documents.isEmpty else {
            return fields
        }
        var fields = fields
        fields["documents"] = .array(list.map { document in
            guard var documentFields = document.objectValue, let id = documentFields["id"]?.stringValue,
                  let kept = documents[id.lowercased()] else {
                return document
            }
            documentFields.merge(kept) { mine, _ in mine }
            return .object(documentFields)
        })
        return fields
    }

    private static func unknown(in fields: [String: JSONValue], known: Set<String>) -> [String: JSONValue] {
        fields.filter { !known.contains($0.key) }
    }
}

/// What this app knows of the wire format, and the conversions between its DTOs and raw JSON.
public enum SyncWire {
    /// The schema this app writes.
    public static let schema = 1
    /// The largest `PUT` body the hub takes, in bytes.
    public static let maximumItemBytes = 20 * 1024 * 1024

    /// The body-level fields the app knows, for each kind.
    public static let conversationFields = Set(ConversationBodyDTO.CodingKeys.allCases.map(\.rawValue))
    public static let projectFields = Set(ProjectBodyDTO.CodingKeys.allCases.map(\.rawValue))
    public static let memoryFields = Set(MemoryBodyDTO.CodingKeys.allCases.map(\.rawValue))
    static let messageFields = Set(MessageDTO.CodingKeys.allCases.map(\.rawValue))
    static let documentFields = Set(DocumentDTO.CodingKeys.allCases.map(\.rawValue))

    /// A DTO as raw JSON, in the wire form.
    public static func json(from value: some Encodable) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: try WireTime.encoder().encode(value))
    }

    /// A DTO read from raw JSON in the wire form.
    public static func decode<Value: Decodable>(_ type: Value.Type, from json: JSONValue) throws -> Value {
        try WireTime.decoder().decode(type, from: try JSONEncoder().encode(json))
    }
}
