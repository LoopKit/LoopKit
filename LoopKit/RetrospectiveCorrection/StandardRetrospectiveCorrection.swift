//
//  StandardRetrospectiveCorrection.swift
//  Loop
//
//  Created by Dragan Maksimovic on 10/27/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

/**
 Standard Retrospective Correction (RC) calculates a correction effect in glucose prediction based on the most recent discrepancy between observed glucose movement and movement expected based on insulin and carb models. Standard retrospective correction acts as a proportional (P) controller aimed at reducing modeling errors in glucose prediction.
 
 In the above summary, "discrepancy" is a difference between the actual glucose and the model predicted glucose over retrospective correction grouping interval (set to 30 min in LoopSettings)
 */
public class StandardRetrospectiveCorrection: RetrospectiveCorrection {
    public static let retrospectionInterval = TimeInterval(minutes: 30)

    /// RetrospectiveCorrection protocol variables
    /// Standard effect duration
    let effectDuration: TimeInterval
    /// Overall retrospective correction effect
    public var totalGlucoseCorrectionEffect: HKQuantity?

    /// All math is performed with glucose expressed in mg/dL
    private let unit = HKUnit.milligramsPerDeciliter

    public init(effectDuration: TimeInterval) {
        self.effectDuration = effectDuration
    }

    public func computeEffect(
        startingAt startingGlucose: GlucoseValue,
        retrospectiveGlucoseDiscrepanciesSummed: [GlucoseChange]?,
        recencyInterval: TimeInterval,
        insulinSensitivity: HKQuantity,
        basalRate: Double,
        correctionRange: ClosedRange<HKQuantity>,
        retrospectiveCorrectionGroupingInterval: TimeInterval
    ) -> [GlucoseEffect] {
        // Last discrepancy should be recent, otherwise clear the effect and return
        let glucoseDate = startingGlucose.startDate
        guard let currentDiscrepancy = retrospectiveGlucoseDiscrepanciesSummed?.last,
            glucoseDate.timeIntervalSince(currentDiscrepancy.endDate) <= recencyInterval
        else {
            totalGlucoseCorrectionEffect = nil
            return []
        }
        
        // Standard retrospective correction math
        let currentDiscrepancyValue = currentDiscrepancy.quantity.doubleValue(for: unit)
        totalGlucoseCorrectionEffect = HKQuantity(unit: unit, doubleValue: currentDiscrepancyValue)
        
        let retrospectionTimeInterval = currentDiscrepancy.endDate.timeIntervalSince(currentDiscrepancy.startDate)
        let discrepancyTime = max(retrospectionTimeInterval, retrospectiveCorrectionGroupingInterval)
        let velocity = HKQuantity(unit: unit.unitDivided(by: .second()), doubleValue: currentDiscrepancyValue / discrepancyTime)
        
        // Update array of glucose correction effects
        return startingGlucose.decayEffect(atRate: velocity, for: effectDuration)
    }

    public var debugDescription: String {
        let report: [String] = [
            "## StandardRetrospectiveCorrection",
            ""
        ]

        return report.joined(separator: "\n")
    }
}
