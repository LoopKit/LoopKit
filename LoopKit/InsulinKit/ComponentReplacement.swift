//
//  ComponentReplacement.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

/// Details of a `.replaceComponent` pump event. The event's date is when the new component started.
public struct ComponentReplacement: Codable, Hashable {
    public enum Reason: Codable, Hashable {
        /// Replaced at or after the end of its nominal lifetime
        case expired
        /// The pump faulted, with the pump's own code for the fault
        case fault(code: String?)
        case occlusion(code: String?)
        /// Replaced early, with no fault or occlusion
        case userInitiated
        /// Not known, or written by a newer build
        case unknown

        private enum CodingKeys: String, CodingKey {
            case type
            case code
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let code = try? container.decodeIfPresent(String.self, forKey: .code)
            switch try container.decode(String.self, forKey: .type) {
            case "expired": self = .expired
            case "fault": self = .fault(code: code)
            case "occlusion": self = .occlusion(code: code)
            case "userInitiated": self = .userInitiated
            default: self = .unknown
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encodeIfPresent(code, forKey: .code)
        }

        public var type: String {
            switch self {
            case .expired: return "expired"
            case .fault: return "fault"
            case .occlusion: return "occlusion"
            case .userInitiated: return "userInitiated"
            case .unknown: return "unknown"
            }
        }

        public var code: String? {
            switch self {
            case .fault(let code), .occlusion(let code): return code
            default: return nil
            }
        }
    }

    /// The component that was replaced
    public struct PreviousComponent: Codable, Hashable {
        /// When it stopped delivering, such as when a pod was deactivated
        public var stopDate: Date?
        /// Insulin left in it, when the pump reported it
        public var remainingUnits: Double?
        public var reason: Reason

        public init(stopDate: Date? = nil, remainingUnits: Double? = nil, reason: Reason) {
            self.stopDate = stopDate
            self.remainingUnits = remainingUnits
            self.reason = reason
        }
    }

    /// Insulin used to fill a cannula or tubing, which is not delivered to the body.
    public struct Prime: Codable, Hashable {
        public enum Target: String, Codable {
            case cannula
            case tubing
        }

        public var target: Target
        public var volume: Double

        public init(target: Target, volume: Double) {
            self.target = target
            self.volume = volume
        }
    }

    /// Nil when the pump knows nothing about the replaced component
    public var previous: PreviousComponent?
    public var primes: [Prime]
    /// The end of the new component's nominal lifetime
    public var expirationDate: Date?
    /// Identifies the new component, such as a pod's lot and sequence numbers
    public var componentIdentifier: String?

    public init(previous: PreviousComponent? = nil, primes: [Prime] = [], expirationDate: Date? = nil, componentIdentifier: String? = nil) {
        self.previous = previous
        self.primes = primes
        self.expirationDate = expirationDate
        self.componentIdentifier = componentIdentifier
    }

    private enum CodingKeys: String, CodingKey {
        case previous
        case primes
        case expirationDate
        case componentIdentifier
    }

    private struct DecodedPrime: Decodable {
        let prime: Prime?

        init(from decoder: Decoder) throws {
            prime = try? Prime(from: decoder)
        }
    }

    /// Primes with a target from a newer build are dropped, keeping the rest of the record.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        previous = try container.decodeIfPresent(PreviousComponent.self, forKey: .previous)
        primes = (try container.decodeIfPresent([DecodedPrime].self, forKey: .primes) ?? []).compactMap(\.prime)
        expirationDate = try container.decodeIfPresent(Date.self, forKey: .expirationDate)
        componentIdentifier = try container.decodeIfPresent(String.self, forKey: .componentIdentifier)
    }

    init(encoded: Data) throws {
        self = try JSONDecoder().decode(ComponentReplacement.self, from: encoded)
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self)
    }
}
