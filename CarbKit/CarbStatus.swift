//
//  CarbStatus.swift
//  LoopKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit


public struct CarbStatus {
    /// Details entered by the user
    public let entry: CarbEntry

    /// The last-computed absorption of the carbs
    public let absorption: AbsorbedCarbValue?

    /// The timeline of observed carb absorption. Nil if observed absorption is less than the modeled minimum
    public let observedTimeline: [CarbValue]?
}


// Masquerade as a carb entry, substituting AbsorbedCarbValue's interpretation of absorption time
extension CarbStatus: SampleValue {
    public var quantity: HKQuantity {
        return entry.quantity
    }

    public var startDate: Date {
        return entry.startDate
    }
}


extension CarbStatus: CarbEntry {
    public var foodType: String? {
        return entry.foodType
    }

    public var absorptionTime: TimeInterval? {
        return absorption?.estimatedDate.duration ?? entry.absorptionTime
    }

    public var createdByCurrentApp: Bool {
        return entry.createdByCurrentApp
    }

    public var isUploaded: Bool {
        return entry.isUploaded
    }

    public var externalID: String? {
        return entry.externalID
    }
}


extension CarbStatus {
    func dynamicCarbsOnBoard(at date: Date, defaultAbsorptionTime: TimeInterval, delay: TimeInterval, delta: TimeInterval) -> Double {
        guard date >= startDate - delta,
            let absorption = absorption
        else {
            // We have to have absorption info for dynamic calculation
            return entry.carbsOnBoard(at: date, defaultAbsorptionTime: defaultAbsorptionTime, delay: delay)
        }

        let unit = HKUnit.gram()

        guard let observedTimeline = observedTimeline else {
            // Less than minimum observed; calc based on min absorption rate
            let total = absorption.total.doubleValue(for: unit)
            let time = date.timeIntervalSince(startDate) - delay
            let absorptionTime = absorption.estimatedDate.duration

            return LinearCarbAbsorption.unabsorbedCarbs(of: total, atTime: time, absorptionTime: absorptionTime)
        }

        guard let end = observedTimeline.last?.endDate, date <= end else {
            // Predicted absorption for remaining carbs, post-observation
            let total = absorption.remaining.doubleValue(for: unit)
            let time = date.timeIntervalSince(absorption.observedDate.end)
            let absorptionTime = absorption.estimatedTimeRemaining

            return LinearCarbAbsorption.unabsorbedCarbs(of: total, atTime: time, absorptionTime: absorptionTime)
        }

        // Observed absorption
        // TODO: This creates an O(n^2) situation for COB timelines
        let total = entry.quantity.doubleValue(for: unit)
        return max(observedTimeline.filter({ $0.endDate <= date }).reduce(total) { (total, value) -> Double in
            return total - value.quantity.doubleValue(for: unit)
        }, 0)
    }

    func dynamicAbsorbedCarbs(at date: Date, absorptionTime: TimeInterval, delay: TimeInterval, delta: TimeInterval) -> Double {
        guard date >= startDate,
            let absorption = absorption
        else {
            // We have to have absorption info for dynamic calculation
            return entry.absorbedCarbs(at: date, absorptionTime: absorptionTime, delay: delay)
        }

        let unit = HKUnit.gram()

        guard let observedTimeline = observedTimeline else {
            // Less than minimum observed; calc based on min absorption rate
            let total = absorption.total.doubleValue(for: unit)
            let time = date.timeIntervalSince(startDate) - delay
            let absorptionTime = absorption.estimatedDate.duration

            return LinearCarbAbsorption.absorbedCarbs(of: total, atTime: time, absorptionTime: absorptionTime)
        }

        guard let end = observedTimeline.last?.endDate, date <= end else {
            // Predicted absorption for remaining carbs, post-observation
            let total = absorption.remaining.doubleValue(for: unit)
            let time = date.timeIntervalSince(absorption.observedDate.end)
            let absorptionTime = absorption.estimatedTimeRemaining

            return absorption.clamped.doubleValue(for: unit) + LinearCarbAbsorption.absorbedCarbs(of: total, atTime: time, absorptionTime: absorptionTime)
        }

        // Observed absorption
        // TODO: This creates an O(n^2) situation for carb effect timelines
        var sum: Double = 0
        var beforeDate = observedTimeline.filter { (value) -> Bool in
            value.startDate.addingTimeInterval(delta) <= date
        }

        // Apply only a portion of the value if it extends past the final value
        if let last = beforeDate.popLast() {
            let observationInterval = DateInterval(start: last.startDate, end: last.endDate)
            if  observationInterval.duration > 0,
                let calculationInterval = DateInterval(start: last.startDate, end: date).intersection(with: observationInterval)
            {
                sum += calculationInterval.duration / observationInterval.duration * last.quantity.doubleValue(for: unit)
            }
        }

        return min(beforeDate.reduce(sum) { (sum, value) -> Double in
            return sum + value.quantity.doubleValue(for: unit)
        }, quantity.doubleValue(for: unit))
    }
}
