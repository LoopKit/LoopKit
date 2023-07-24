//
//  RetrospectiveCorrection.swift
//  Loop
//
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit


/// Derives a continued glucose effect from recent prediction discrepancies
public protocol RetrospectiveCorrection: CustomDebugStringConvertible {
    /// The maximum interval of historical glucose discrepancies that should be provided to the computation
    static var retrospectionInterval: TimeInterval { get }

    /// Overall retrospective correction effect
    var totalGlucoseCorrectionEffect: HKQuantity? { get }

    /// Calculates overall correction effect based on timeline of discrepancies, and updates glucoseCorrectionEffect
    ///
    /// - Parameters:
    ///   - startingAt: Initial glucose value
    ///   - retrospectiveGlucoseDiscrepanciesSummed: Timeline of past discepancies
    ///   - recencyInterval: how recent discrepancy data must be, otherwise effect will be cleared
    ///   - insulinSensitivity: Insulin sensitivity at time of initial glucose value
    ///   - basalRate: Basal rate at time of initial glucose value
    ///   - correctionRange: Correction range at time of initial glucose value
    ///   - retrospectiveCorrectionGroupingInterval: Duration of discrepancy measurements
    /// - Returns: Glucose correction effects
    func computeEffect(
        startingAt startingGlucose: GlucoseValue,
        retrospectiveGlucoseDiscrepanciesSummed: [GlucoseChange]?,
        recencyInterval: TimeInterval,
        insulinSensitivity: HKQuantity,
        basalRate: Double,
        correctionRange: ClosedRange<HKQuantity>,
        retrospectiveCorrectionGroupingInterval: TimeInterval
    ) -> [GlucoseEffect]
}
