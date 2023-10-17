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

public struct LoopPrediction {
    public var glucose: [PredictedGlucoseValue]
    public var effects: LoopAlgorithmEffects
}

public struct LoopAlgorithm {
    /// Percentage of recommended dose to apply as bolus when using automatic bolus dosing strategy
    static public let bolusPartialApplicationFactor = 0.4

    /// The duration of recommended temp basals
    static public let tempBasalDuration = TimeInterval(minutes: 30)

    /// The duration of time before an ongoing temp basal should be continued with a new command
    static public let tempBasalContinuationInterval = TimeInterval(minutes: 11)

    /// The amount of time since a given date that input data should be considered valid
    public static let inputDataRecencyInterval = TimeInterval(minutes: 15)

    static let insulinModelProvider = PresetInsulinModelProvider(defaultRapidActingModel: nil)

    /// Generates a forecast predicting glucose.
    ///
    /// Returns nil if the normal scheduled basal, or active temporary basal, is sufficient.
    ///
    /// - Parameters:
    ///   - predictionStart: The starting time of the glucose prediction, defaults to the sample time of the latest glucose sample provided.
    ///   - glucoseHistory: History of glucose values: t-10h to t. Must include at least one value.
    ///   - doses: History of insulin doses: t-16h to t
    ///   - carbEntries: History of carb entries: t-10h to t
    ///   - basal: Scheduled basal rate timeline: t-16h to t
    ///   - sensitivity: Insulin sensitivity timeline: t-16h to t (eventually with mid-absorption isf changes, it will be t-10h to t)
    ///   - carbRatio: Carb ratio timeline: t-10h to t+6h
    ///   - useIntegralRetrospectiveCorrection: Whether to use IRC (true) or RC (false)
    ///   - rateRounder: Closure that rounds recommendation to nearest supported rate. If nil, no rounding is performed
    ///   - isBasalRateScheduleOverrideActive: A flag describing whether a basal rate schedule override is in progress
    ///   - duration: The duration of the temporary basal
    ///   - continuationInterval: The duration of time before an ongoing temp basal should be continued with a new command
    /// - Returns: A LoopPrediction struct containing the predicted glucose and the computed intermediate effects used to make the prediction

    public static func generatePrediction(
        predictionStart: Date? = nil,
        glucoseHistory: [StoredGlucoseSample],
        doses: [DoseEntry],
        carbEntries: [StoredCarbEntry],
        basal: [AbsoluteScheduleValue<Double>],
        sensitivity: [AbsoluteScheduleValue<HKQuantity>],
        carbRatio: [AbsoluteScheduleValue<Double>],
        algorithmEffectsOptions: AlgorithmEffectsOptions = .all,
        useIntegralRetrospectiveCorrection: Bool = false
    ) -> LoopPrediction {

        guard let latestGlucose = glucoseHistory.last else {
            preconditionFailure("Must have at least one historical glucose value to make a prediction")
        }

        let start = predictionStart ?? latestGlucose.startDate

        if let doseStart = doses.first?.startDate {
            assert(!basal.isEmpty, "Missing basal history input.")
            let basalStart = basal.first!.startDate
            precondition(basalStart <= doseStart, "Basal history must cover historic dose range. First dose date: \(doseStart) > \(basalStart)")
        }

        // Overlay basal history on basal doses, splitting doses to get amount delivered relative to basal
        let annotatedDoses = doses.annotated(with: basal)

        let insulinEffects = annotatedDoses.glucoseEffects(
            insulinModelProvider: insulinModelProvider,
            insulinSensitivityHistory: sensitivity,
            from: start.addingTimeInterval(-CarbMath.maximumAbsorptionTimeInterval).dateFlooredToTimeInterval(GlucoseMath.defaultDelta),
            to: nil)

        // ICE
        let insulinCounteractionEffects = glucoseHistory.counteractionEffects(to: insulinEffects)

        // Carb Effects
        let carbEffects = carbEntries.map(
            to: insulinCounteractionEffects,
            carbRatio: carbRatio,
            insulinSensitivity: sensitivity
        ).dynamicGlucoseEffects(
            from: start.addingTimeInterval(-IntegralRetrospectiveCorrection.retrospectionInterval),
            carbRatios: carbRatio,
            insulinSensitivities: sensitivity
        )

        // RC
        let retrospectiveGlucoseDiscrepancies = insulinCounteractionEffects.subtracting(carbEffects)
        let retrospectiveGlucoseDiscrepanciesSummed = retrospectiveGlucoseDiscrepancies.combinedSums(of: LoopMath.retrospectiveCorrectionGroupingInterval * 1.01)

        let rc: RetrospectiveCorrection

        if useIntegralRetrospectiveCorrection {
            rc = IntegralRetrospectiveCorrection(effectDuration: LoopMath.retrospectiveCorrectionEffectDuration)
        } else {
            rc = StandardRetrospectiveCorrection(effectDuration: LoopMath.retrospectiveCorrectionEffectDuration)
        }

        let rcEffect = rc.computeEffect(
            startingAt: latestGlucose,
            retrospectiveGlucoseDiscrepanciesSummed: retrospectiveGlucoseDiscrepanciesSummed,
            recencyInterval: TimeInterval(minutes: 15),
            retrospectiveCorrectionGroupingInterval: LoopMath.retrospectiveCorrectionGroupingInterval
        )

        var effects = [[GlucoseEffect]]()

        if algorithmEffectsOptions.contains(.carbs) {
            effects.append(carbEffects)
        }

        if algorithmEffectsOptions.contains(.insulin) {
            effects.append(insulinEffects)
        }

        if algorithmEffectsOptions.contains(.retrospection) {
            effects.append(rcEffect)
        }

        // Glucose Momentum
        let momentumEffects: [GlucoseEffect]
        if algorithmEffectsOptions.contains(.momentum) {
            let momentumInputData = glucoseHistory.filterDateRange(start.addingTimeInterval(-GlucoseMath.momentumDataInterval), start)
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

    // Helper to generate prediction with LoopPredictionInput struct
    public static func generatePrediction(input: LoopPredictionInput) -> LoopPrediction {
        return generatePrediction(
            glucoseHistory: input.glucoseHistory,
            doses: input.doses,
            carbEntries: input.carbEntries,
            basal: input.basal,
            sensitivity: input.sensitivity,
            carbRatio: input.carbRatio,
            algorithmEffectsOptions: input.algorithmEffectsOptions,
            useIntegralRetrospectiveCorrection: input.useIntegralRetrospectiveCorrection)
    }

    // Computes an amount of insulin to correct the given prediction
    public static func insulinCorrection(
        prediction: LoopPrediction,
        at deliveryDate: Date,
        target: GlucoseRangeTimeline,
        suspendThreshold: HKQuantity,
        sensitivity: [AbsoluteScheduleValue<HKQuantity>],
        insulinType: InsulinType
    ) -> InsulinCorrection {
        let insulinModel = insulinModelProvider.model(for: insulinType)

        return prediction.glucose.insulinCorrection(
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
        scheduledBasalRate: Double,
        activeInsulin: Double,
        maxBolus: Double,
        maxBasalRate: Double,
        rateRounder: ((Double) -> Double)?,
        lastTempBasal: DoseEntry?,
        overrideIsActive: Bool
    ) -> TempBasalRecommendation? {

        var maxBasalRate = maxBasalRate

        // TODO: Allow `highBasalThreshold` to be a configurable setting
        if case .aboveRange(min: let min, correcting: _, minTarget: let highBasalThreshold, units: _) = correction,
            min.quantity < highBasalThreshold
        {
            maxBasalRate = scheduledBasalRate
        }

        // automaticDosingIOBLimit calculated from the user entered maxBolus
        let automaticDosingIOBLimit = maxBolus * 2.0
        let iobHeadroom = automaticDosingIOBLimit - activeInsulin

        let maxThirtyMinuteRateToKeepIOBBelowLimit = iobHeadroom * (TimeInterval.hours(1) / tempBasalDuration) + scheduledBasalRate  // 30 minutes of a U/hr rate
        maxBasalRate = Swift.min(maxThirtyMinuteRateToKeepIOBBelowLimit, maxBasalRate)

        let temp = correction.asTempBasal(
            scheduledBasalRate: scheduledBasalRate,
            maxBasalRate: maxBasalRate,
            duration: tempBasalDuration,
            rateRounder: rateRounder
        )

        return temp.ifNecessary(
            at: deliveryDate,
            scheduledBasalRate: scheduledBasalRate,
            lastTempBasal: lastTempBasal,
            continuationInterval: tempBasalContinuationInterval,
            scheduledBasalRateMatchesPump: !overrideIsActive
        )
    }

    // Computes a bolus or low-temp basal dose to correct the given prediction
    public static func recommendAutomaticDose(
        for correction: InsulinCorrection,
        at deliveryDate: Date,
        scheduledBasalRate: Double,
        activeInsulin: Double,
        maxBolus: Double,
        maxBasalRate: Double,
        rateRounder: ((Double) -> Double)?,
        volumeRounder: ((Double) -> Double)?,
        lastTempBasal: DoseEntry?,
        overrideIsActive: Bool
    ) -> AutomaticDoseRecommendation? {

        var maxAutomaticBolus = maxBolus * bolusPartialApplicationFactor

        if case .aboveRange(min: let min, correcting: _, minTarget: let doseThreshold, units: _) = correction,
            min.quantity < doseThreshold
        {
            maxAutomaticBolus = 0
        }

        var temp: TempBasalRecommendation? = correction.asTempBasal(
            scheduledBasalRate: scheduledBasalRate,
            maxBasalRate: scheduledBasalRate,
            duration: .minutes(30),
            rateRounder: rateRounder
        )

        temp = temp?.ifNecessary(
            at: deliveryDate,
            scheduledBasalRate: scheduledBasalRate,
            lastTempBasal: lastTempBasal,
            continuationInterval: tempBasalContinuationInterval,
            scheduledBasalRateMatchesPump: !overrideIsActive
        )

        let bolusUnits = correction.asPartialBolus(
            partialApplicationFactor: bolusPartialApplicationFactor,
            maxBolusUnits: maxAutomaticBolus,
            volumeRounder: volumeRounder
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
        return try run(input: input).doseRecommendation
    }

    public static func run(input: LoopAlgorithmInput) throws -> LoopAlgorithmOutput {

        guard let latestGlucose = input.glucoseHistory.last else {
            throw AlgorithmError.missingGlucose
        }

        guard input.predictionStart.timeIntervalSince(latestGlucose.startDate) < inputDataRecencyInterval else {
            throw AlgorithmError.glucoseTooOld
        }

        guard let scheduledBasalRate = input.basal.closestPrior(to: input.predictionStart)?.value else {
            throw AlgorithmError.basalTimelineIncomplete
        }

        let forecastEnd = input.predictionStart.addingTimeInterval(InsulinMath.defaultInsulinActivityDuration)

        guard let sensitivityEndDate = input.sensitivity.last?.endDate, sensitivityEndDate >= forecastEnd else {
            throw AlgorithmError.sensitivityTimelineIncomplete
        }

        let prediction = generatePrediction(
            predictionStart: input.predictionStart,
            glucoseHistory: input.glucoseHistory,
            doses: input.doses,
            carbEntries: input.carbEntries,
            basal: input.basal,
            sensitivity: input.sensitivity,
            carbRatio: input.carbRatio)

        guard let suspendThreshold = input.suspendThreshold ?? input.target.closestPrior(to: input.predictionStart)?.value.lowerBound else {
            throw AlgorithmError.missingSuspendThreshold
        }

        let correction = insulinCorrection(
            prediction: prediction,
            at: input.predictionStart,
            target: input.target,
            suspendThreshold: suspendThreshold,
            sensitivity: input.sensitivity,
            insulinType: input.recommendationInsulinType)

        let activeDoses = input.doses.filterDateRange (nil, input.predictionStart)
        let activeInsulin = activeDoses.insulinOnBoard(insulinModelProvider: insulinModelProvider, at: input.predictionStart)


        // Round to 0.05 values for now; maybe eventually precision can be specified in input struct/file
        let deliveryRounder = { (rate: Double) -> Double in
            let factor = 20.0
            return floor(rate * factor) / factor
        }

        let lastTempBasal = input.doses.first { $0.type == .tempBasal && $0.startDate < input.predictionStart && $0.endDate > input.predictionStart }

        let doseRecommendation: LoopAlgorithmDoseRecommendation

        switch input.recommendationType {
        case .manualBolus:
            let recommendation = recommendManualBolus(
                for: correction,
                maxBolus: input.maxBolus,
                currentGlucose: latestGlucose, 
                target: input.target)
            doseRecommendation = LoopAlgorithmDoseRecommendation(manualBolus: recommendation)
        case .automaticBolus:
            let recommendation = recommendAutomaticDose(
                for: correction,
                at: input.predictionStart,
                scheduledBasalRate: scheduledBasalRate,
                activeInsulin: activeInsulin,
                maxBolus: input.maxBolus,
                maxBasalRate: input.maxBasalRate,
                rateRounder: deliveryRounder,
                volumeRounder: deliveryRounder,
                lastTempBasal: lastTempBasal,
                overrideIsActive: false)
            doseRecommendation = LoopAlgorithmDoseRecommendation(automaticBolus: recommendation)
        case .tempBasal:
            let recommendation = recommendTempBasal(
                for: correction,
                at: input.predictionStart,
                scheduledBasalRate: scheduledBasalRate,
                activeInsulin: activeInsulin,
                maxBolus: input.maxBolus,
                maxBasalRate: input.maxBasalRate,
                rateRounder: deliveryRounder,
                lastTempBasal: lastTempBasal,
                overrideIsActive: false)
            doseRecommendation = LoopAlgorithmDoseRecommendation(tempBasal: recommendation)
        }

        return LoopAlgorithmOutput(
            doseRecommendation: doseRecommendation,
            predictedGlucose: prediction.glucose,
            effects: prediction.effects,
            activeInsulin: activeInsulin)
    }
}


