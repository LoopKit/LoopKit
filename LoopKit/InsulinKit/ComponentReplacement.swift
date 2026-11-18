//
//  ComponentReplacement.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

/// Details of a `.replaceComponent` pump event. The event's date is when the new component started.
public struct ComponentReplacement: Codable, Hashable {
    public enum Reason: String, Codable {
        /// Replaced at or after the end of its nominal lifetime
        case expired
        /// The pump faulted; see `faultCode`
        case fault
        case occlusion
        /// Replaced early, with no fault or occlusion
        case userInitiated
        /// Not known, or written by a newer build
        case unknown

        public init(from decoder: Decoder) throws {
            self = Reason(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
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

    /// When the replaced component stopped delivering, such as when a pod was deactivated
    public var previousStopDate: Date?
    public var reason: Reason?
    /// The pump's own code for the fault, when `reason` is `.fault`
    public var faultCode: String?
    /// Insulin left in the replaced component, when the pump reported it
    public var previousRemainingUnits: Double?
    public var primes: [Prime]
    /// The end of the new component's nominal lifetime
    public var expirationDate: Date?
    /// Identifies the new component, such as a pod's lot and sequence numbers. This identifies a device, so services should not upload it as is.
    public var componentIdentifier: String?

    public init(previousStopDate: Date? = nil, reason: Reason? = nil, faultCode: String? = nil, previousRemainingUnits: Double? = nil, primes: [Prime] = [], expirationDate: Date? = nil, componentIdentifier: String? = nil) {
        self.previousStopDate = previousStopDate
        self.reason = reason
        self.faultCode = faultCode
        self.previousRemainingUnits = previousRemainingUnits
        self.primes = primes
        self.expirationDate = expirationDate
        self.componentIdentifier = componentIdentifier
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
