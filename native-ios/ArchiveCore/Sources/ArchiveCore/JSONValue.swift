import Foundation

/// An open JSON tree. Typed convenience accessors never invent nonempty values.
public enum JSONValue: Codable, Equatable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    public var objectValue: [String: JSONValue] {
        if case .object(let value) = self { return value }
        return [:]
    }

    public var arrayValue: [JSONValue] {
        if case .array(let value) = self { return value }
        return []
    }

    public var stringValue: String {
        if case .string(let value) = self { return value }
        return ""
    }

    public var doubleValue: Double {
        if case .number(let value) = self { return value }
        return 0
    }

    public var boolValue: Bool {
        if case .bool(let value) = self { return value }
        return false
    }

    public subscript(key: String) -> JSONValue {
        get { objectValue[key] ?? .null }
        set {
            var object = objectValue
            object[key] = newValue
            self = .object(object)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: JSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    // Legacy imports sometimes encoded input values as numeric strings. Do not
    // change the strict public accessor's empty-default contract to coerce them.
    var finiteNumber: Double? {
        let number: Double?
        switch self {
        case .number(let value): number = value
        case .string(let value): number = Double(value)
        default: number = nil
        }
        guard let value = number, value.isFinite else { return nil }
        return value
    }
}
