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
    case glucoseTooOld
    case basalTimelineIncomplete
    case missingSuspendThreshold
    case sensitivityTimelineIncomplete
}

public struct LoopAlgorithmEffects {
    public var insulin: [GlucoseEffect]
    public var carbs: [GlucoseEffect]
    public var carbStatus: [CarbStatus<StoredCarbEntry>]
    public var retrospectiveCorrection: [GlucoseEffect]
    public var momentum: [GlucoseEffect]
    public var insulinCounteraction: [GlucoseEffectVelocity]
    public var retrospectiveGlucoseDiscrepancies: [GlucoseChange]
    public var totalGlucoseCorrectionEffect: HKQuantity?

    public init(
        insulin: [GlucoseEffect],
        carbs: [GlucoseEffect],
        carbStatus: [CarbStatus<StoredCarbEntry>],
        retrospectiveCorrection: [GlucoseEffect],
        momentum: [GlucoseEffect],
        insulinCounteraction: [GlucoseEffectVelocity],
        retrospectiveGlucoseDiscrepancies: [GlucoseChange],
        totalGlucoseCorrectionEffect: HKQuantity? = nil
    ) {
        self.insulin = insulin
        self.carbs = carbs
        self.carbStatus = carbStatus
        self.retrospectiveCorrection = retrospectiveCorrection
        self.momentum = momentum
        self.insulinCounteraction = insulinCounteraction
        self.retrospectiveGlucoseDiscrepancies = retrospectiveGlucoseDiscrepancies
        self.totalGlucoseCorrectionEffect = totalGlucoseCorrectionEffect
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

public struct LoopPrediction {
    public var glucose: [PredictedGlucoseValue]
    public var effects: LoopAlgorithmEffects
    public var dosesRelativeToBasal: [DoseEntry]
    public var activeInsulin: Double?
    public var activeCarbs: Double?
}

public struct LoopAlgorithm {
    /// Percentage of recommended dose to apply as bolus when using automatic bolus dosing strategy
    static public let defaultBolusPartialApplicationFactor = 0.4

    /// The duration of recommended temp basals
    static public let tempBasalDuration = TimeInterval(minutes: 30)

    /// The amount of time since a given date that input data should be considered valid
    public static let inputDataRecencyInterval = TimeInterval(minutes: 15)

    public static let insulinModelProvider = PresetInsulinModelProvider(defaultRapidActingModel: nil)

    /// Generates a forecast predicting glucose.
    ///
    /// Returns nil if the normal scheduled basal, or active temporary basal, is sufficient.
    ///
    /// - Parameters:
    ///   - start: The starting time of the glucose prediction.
    ///   - glucoseHistory: History of glucose values: t-10h to t. Must include at least one value.
    ///   - doses: History of insulin doses: t-16h to t
    ///   - carbEntries: History of carb entries: t-10h to t
    ///   - basal: Scheduled basal rate timeline: t-16h to t
    ///   - sensitivity: Insulin sensitivity timeline: t-16h to t (eventually with mid-absorption isf changes, it will be t-10h to t)
    ///   - carbRatio: Carb ratio timeline: t-10h to t+6h
    ///   - algorithmEffectsOptions: Which effects to include when combining effects to generate glucose prediction
    ///   - useIntegralRetrospectiveCorrection: If true, the prediction will use Integral Retrospection. If false, will use traditional Retrospective Correction
    ///   - includingPositiveVelocityAndRC: If false, only net negative momentum and RC effects will used.
    ///   - carbAbsorptionModel: A model conforming to CarbAbsorptionComputable that is used for computing carb absorption over time.
    /// - Returns: A LoopPrediction struct containing the predicted glucose and the computed intermediate effects used to make the prediction

    public static func generatePrediction(
        start: Date,
        glucoseHistory: [StoredGlucoseSample],
        doses: [DoseEntry],
        carbEntries: [StoredCarbEntry],
        basal: [AbsoluteScheduleValue<Double>],
        sensitivity: [AbsoluteScheduleValue<HKQuantity>],
        carbRatio: [AbsoluteScheduleValue<Double>],
        algorithmEffectsOptions: AlgorithmEffectsOptions = .all,
        useIntegralRetrospectiveCorrection: Bool = false,
        includingPositiveVelocityAndRC: Bool = true,
        carbAbsorptionModel: CarbAbsorptionComputable = PiecewiseLinearAbsorption()
    ) -> LoopPrediction {

        var prediction: [PredictedGlucoseValue] = []
        var insulinEffects: [GlucoseEffect] = []
        var carbEffects: [GlucoseEffect] = []
        var retrospectiveCorrectionEffects: [GlucoseEffect] = []
        var momentumEffects: [GlucoseEffect] = []
        var insulinCounteractionEffects: [GlucoseEffectVelocity] = []
        var retrospectiveGlucoseDiscrepanciesSummed: [GlucoseChange] = []
        var totalGlucoseCorrectionEffect: HKQuantity?
        var activeInsulin: Double?
        var activeCarbs: Double?
        var carbStatus: [CarbStatus<StoredCarbEntry>] = []
        var dosesRelativeToBasal: [DoseEntry] = []

        // Ensure basal history covers doses
        if let doseStart = doses.first?.startDate, !basal.isEmpty, basal.first!.startDate <= doseStart {
            // Overlay basal history on basal doses, splitting doses to get amount delivered relative to basal
            dosesRelativeToBasal = doses.annotated(with: basal)

            insulinEffects = dosesRelativeToBasal.glucoseEffects(
                insulinModelProvider: insulinModelProvider,
                insulinSensitivityHistory: sensitivity,
                from: start.addingTimeInterval(-CarbMath.maximumAbsorptionTimeInterval).dateFlooredToTimeInterval(GlucoseMath.defaultDelta),
                to: nil)

            activeInsulin = dosesRelativeToBasal.insulinOnBoard(insulinModelProvider: insulinModelProvider, at: start)

            // ICE
            insulinCounteractionEffects = glucoseHistory.counteractionEffects(to: insulinEffects)
        } else {
            activeInsulin = 0
        }

        // Carb Effects
        carbStatus = carbEntries.map(
            to: insulinCounteractionEffects,
            carbRatio: carbRatio,
            insulinSensitivity: sensitivity
        )

        carbEffects = carbStatus.dynamicGlucoseEffects(
            from: start.addingTimeInterval(-IntegralRetrospectiveCorrection.retrospectionInterval),
            carbRatios: carbRatio,
            insulinSensitivities: sensitivity,
            absorptionModel: carbAbsorptionModel
        )

        activeCarbs = carbStatus.dynamicCarbsOnBoard(at: start, absorptionModel: carbAbsorptionModel)

        // RC
        let retrospectiveGlucoseDiscrepancies = insulinCounteractionEffects.subtracting(carbEffects)
        retrospectiveGlucoseDiscrepanciesSummed = retrospectiveGlucoseDiscrepancies.combinedSums(of: LoopMath.retrospectiveCorrectionGroupingInterval * 1.01)

        let rc: RetrospectiveCorrection

        if useIntegralRetrospectiveCorrection {
            rc = IntegralRetrospectiveCorrection(effectDuration: LoopMath.retrospectiveCorrectionEffectDuration)
        } else {
            rc = StandardRetrospectiveCorrection(effectDuration: LoopMath.retrospectiveCorrectionEffectDuration)
        }

        if let latestGlucose = glucoseHistory.last {
            retrospectiveCorrectionEffects = rc.computeEffect(
                startingAt: latestGlucose,
                retrospectiveGlucoseDiscrepanciesSummed: retrospectiveGlucoseDiscrepanciesSummed,
                recencyInterval: TimeInterval(minutes: 15),
                retrospectiveCorrectionGroupingInterval: LoopMath.retrospectiveCorrectionGroupingInterval
            )

            totalGlucoseCorrectionEffect = rc.totalGlucoseCorrectionEffect

            var effects = [[GlucoseEffect]]()

            if algorithmEffectsOptions.contains(.carbs) {
                effects.append(carbEffects)
            }

            if algorithmEffectsOptions.contains(.insulin) {
                effects.append(insulinEffects)
            }

            if algorithmEffectsOptions.contains(.retrospection) {
                if !includingPositiveVelocityAndRC, let netRC = retrospectiveCorrectionEffects.netEffect(), netRC.quantity.doubleValue(for: .milligramsPerDeciliter) > 0 {
                    // positive RC is turned off
                } else {
                    effects.append(retrospectiveCorrectionEffects)
                }
            }

            // Glucose Momentum
            var useMomentum: Bool = true
            if algorithmEffectsOptions.contains(.momentum) {
                let momentumInputData = glucoseHistory.filterDateRange(start.addingTimeInterval(-GlucoseMath.momentumDataInterval), start)
                momentumEffects = momentumInputData.linearMomentumEffect()
                if !includingPositiveVelocityAndRC, let netMomentum = momentumEffects.netEffect(), netMomentum.quantity.doubleValue(for: .milligramsPerDeciliter) > 0 {
                    // positive momentum is turned off
                    useMomentum = false
                }
            } else {
                useMomentum = false
            }

            prediction = LoopMath.predictGlucose(
                startingAt: latestGlucose,
                momentum: useMomentum ? momentumEffects : [],
                effects: effects
            )

            // Dosing requires prediction entries at least as long as the insulin model duration.
            // If our prediction is shorter than that, then extend it here.
            let finalDate = latestGlucose.startDate.addingTimeInterval(InsulinMath.defaultInsulinActivityDuration)
            if let last = prediction.last, last.startDate < finalDate {
                prediction.append(PredictedGlucoseValue(startDate: finalDate, quantity: last.quantity))
            }
        }

        return LoopPrediction(
            glucose: prediction,
            effects: LoopAlgorithmEffects(
                insulin: insulinEffects,
                carbs: carbEffects,
                carbStatus: carbStatus,
                retrospectiveCorrection: retrospectiveCorrectionEffects,
                momentum: momentumEffects,
                insulinCounteraction: insulinCounteractionEffects,
                retrospectiveGlucoseDiscrepancies: retrospectiveGlucoseDiscrepanciesSummed,
                totalGlucoseCorrectionEffect: totalGlucoseCorrectionEffect
            ), 
            dosesRelativeToBasal: dosesRelativeToBasal,
            activeInsulin: activeInsulin,
            activeCarbs: activeCarbs
        )
    }

    // Helper to generate prediction with LoopPredictionInput struct
    public static func generatePrediction(input: LoopPredictionInput) -> LoopPrediction {

        return generatePrediction(
            start: input.glucoseHistory.last?.startDate ?? Date(),
            glucoseHistory: input.glucoseHistory,
            doses: input.doses,
            carbEntries: input.carbEntries,
            basal: input.basal,
            sensitivity: input.sensitivity,
            carbRatio: input.carbRatio,
            algorithmEffectsOptions: input.algorithmEffectsOptions,
            useIntegralRetrospectiveCorrection: input.useIntegralRetrospectiveCorrection,
            carbAbsorptionModel: input.carbAbsorptionModel.model
        )
    }

    // Computes an amount of insulin to correct the given prediction
    public static func insulinCorrection(
        prediction: [PredictedGlucoseValue],
        at deliveryDate: Date,
        target: GlucoseRangeTimeline,
        suspendThreshold: HKQuantity,
        sensitivity: [AbsoluteScheduleValue<HKQuantity>],
        insulinType: InsulinType
    ) -> InsulinCorrection {
        let insulinModel = insulinModelProvider.model(for: insulinType)

        return prediction.insulinCorrection(
            to: target,
            at: deliveryDate,
            suspendThreshold: suspendThreshold,
            insulinSensitivity: sensitivity,
            model: insulinModel)
    }

    // Computes a 30 minute temp basal dose to correct the given prediction
    public static func recommendTempBasal(
        for correction: InsulinCorrection,
        at deliveryDate: Date,
        neutralBasalRate: Double,
        activeInsulin: Double,
        maxBolus: Double,
        maxBasalRate: Double
    ) -> TempBasalRecommendation? {

        var maxBasalRate = maxBasalRate

        // TODO: Allow `highBasalThreshold` to be a configurable setting
        if case .aboveRange(min: let min, correcting: _, minTarget: let highBasalThreshold, units: _) = correction,
            min.quantity < highBasalThreshold
        {
            maxBasalRate = neutralBasalRate
        }

        // Enforce max IOB, calculated from the user entered maxBolus
        let automaticDosingIOBLimit = maxBolus * 2.0
        let iobHeadroom = automaticDosingIOBLimit - activeInsulin

        let maxThirtyMinuteRateToKeepIOBBelowLimit = iobHeadroom * (TimeInterval.hours(1) / tempBasalDuration) + neutralBasalRate  // 30 minutes of a U/hr rate
        maxBasalRate = Swift.min(maxThirtyMinuteRateToKeepIOBBelowLimit, maxBasalRate)

        return correction.asTempBasal(
            neutralBasalRate: neutralBasalRate,
            maxBasalRate: maxBasalRate,
            duration: tempBasalDuration
        )
    }

    // Computes a bolus or low-temp basal dose to correct the given prediction
    public static func recommendAutomaticDose(
        for correction: InsulinCorrection,
        at deliveryDate: Date,
        applicationFactor: Double,
        neutralBasalRate: Double,
        activeInsulin: Double,
        maxBolus: Double,
        maxBasalRate: Double
    ) -> AutomaticDoseRecommendation? {


        let deliveryHeadroom = max(0, maxBolus * 2.0 - activeInsulin)

        var deliveryMax = min(maxBolus * applicationFactor, deliveryHeadroom)

        if case .aboveRange(min: let min, correcting: _, minTarget: let minTarget, units: _) = correction,
            min.quantity < minTarget
        {
            deliveryMax = 0
        }

        let temp: TempBasalRecommendation? = correction.asTempBasal(
            neutralBasalRate: neutralBasalRate,
            maxBasalRate: neutralBasalRate,
            duration: .minutes(30)
        )

        let bolusUnits = correction.asPartialBolus(
            partialApplicationFactor: applicationFactor,
            maxBolusUnits: deliveryMax
        )

        if temp != nil || bolusUnits > 0 {
            return AutomaticDoseRecommendation(basalAdjustment: temp, bolusUnits: bolusUnits)
        }

        return nil
    }

    // Computes a manual bolus to correct the given prediction
    public static func recommendManualBolus(
        for correction: InsulinCorrection,
        maxBolus: Double,
        currentGlucose: StoredGlucoseSample,
        target: GlucoseRangeTimeline
    ) -> ManualBolusRecommendation {
        var bolus = correction.asManualBolus(maxBolus: maxBolus)

        if let targetAtCurrentGlucose = target.closestPrior(to: currentGlucose.startDate),
           currentGlucose.quantity < targetAtCurrentGlucose.value.lowerBound
        {
            bolus.notice = .currentGlucoseBelowTarget(glucose: currentGlucose)
        }

        return bolus
    }

    public static func recommendDose(input: LoopAlgorithmInput) throws -> LoopAlgorithmDoseRecommendation {
        let output = run(input: input)
        switch output.recommendationResult {
        case .success(let recommendation):
            return recommendation
        case .failure(let error):
            throw error
        }
    }

    public static func run(input: LoopAlgorithmInput, effectOptions: AlgorithmEffectsOptions = .all) -> LoopAlgorithmOutput {

        // If we're running for automated dosing, we calculate a dose assuming that the current temp basal will be canceled
        let inputDoses: [DoseEntry]

        if input.recommendationType.automated {
            inputDoses = input.doses.trimmed(to: input.predictionStart, onlyTrimTempBasals: true)
        } else {
            inputDoses = input.doses
        }

        // `generatePrediction` does a best-try to generate a prediction and associated effects.
        // Outputs may be incomplete, if there are issues with the provided data.
        // Assertions of data completeness/recency for dosing will be checked after.
        // This is so we can communicate/visualize state to the user even if we can't make a dosing recommendation.

        let prediction = generatePrediction(
            start: input.predictionStart,
            glucoseHistory: input.glucoseHistory,
            doses: inputDoses,
            carbEntries: input.carbEntries,
            basal: input.basal,
            sensitivity: input.sensitivity,
            carbRatio: input.carbRatio,
            algorithmEffectsOptions: .all,
            useIntegralRetrospectiveCorrection: input.useIntegralRetrospectiveCorrection,
            includingPositiveVelocityAndRC: input.includePositiveVelocityAndRC,
            carbAbsorptionModel: input.carbAbsorptionModel.model
        )

        // Now validate/recommend
        let result: Result<LoopAlgorithmDoseRecommendation,Error>

        do {
            guard let latestGlucose = input.glucoseHistory.last else {
                throw AlgorithmError.missingGlucose
            }

            guard input.predictionStart.timeIntervalSince(latestGlucose.startDate) < inputDataRecencyInterval else {
                throw AlgorithmError.glucoseTooOld
            }

            let forecastEnd = input.predictionStart.addingTimeInterval(InsulinMath.defaultInsulinActivityDuration)

            guard let sensitivityEndDate = input.sensitivity.last?.endDate, sensitivityEndDate >= forecastEnd else {
                throw AlgorithmError.sensitivityTimelineIncomplete
            }

            guard let scheduledBasalRate = input.basal.closestPrior(to: input.predictionStart)?.value else {
                throw AlgorithmError.basalTimelineIncomplete
            }

            guard let suspendThreshold = input.suspendThreshold ?? input.target.closestPrior(to: input.predictionStart)?.value.lowerBound else {
                throw AlgorithmError.missingSuspendThreshold
            }

            // TODO: This is to be removed when implementing mid-absorption ISF changes
            // This sets a single ISF value for the duration of the dose.
            let correctionSensitivity = [input.sensitivity.first { $0.startDate <= input.predictionStart && $0.endDate >= input.predictionStart }!]

            let correction = insulinCorrection(
                prediction: prediction.glucose,
                at: input.predictionStart,
                target: input.target,
                suspendThreshold: suspendThreshold,
                sensitivity: correctionSensitivity,
                insulinType: input.recommendationInsulinType)

            switch input.recommendationType {
            case .manualBolus:
                let recommendation = recommendManualBolus(
                    for: correction,
                    maxBolus: input.maxBolus,
                    currentGlucose: latestGlucose,
                    target: input.target)
                result = .success(.init(manual: recommendation))
            case .automaticBolus:
                let recommendation = recommendAutomaticDose(
                    for: correction,
                    at: input.predictionStart,
                    applicationFactor: input.automaticBolusApplicationFactor ?? defaultBolusPartialApplicationFactor,
                    neutralBasalRate: scheduledBasalRate,
                    activeInsulin: prediction.activeInsulin!,
                    maxBolus: input.maxBolus,
                    maxBasalRate: input.maxBasalRate)
                result = .success(.init(automatic: recommendation))
            case .tempBasal:
                let recommendation = recommendTempBasal(
                    for: correction,
                    at: input.predictionStart,
                    neutralBasalRate: scheduledBasalRate,
                    activeInsulin: prediction.activeInsulin!,
                    maxBolus: input.maxBolus,
                    maxBasalRate: input.maxBasalRate)
                result = .success(.init(automatic: AutomaticDoseRecommendation(basalAdjustment: recommendation)))
            }
        } catch {
            result = .failure(error)
        }

        return LoopAlgorithmOutput(
            recommendationResult: result,
            predictedGlucose: prediction.glucose,
            effects: prediction.effects,
            dosesRelativeToBasal: prediction.dosesRelativeToBasal,
            activeInsulin: prediction.activeInsulin,
            activeCarbs: prediction.activeCarbs
        )
    }
}

