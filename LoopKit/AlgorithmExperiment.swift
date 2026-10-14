//
//  AlgorithmExperiment.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

/// An algorithm experiment in effect, identified by a string so new experiments need no LoopKit changes
public struct AlgorithmExperiment: Codable, Equatable {
    /// e.g. "integralRetrospectiveCorrection"
    public var identifier: String
    /// Experiment-specific configuration
    public var parameters: JSONValue?

    public init(identifier: String, parameters: JSONValue? = nil) {
        self.identifier = identifier
        self.parameters = parameters
    }
}

/// A free-form JSON value
public enum JSONValue: Codable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    /// The value as Foundation JSON objects, for JSONSerialization based uploaders
    public var jsonObject: Any {
        switch self {
        case .null: return NSNull()
        case .bool(let value): return value
        case .number(let value): return value
        case .string(let value): return value
        case .array(let value): return value.map { $0.jsonObject }
        case .object(let value): return value.mapValues { $0.jsonObject }
        }
    }
}

extension AlgorithmExperiment {
    /// The experiment as a Foundation dictionary, for JSONSerialization based uploaders
    public var jsonObject: [String: Any] {
        var object: [String: Any] = ["identifier": identifier]
        object["parameters"] = parameters?.jsonObject
        return object
    }
}
