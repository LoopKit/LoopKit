//
//  Guardrail+Settings.swift
//  LoopKit
//
//  Created by Rick Pasetto on 7/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit

public extension Guardrail where Value == HKQuantity {
    static let suspendThreshold = Guardrail(absoluteBounds: 67...110, recommendedBounds: 74...80, unit: .milligramsPerDeciliter)

    static func maxSuspendThresholdValue(correctionRangeSchedule: GlucoseRangeSchedule?, preMealTargetRange: ClosedRange<HKQuantity>?, workoutTargetRange: ClosedRange<HKQuantity>?) -> HKQuantity {

        return [
            suspendThreshold.absoluteBounds.upperBound,
            correctionRangeSchedule?.minLowerBound(),
            preMealTargetRange?.lowerBound,
            workoutTargetRange?.lowerBound
        ]
        .compactMap { $0 }
        .min()!
    }

    static let correctionRange = Guardrail(absoluteBounds: 87...180, recommendedBounds: 101...115, unit: .milligramsPerDeciliter)

    static func minCorrectionRangeValue(suspendThreshold: GlucoseThreshold?) -> HKQuantity {
        return [
            correctionRange.absoluteBounds.lowerBound,
            suspendThreshold?.quantity
        ]
        .compactMap { $0 }
        .max()!
    }
    
    fileprivate static func workoutCorrectionRange(correctionRangeScheduleRange: ClosedRange<HKQuantity>,
                                                   suspendThreshold: GlucoseThreshold?) -> Guardrail<HKQuantity> {
        // Static "unconstrained" constant values before applying constraints
        let workoutCorrectionRange = Guardrail(absoluteBounds: 85...250, recommendedBounds: 101...180, unit: .milligramsPerDeciliter)
        
        let absoluteLowerBound = [
            workoutCorrectionRange.absoluteBounds.lowerBound,
            suspendThreshold?.quantity
        ]
        .compactMap { $0 }
        .max()!
        let recommmendedLowerBound = max(absoluteLowerBound, correctionRangeScheduleRange.upperBound)
        return Guardrail(
            absoluteBounds: absoluteLowerBound...workoutCorrectionRange.absoluteBounds.upperBound,
            recommendedBounds: recommmendedLowerBound...workoutCorrectionRange.recommendedBounds.upperBound
        )
    }
    
    fileprivate static func preMealCorrectionRange(correctionRangeScheduleRange: ClosedRange<HKQuantity>,
                                                   suspendThreshold: GlucoseThreshold?) -> Guardrail<HKQuantity> {
        let premealCorrectionRangeMaximum = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 130.0)
        let absoluteLowerBound = suspendThreshold?.quantity ?? Guardrail.suspendThreshold.absoluteBounds.lowerBound
        return Guardrail(
            absoluteBounds: absoluteLowerBound...premealCorrectionRangeMaximum,
            recommendedBounds: absoluteLowerBound...min(max(absoluteLowerBound, correctionRangeScheduleRange.lowerBound), premealCorrectionRangeMaximum)
        )
    }
    
    static func correctionRangeOverride(for preset: CorrectionRangeOverrides.Preset,
                                        correctionRangeScheduleRange: ClosedRange<HKQuantity>,
                                        suspendThreshold: GlucoseThreshold?) -> Guardrail {
        
        switch preset {
        case .workout:
            return workoutCorrectionRange(correctionRangeScheduleRange: correctionRangeScheduleRange, suspendThreshold: suspendThreshold)
        case .preMeal:
            return preMealCorrectionRange(correctionRangeScheduleRange: correctionRangeScheduleRange, suspendThreshold: suspendThreshold)
        }
    }
    
    static let insulinSensitivity = Guardrail(
        absoluteBounds: 10...500,
        recommendedBounds: 16...399,
        unit: HKUnit.milligramsPerDeciliter.unitDivided(by: .internationalUnit())
    )

    static let carbRatio = Guardrail(
        absoluteBounds: 1...150,
        recommendedBounds: 3.0.nextUp...28.0.nextDown,
        unit: .gramsPerUnit
    )

    static func basalRate(supportedBasalRates: [Double]) -> Guardrail {
        let recommendedLowerBound = supportedBasalRates.first == 0
            ? supportedBasalRates.dropFirst().first!
            : supportedBasalRates.first!
        return Guardrail(
            absoluteBounds: supportedBasalRates.first!...supportedBasalRates.last!,
            recommendedBounds: recommendedLowerBound...supportedBasalRates.last!,
            unit: .internationalUnitsPerHour
        )
    }

    static var recommendedMaximumScheduledBasalScaleFactor: Double {
        return 6
    }

    static func maximumBasalRate(
        supportedBasalRates: [Double],
        scheduledBasalRange: ClosedRange<Double>?,
        maximumBasalRatePrecision decimalPlaces: Int = 3
    ) -> Guardrail {
        let minimumSupportedBasalRate = supportedBasalRates.first!
        let recommendedLowerBound = minimumSupportedBasalRate == 0 ? supportedBasalRates.dropFirst().first! : minimumSupportedBasalRate
        let recommendedUpperBound: Double
        if let maximumScheduledBasalRate = scheduledBasalRange?.upperBound {
            let scaledMaximumScheduledBasalRate = (recommendedMaximumScheduledBasalScaleFactor * maximumScheduledBasalRate).matchingOrTruncatedValue(from: supportedBasalRates, withinDecimalPlaces: decimalPlaces)
            recommendedUpperBound = maximumScheduledBasalRate == 0
                ? recommendedLowerBound
                : scaledMaximumScheduledBasalRate
        } else {
            recommendedUpperBound = supportedBasalRates.last!
        }
        return Guardrail(
            absoluteBounds: supportedBasalRates.first!...supportedBasalRates.last!,
            recommendedBounds: recommendedLowerBound...recommendedUpperBound,
            unit: .internationalUnitsPerHour
        )
    }

    static func maximumBolus(supportedBolusVolumes: [Double]) -> Guardrail {
        let maxBolusWarningThresholdUnits: Double = 20
        let minimumSupportedBolusVolume = supportedBolusVolumes.first!
        let recommendedLowerBound = minimumSupportedBolusVolume == 0 ? supportedBolusVolumes.dropFirst().first! : minimumSupportedBolusVolume
        let recommendedUpperBound = min(maxBolusWarningThresholdUnits.nextDown, supportedBolusVolumes.last!)
        return Guardrail(
            absoluteBounds: supportedBolusVolumes.first!...supportedBolusVolumes.last!,
            recommendedBounds: recommendedLowerBound...recommendedUpperBound,
            unit: .internationalUnit()
        )
    }
}
