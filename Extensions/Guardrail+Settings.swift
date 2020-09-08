//
//  Guardrail+Settings.swift
//  LoopKit
//
//  Created by Rick Pasetto on 7/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit

public extension Guardrail where Value == HKQuantity {
    static let correctionRange = Guardrail(absoluteBounds: 60...180, recommendedBounds: 70...120, unit: .milligramsPerDeciliter)

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

    static let suspendThreshold = Guardrail(absoluteBounds: 54...180, recommendedBounds: 71...120, unit: .milligramsPerDeciliter)

    static func maxSuspendThresholdValue(correctionRangeSchedule: GlucoseRangeSchedule?, preMealTargetRange: DoubleRange?, workoutTargetRange: DoubleRange?, unit: HKUnit) -> HKQuantity? {

        return [
            correctionRangeSchedule?.minLowerBound().doubleValue(for: unit),
            preMealTargetRange?.minValue,
            workoutTargetRange?.minValue
        ]
        .compactMap { $0 }
        .min()
        .map { HKQuantity(unit: unit, doubleValue: $0) }
    }

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

    static func correctionRangeOverride(for preset: CorrectionRangeOverrides.Preset, correctionRangeScheduleRange: ClosedRange<HKQuantity>) -> Guardrail {
        switch preset {
        case .preMeal:
            return Guardrail(
                absoluteBounds: correctionRange.absoluteBounds,
                recommendedBounds: correctionRange.recommendedBounds.lowerBound...max(correctionRangeScheduleRange.lowerBound, correctionRange.recommendedBounds.lowerBound)
            )
        case .workout:
            return Guardrail(
                absoluteBounds: correctionRange.absoluteBounds,
                recommendedBounds: max(correctionRange.recommendedBounds.lowerBound, correctionRangeScheduleRange.lowerBound)...correctionRange.absoluteBounds.upperBound
            )
        }
    }
}
