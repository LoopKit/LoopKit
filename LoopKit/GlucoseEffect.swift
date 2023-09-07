//
//  GlucoseEffect.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit


public struct GlucoseEffect: GlucoseValue, Equatable {
    public let startDate: Date
    public let quantity: HKQuantity

    public init(startDate: Date, quantity: HKQuantity) {
        self.startDate = startDate
        self.quantity = quantity
    }
}

extension GlucoseEffect: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(startDate: try container.decode(Date.self, forKey: .startDate),
                  quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: try container.decode(Double.self, forKey: .quantity)))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(quantity.doubleValue(for: .milligramsPerDeciliter), forKey: .quantity)
    }

    private enum CodingKeys: String, CodingKey {
        case startDate
        case quantity
    }
}


extension GlucoseEffect: Comparable {
    public static func <(lhs: GlucoseEffect, rhs: GlucoseEffect) -> Bool {
        return lhs.startDate < rhs.startDate
    }
}

public extension Array where Element == GlucoseEffect {
    func asVelocities() -> [GlucoseEffectVelocity] {
        guard count > 1 else {
            return []
        }
        let unit = HKUnit.milligramsPerDeciliter
        var previousEffectValue: Double = first!.quantity.doubleValue(for: unit)
        var previousEffectDate: Date = first!.startDate

        var velocities = [GlucoseEffectVelocity]()

        for effect in dropFirst() {
            let value = effect.quantity.doubleValue(for: unit)
            let delta = value - previousEffectValue
            let timespan = effect.startDate.timeIntervalSince(previousEffectDate).minutes
            let velocity = delta / timespan

            velocities.append(GlucoseEffectVelocity(startDate: previousEffectDate, endDate: effect.startDate, quantity: HKQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: velocity)))

            previousEffectValue = value
            previousEffectDate = effect.startDate
        }

        return velocities
    }
}
