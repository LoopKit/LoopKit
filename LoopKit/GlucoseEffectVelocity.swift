//
//  GlucoseEffectVelocity.swift
//  LoopKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit


/// The first-derivative of GlucoseEffect, blood glucose over time.
public struct GlucoseEffectVelocity: SampleValue {
    public let startDate: Date
    public let endDate: Date
    public let quantity: HKQuantity

    public init(startDate: Date, endDate: Date, quantity: HKQuantity) {
        self.startDate = startDate
        self.endDate = endDate
        self.quantity = quantity
    }
}


extension GlucoseEffectVelocity {
    static let perSecondUnit = HKUnit.milligramsPerDeciliter.unitDivided(by: .second())

    /// The integration of the velocity span
    public var effect: GlucoseEffect {
        let duration = endDate.timeIntervalSince(startDate)
        let velocityPerSecond = quantity.doubleValue(for: GlucoseEffectVelocity.perSecondUnit)

        return GlucoseEffect(
            startDate: endDate,
            quantity: HKQuantity(
                unit: .milligramsPerDeciliter,
                doubleValue: velocityPerSecond * duration
            )
        )
    }
}
