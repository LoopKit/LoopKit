//
//  WalshInsulinModel.swift
//  InsulinKit
//
//  Created by Pete Schwamb on 7/30/17.
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation

public struct WalshInsulinModel {
    public let actionDuration: TimeInterval
    public let delay: TimeInterval

    public init(actionDuration: TimeInterval, delay: TimeInterval = 600) {
        self.actionDuration = actionDuration
        self.delay = delay
    }
}

extension WalshInsulinModel: InsulinModel {
    public var effectDuration: TimeInterval {
        return self.actionDuration + self.delay
    }
    
    /// Returns the percentage of total insulin effect remaining at a specified interval after delivery; 
    /// also known as Insulin On Board (IOB).
    ///
    /// These are 4th-order polynomial fits of John Walsh's IOB curve plots, and they first appeared in GlucoDyn.
    ///
    /// See: https:github.com/kenstack/GlucoDyn
    ///
    /// - Parameter time: The interval after insulin delivery
    /// - Returns: The percentage of total insulin effect remaining
    public func percentEffectRemaining(at time: TimeInterval) -> Double {
        let timeAfterDelay = time - delay
        switch timeAfterDelay {
        case let t where t <= 0:
            return 1
        case let t where t >= actionDuration:
            return 0
        default:
            // We only have Walsh models for a few discrete action durations, so we scale other action durations appropriately to the nearest one.
            let nearestModeledDuration: TimeInterval
            
            switch actionDuration {
            case let x where x < TimeInterval(hours: 3):
                nearestModeledDuration = TimeInterval(hours: 3)
            case let x where x > TimeInterval(hours: 6):
                nearestModeledDuration = TimeInterval(hours: 6)
            default:
                nearestModeledDuration = TimeInterval(hours: round(actionDuration.hours))
            }
            
            let minutes = timeAfterDelay.minutes * nearestModeledDuration / actionDuration
            
            switch nearestModeledDuration {
            case TimeInterval(hours: 3):
                return -3.2030e-9 * pow(minutes, 4) + 1.354e-6 * pow(minutes, 3) - 1.759e-4 * pow(minutes, 2) + 9.255e-4 * minutes + 0.99951
            case TimeInterval(hours: 4):
                return -3.310e-10 * pow(minutes, 4) + 2.530e-7 * pow(minutes, 3) - 5.510e-5 * pow(minutes, 2) - 9.086e-4 * minutes + 0.99950
            case TimeInterval(hours: 5):
                return -2.950e-10 * pow(minutes, 4) + 2.320e-7 * pow(minutes, 3) - 5.550e-5 * pow(minutes, 2) + 4.490e-4 * minutes + 0.99300
            case TimeInterval(hours: 6):
                return -1.493e-10 * pow(minutes, 4) + 1.413e-7 * pow(minutes, 3) - 4.095e-5 * pow(minutes, 2) + 6.365e-4 * minutes + 0.99700
            default:
                assertionFailure()
                return 0
            }
        }
    }
}

extension WalshInsulinModel: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "WalshInsulinModel(actionDuration: \(actionDuration), delay: \(delay))"
    }
}

extension WalshInsulinModel: Equatable {
    public static func ==(lhs: WalshInsulinModel, rhs: WalshInsulinModel) -> Bool {
        return abs(lhs.actionDuration - rhs.actionDuration) < .ulpOfOne
    }
}

#if swift(>=4)
extension WalshInsulinModel: Codable {
    enum CodingKeys: String, CodingKey {
        case actionDuration = "actionDuration"
        case delay = "delay"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let actionDuration: Double = try container.decode(Double.self, forKey: .actionDuration)
        let delay: Double = try container.decode(Double.self, forKey: .delay)
        
        self.init(actionDuration: actionDuration, delay: delay)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(actionDuration, forKey: .actionDuration)
        try container.encode(delay, forKey: .delay)
    }

}
#endif
