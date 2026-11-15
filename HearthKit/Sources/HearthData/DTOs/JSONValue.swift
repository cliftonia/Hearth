import Foundation

/// Any JSON value, kept exactly as it was read, so that fields the app does not know can be written back unchanged.
public enum JSONValue: Hashable, Sendable {
    case null
    case bool(Bool)
    /// A whole number, kept whole so that a large one is not rounded through a `Double`.
    case integer(Int64)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    /// The members of an object; `nil` for anything else.
    public var objectValue: [String: JSONValue]? {
        if case .object(let members) = self {
            return members
        }
        return nil
    }

    /// The elements of an array; `nil` for anything else.
    public var arrayValue: [JSONValue]? {
        if case .array(let elements) = self {
            return elements
        }
        return nil
    }

    /// The text of a string; `nil` for anything else.
    public var stringValue: String? {
        if case .string(let text) = self {
            return text
        }
        return nil
    }

    /// The value of a whole number; `nil` for anything else.
    public var integerValue: Int64? {
        if case .integer(let number) = self {
            return number
        }
        return nil
    }
}

extension JSONValue: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}
