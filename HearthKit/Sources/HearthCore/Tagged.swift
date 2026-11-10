import Foundation

/// A raw value branded with a phantom tag, so that identifiers of different models cannot be mixed up.
public struct Tagged<Tag, RawValue: Hashable & Codable & Sendable>: RawRepresentable, Hashable, Sendable {
    public let rawValue: RawValue

    public init(rawValue: RawValue) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: RawValue) {
        self.rawValue = rawValue
    }
}

extension Tagged: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(RawValue.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension Tagged: CustomStringConvertible {
    public var description: String {
        String(describing: rawValue)
    }
}
