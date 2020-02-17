//
//  InhaledInsulinModel.swift
//  LoopKit
//
//  Created by Anna Quinlan on 2/16/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

// y = -0.09821229 + 0.008567227*x - 0.00002271983*x^2 + 2.055193e-8*x^3

public struct InhaledInsulinModel {
    public let actionDuration: TimeInterval
    public let delay: TimeInterval

    // Precomputed terms
    fileprivate let a: Double = 2.055193 * pow(10, -8)
    fileprivate let b: Double = -0.00002271983
    fileprivate let c: Double = 0.008567227
    fileprivate let d: Double = -0.09821229
    
    /// Configures a new inhaled insulin model with a 6-hour duration
    public init(modelDelay: TimeInterval = 600) {
        actionDuration = TimeInterval(hours: 6)
        delay = modelDelay
    }
}

extension InhaledInsulinModel: InsulinModel {
    public var effectDuration: TimeInterval {
        return actionDuration
    }
    
    // Returns if two insulin models are equal
    public func isEqualTo(other: InsulinModel?) -> Bool {
        if let other = other as? InhaledInsulinModel {
            return self == other
        }
        return false
    }
    
    /// Returns the percentage of total insulin effect remaining at a specified interval after delivery;
    /// also known as Insulin On Board (IOB).
    public func percentEffectRemaining(at time: TimeInterval) -> Double {
        let timeAfterDelay = time - delay
        switch timeAfterDelay {
        case let t where t <= 0:
            return 1
        case let t where t >= effectDuration:
            return 0
        default:
            let t = timeAfterDelay.minutes
            let percentUsed = max(0, min(1, a * pow(t, 3) + b * pow(t, 2) + c * t + d))
            
            return 1 - percentUsed
        }
    }
}

extension InhaledInsulinModel: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "InhaledInsulinModel(actionDuration: \(actionDuration), delay: \(delay)"
    }
}

extension InhaledInsulinModel: Equatable {
    public static func ==(lhs: InhaledInsulinModel, rhs: InhaledInsulinModel) -> Bool {
        return abs(lhs.actionDuration - rhs.actionDuration) < .ulpOfOne &&  abs(lhs.delay - rhs.delay) < .ulpOfOne
    }
}

#if swift(>=4)
extension InhaledInsulinModel: Decodable {
    enum CodingKeys: String, CodingKey {
        case delay = "delay"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let delay: Double = try container.decode(Double.self, forKey: .delay)
        self.init(modelDelay: delay)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(delay, forKey: .delay)
    }
}
#endif
