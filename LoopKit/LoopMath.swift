//
//  LoopMath.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit
import LoopAlgorithm

extension BidirectionalCollection where Element == GlucoseEffect {

    /// Returns the net effect of a portion of receiver as a GlucoseChange object
    ///
    /// Requires the receiver to be sorted chronologically by endDate
    ///
    /// - Returns: A single GlucoseChange representing the net effect
    public func netEffect(after startDate: Date) -> GlucoseChange? {
        guard count > 1 else {
            return nil
        }

        guard var startingEffectIndex = firstIndex(where: { $0.startDate > startDate } ) else {
            return nil
        }

        if startingEffectIndex > startIndex {
            startingEffectIndex = index(before: startingEffectIndex)
        }

        let firstEffect = self[startingEffectIndex]

        let net = last!.quantity.doubleValue(for: .milligramsPerDeciliter) - firstEffect.quantity.doubleValue(for: .milligramsPerDeciliter)

        return GlucoseChange(startDate: firstEffect.startDate, endDate: last!.endDate, quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: net))
    }
}
