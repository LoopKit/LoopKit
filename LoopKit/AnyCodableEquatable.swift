//
//  AnyCodableEquatable.swift
//  LoopKit
//
//  Created by Darin Krauss on 2/8/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation

public struct AnyCodableEquatable: Codable, Equatable {
    public enum Error: Swift.Error {
        case unknownType
    }

    public let wrapped: Any
    private let equals: (Self) -> Bool

    public init<T: Codable & Equatable>(_ wrapped: T) {
        self.wrapped = wrapped
        self.equals = { $0.wrapped as? T == wrapped }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self.init(value)
        } else if let value = try? container.decode(Int.self) {
            self.init(value)
        } else if let value = try? container.decode(Double.self) {
            self.init(value)
        } else if let value = try? container.decode(Bool.self) {
            self.init(value)
        } else {
            throw Error.unknownType
        }
    }

    public func encode(to encoder: Encoder) throws {
        try (wrapped as? Encodable)?.encode(to: encoder)
    }

    public static func ==(lhs: AnyCodableEquatable, rhs: AnyCodableEquatable) -> Bool {
        return lhs.equals(rhs)
    }
}
