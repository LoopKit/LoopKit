//
//  LoopAlgorithm.swift
//  Learn
//
//  Created by Pete Schwamb on 6/30/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public enum AlgorithmError: Error {
    case missingGlucose
    case incompleteSchedules
}

public struct LoopAlgorithmEffects {
    public var insulin: [GlucoseEffect]
    public var carbs: [GlucoseEffect]
    public var retrospectiveCorrection: [GlucoseEffect]
    public var momentum: [GlucoseEffect]
    public var insulinCounteraction: [GlucoseEffectVelocity]
}

public struct AlgorithmEffectSummary {
    let date: Date

    let netInsulinEffect: HKQuantity
//    let carbsOnBoard: Double // grams
    let insulinOnBoard: Double // IU
//    let momentumEffect: HKQuantity
//    let insulinCounteractionEffects: HKQuantity
//    let retrospectiveCorrection: HKQuantity

    public init(date: Date, netInsulinEffect: HKQuantity, insulinOnBoard: Double) {
        self.date = date
        self.netInsulinEffect = netInsulinEffect
        self.insulinOnBoard = insulinOnBoard
    }
}

public struct AlgorithmEffectsOptions: OptionSet {
    public let rawValue: UInt8

    public static let carbs            = AlgorithmEffectsOptions(rawValue: 1 << 0)
    public static let insulin          = AlgorithmEffectsOptions(rawValue: 1 << 1)
    public static let momentum         = AlgorithmEffectsOptions(rawValue: 1 << 2)
    public static let retrospection    = AlgorithmEffectsOptions(rawValue: 1 << 3)

    public static let all: AlgorithmEffectsOptions = [.carbs, .insulin, .momentum, .retrospection]

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
}

public struct AlgorithmEffectsTimeline {
    let summaries: [AlgorithmEffectSummary]

    public init(summaries: [AlgorithmEffectSummary]) {
        self.summaries = summaries
    }
}

public struct LoopPrediction: GlucosePrediction {
    public var glucose: [PredictedGlucoseValue]
    public var effects: LoopAlgorithmEffects
}

public actor LoopAlgorithm {

    public typealias InputType = LoopPredictionInput
    public typealias OutputType = LoopPrediction

    private static var treatmentHistoryInterval: TimeInterval = .hours(24)

    public static func treatmentHistoryDateInterval(for startDate: Date) -> DateInterval {
        return DateInterval(
            start: startDate.addingTimeInterval(-LoopAlgorithm.treatmentHistoryInterval).dateFlooredToTimeInterval(.minutes(5)),
            end: startDate)
    }

    public static func glucoseHistoryDateInterval(for startDate: Date) -> DateInterval {
        return DateInterval(
            start: startDate.addingTimeInterval(InsulinMath.defaultInsulinActivityDuration-LoopAlgorithm.treatmentHistoryInterval),
            end: startDate)
    }

    static var momentumDataInterval: TimeInterval = .minutes(15)

    // Generates a forecast predicting glucose.
    public static func getForecast(input: LoopPredictionInput, startDate: Date? = nil) throws -> LoopPrediction {

        guard let latestGlucose = input.glucoseHistory.last else {
            throw AlgorithmError.missingGlucose
        }

        let start = startDate ?? latestGlucose.startDate

        let insulinModelProvider = PresetInsulinModelProvider(defaultRapidActingModel: nil)

        let effectsInterval = DateInterval(
            start: Self.treatmentHistoryDateInterval(for: start).start,
            end: start.addingTimeInterval(input.insulinActivityDuration).dateCeiledToTimeInterval(input.delta)
        )

        // Overlay basal history on basal doses, splitting doses to get amount delivered relative to basal
        let annotatedDoses = input.doses.annotated(with: input.basal)

        let insulinEffects = annotatedDoses.glucoseEffects(
            insulinModelProvider: insulinModelProvider,
            longestEffectDuration: input.insulinActivityDuration,
            insulinSensitivityHistory: input.sensitivity,
            from: effectsInterval.start,
            to: effectsInterval.end)

        // Try calculating insulin effects at glucose sample timestamps. This should produce more accurate samples to compare against glucose.
//        let effectDates = input.glucoseHistory.map { $0.startDate }
//        let insulinEffectsAtGlucoseTimestamps = annotatedDoses.glucoseEffects(
//            insulinModelProvider: insulinModelProvider,
//            longestEffectDuration: input.insulinActivityDuration,
//            insulinSensitivityTimeline: input.sensitivity,
//            effectDates: effectDates)

        // ICE
        let insulinCounteractionEffects = input.glucoseHistory.counteractionEffects(to: insulinEffects)

        // Carb Effects
        let carbEffects = input.carbEntries.map(
            to: insulinCounteractionEffects,
            carbRatio: input.carbRatio,
            insulinSensitivity: input.sensitivity
        ).dynamicGlucoseEffects(
            carbRatios: input.carbRatio,
            insulinSensitivities: input.sensitivity
        )


        // RC
        let retrospectiveCorrectionGroupingInterval: TimeInterval = .minutes(30)
        let retrospectiveGlucoseDiscrepancies = insulinCounteractionEffects.subtracting(carbEffects)
        let retrospectiveGlucoseDiscrepanciesSummed = retrospectiveGlucoseDiscrepancies.combinedSums(of: retrospectiveCorrectionGroupingInterval * 1.01)

        let rc = StandardRetrospectiveCorrection(effectDuration: TimeInterval(hours: 1))

        guard let curSensitivity = input.sensitivity.closestPrior(to: start)?.value,
              let curBasal = input.basal.closestPrior(to: start)?.value,
              let curTarget = input.target.closestPrior(to: start)?.value else
        {
            throw AlgorithmError.incompleteSchedules
        }

        let rcEffect = rc.computeEffect(
            startingAt: latestGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: retrospectiveGlucoseDiscrepanciesSummed,
            recencyInterval: TimeInterval(minutes: 15),
            insulinSensitivity: curSensitivity,
            basalRate: curBasal,
            correctionRange: curTarget,
            retrospectiveCorrectionGroupingInterval: retrospectiveCorrectionGroupingInterval
        )

        var effects = [[GlucoseEffect]]()

        if input.algorithmEffectsOptions.contains(.carbs) {
            effects.append(carbEffects)
        }

        if input.algorithmEffectsOptions.contains(.insulin) {
            effects.append(insulinEffects)
        }

        if input.algorithmEffectsOptions.contains(.retrospection) {
            effects.append(rcEffect)
        }

        // Glucose Momentum
        let momentumEffects: [GlucoseEffect]
        if input.algorithmEffectsOptions.contains(.momentum) {
            let momentumInputData = input.glucoseHistory.filterDateRange(start.addingTimeInterval(-momentumDataInterval), start)
            momentumEffects = momentumInputData.linearMomentumEffect()
        } else {
            momentumEffects = []
        }

        let prediction = LoopMath.predictGlucose(startingAt: latestGlucose, momentum: momentumEffects, effects: effects)

//        print("**********")
//        print("carbEffects = \(carbEffects)")
//        print("retrospectiveGlucoseDiscrepancies = \(retrospectiveGlucoseDiscrepancies)")
//        print("rc = \(rcEffect)")

        return LoopPrediction(
            glucose: prediction,
            effects: LoopAlgorithmEffects(
                insulin: insulinEffects,
                carbs: carbEffects,
                retrospectiveCorrection: rcEffect,
                momentum: momentumEffects,
                insulinCounteraction: insulinCounteractionEffects
            )
        )
    }
}


