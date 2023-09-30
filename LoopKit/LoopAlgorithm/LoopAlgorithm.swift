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

public struct LoopPrediction: GlucosePrediction {
    public var glucose: [PredictedGlucoseValue]
    public var effects: LoopAlgorithmEffects
}

public struct DoseRecommendation: Equatable {
    public let basalAdjustment: TempBasalRecommendation?
    public let bolusUnits: Double?

    public init(basalAdjustment: TempBasalRecommendation?, bolusUnits: Double? = nil) {
        self.basalAdjustment = basalAdjustment
        self.bolusUnits = bolusUnits
    }
}

public actor LoopAlgorithm {

    public typealias InputType = LoopPredictionInput
    public typealias OutputType = LoopPrediction

//    public static func generateRecommendation(input: LoopAlgorithmInput) throws -> DoseRecommendation {
//        let prediction = try generatePrediction(input: input.predictionInput, startDate: input.predictionDate)
//
//        switch input.doseRecommendationType {
//        case .manualBolus:
//            prediction.glucose.recommendedManualBolus(to: <#T##GlucoseRangeSchedule#>, suspendThreshold: <#T##HKQuantity?#>, sensitivity: <#T##InsulinSensitivitySchedule#>, model: <#T##InsulinModel#>, pendingInsulin: <#T##Double#>, maxBolus: <#T##Double#>)
//        case .automaticBolus:
//            <#code#>
//        case .tempBasal:
//            <#code#>
//        }
//    }

    // Generates a forecast predicting glucose.
    public static func generatePrediction(input: LoopPredictionInput, startDate: Date? = nil) throws -> LoopPrediction {

        guard let latestGlucose = input.glucoseHistory.last else {
            throw AlgorithmError.missingGlucose
        }

        let start = startDate ?? latestGlucose.startDate

        let insulinModelProvider = PresetInsulinModelProvider(defaultRapidActingModel: nil)

        let settings = input.settings

        if let doseStart = input.doses.first?.startDate {
            assert(!input.settings.basal.isEmpty, "Missing basal history input.")
            let basalStart = input.settings.basal.first!.startDate
            precondition(basalStart <= doseStart, "Basal history must cover historic dose range. First dose date: \(doseStart) < \(basalStart)")
        }

        // Overlay basal history on basal doses, splitting doses to get amount delivered relative to basal
        let annotatedDoses = input.doses.annotated(with: input.settings.basal)

        let insulinEffects = annotatedDoses.glucoseEffects(
            insulinModelProvider: insulinModelProvider,
            longestEffectDuration: settings.insulinActivityDuration,
            insulinSensitivityHistory: settings.sensitivity,
            from: start.addingTimeInterval(-CarbMath.maximumAbsorptionTimeInterval).dateFlooredToTimeInterval(settings.delta),
            to: nil)

        // ICE
        let insulinCounteractionEffects = input.glucoseHistory.counteractionEffects(to: insulinEffects)

        // Carb Effects
        let carbEffects = input.carbEntries.map(
            to: insulinCounteractionEffects,
            carbRatio: settings.carbRatio,
            insulinSensitivity: settings.sensitivity
        ).dynamicGlucoseEffects(
            from: start.addingTimeInterval(-IntegralRetrospectiveCorrection.retrospectionInterval),
            carbRatios: settings.carbRatio,
            insulinSensitivities: settings.sensitivity
        )

        // RC
        let retrospectiveGlucoseDiscrepancies = insulinCounteractionEffects.subtracting(carbEffects)
        let retrospectiveGlucoseDiscrepanciesSummed = retrospectiveGlucoseDiscrepancies.combinedSums(of: LoopMath.retrospectiveCorrectionGroupingInterval * 1.01)

        let rc: RetrospectiveCorrection

        if input.settings.useIntegralRetrospectiveCorrection {
            rc = IntegralRetrospectiveCorrection(effectDuration: LoopMath.retrospectiveCorrectionEffectDuration)
        } else {
            rc = StandardRetrospectiveCorrection(effectDuration: LoopMath.retrospectiveCorrectionEffectDuration)
        }

        guard let curSensitivity = settings.sensitivity.closestPrior(to: start)?.value,
              let curBasal = settings.basal.closestPrior(to: start)?.value,
              let curTarget = settings.target.closestPrior(to: start)?.value else
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
            retrospectiveCorrectionGroupingInterval: LoopMath.retrospectiveCorrectionGroupingInterval
        )

        var effects = [[GlucoseEffect]]()

        if settings.algorithmEffectsOptions.contains(.carbs) {
            effects.append(carbEffects)
        }

        if settings.algorithmEffectsOptions.contains(.insulin) {
            effects.append(insulinEffects)
        }

        if settings.algorithmEffectsOptions.contains(.retrospection) {
            effects.append(rcEffect)
        }

        // Glucose Momentum
        let momentumEffects: [GlucoseEffect]
        if settings.algorithmEffectsOptions.contains(.momentum) {
            let momentumInputData = input.glucoseHistory.filterDateRange(start.addingTimeInterval(-GlucoseMath.momentumDataInterval), start)
            momentumEffects = momentumInputData.linearMomentumEffect()
        } else {
            momentumEffects = []
        }

        var prediction = LoopMath.predictGlucose(startingAt: latestGlucose, momentum: momentumEffects, effects: effects)

        // Dosing requires prediction entries at least as long as the insulin model duration.
        // If our prediction is shorter than that, then extend it here.
        let finalDate = latestGlucose.startDate.addingTimeInterval(InsulinMath.defaultInsulinActivityDuration)
        if let last = prediction.last, last.startDate < finalDate {
            prediction.append(PredictedGlucoseValue(startDate: finalDate, quantity: last.quantity))
        }

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


