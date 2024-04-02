//
//  GlucoseEffect.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit
import LoopAlgorithm

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
