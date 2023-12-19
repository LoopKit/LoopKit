//
//  LoopAlgorithmInput.swift
//  LoopKit
//
//  Created by Pete Schwamb on 9/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public enum AlgorithmInputDecodingError: Error {
    case invalidDoseRecommendationType
    case invalidInsulinType
    case doseRateMissing
    case doseVolumeMissing
}

public struct LoopAlgorithmInput {
    public var predictionStart: Date
    public var glucoseHistory: [StoredGlucoseSample]
    public var doses: [DoseEntry]
    public var carbEntries: [StoredCarbEntry]
    public var basal: [AbsoluteScheduleValue<Double>]
    public var sensitivity: [AbsoluteScheduleValue<HKQuantity>]
    public var carbRatio: [AbsoluteScheduleValue<Double>]
    public var target: GlucoseRangeTimeline
    public var suspendThreshold: HKQuantity?
    public var maxBolus: Double
    public var maxBasalRate: Double
    public var useIntegralRetrospectiveCorrection: Bool
    public var includePositiveVelocityAndRC: Bool
    public var carbAbsorptionModel: CarbAbsorptionModel = .piecewiseLinear
    public var recommendationInsulinType: InsulinType = .novolog
    public var recommendationType: DoseRecommendationType = .automaticBolus
    public var automaticBolusApplicationFactor: Double?

    struct TargetEntry: Codable {
        var startDate: Date
        var endDate: Date
        var lowerBound: Double
        var upperBound: Double
    }

    struct Dose: Codable {
        var startDate: Date
        var endDate: Date?
        var volume: Double?
        var type: DoseType
        var insulinType: String?
    }

    struct Glucose {
        var value: Double
        var isCalibration: Bool
        var date: Date
    }

    struct CarbEntry: Codable {
        var grams: Double
        var absorptionTime: TimeInterval?
        var date: Date
    }

    public init(
        predictionStart: Date,
        glucoseHistory: [StoredGlucoseSample],
        doses: [DoseEntry],
        carbEntries: [StoredCarbEntry],
        basal: [AbsoluteScheduleValue<Double>],
        sensitivity: [AbsoluteScheduleValue<HKQuantity>],
        carbRatio: [AbsoluteScheduleValue<Double>],
        target: GlucoseRangeTimeline,
        suspendThreshold: HKQuantity?,
        maxBolus: Double,
        maxBasalRate: Double,
        useIntegralRetrospectiveCorrection: Bool = false,
        includePositiveVelocityAndRC: Bool = true,
        carbAbsorptionModel: CarbAbsorptionModel = .piecewiseLinear,
        recommendationInsulinType: InsulinType,
        recommendationType: DoseRecommendationType,
        automaticBolusApplicationFactor: Double? = nil
    ) {
        self.predictionStart = predictionStart
        self.glucoseHistory = glucoseHistory
        self.doses = doses
        self.carbEntries = carbEntries
        self.basal = basal
        self.sensitivity = sensitivity
        self.carbRatio = carbRatio
        self.target = target
        self.suspendThreshold = suspendThreshold
        self.maxBolus = maxBolus
        self.maxBasalRate = maxBasalRate
        self.useIntegralRetrospectiveCorrection = useIntegralRetrospectiveCorrection
        self.includePositiveVelocityAndRC = includePositiveVelocityAndRC
        self.carbAbsorptionModel = carbAbsorptionModel
        self.recommendationInsulinType = recommendationInsulinType
        self.recommendationType = recommendationType
        self.automaticBolusApplicationFactor = automaticBolusApplicationFactor
    }
}

extension LoopAlgorithmInput.Glucose: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.value = try container.decode(Double.self, forKey: .value)
        self.isCalibration = try container.decodeIfPresent(Bool.self, forKey: .isCalibration) ?? false
        self.date = try container.decode(Date.self, forKey: .date)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(value, forKey: .value)
        if isCalibration {
            try container.encode(isCalibration, forKey: .isCalibration)
        }
        try container.encode(date, forKey: .date)

    }

    private enum CodingKeys: String, CodingKey {
        case value
        case isCalibration
        case date
    }
}


extension LoopAlgorithmInput: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.predictionStart = try container.decode(Date.self, forKey: .predictionStart)
        let glucose = try container.decode([Glucose].self, forKey: .glucoseHistory)
        self.glucoseHistory = glucose.map { sample in
            StoredGlucoseSample(
                startDate: sample.date,
                quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: sample.value),
                isDisplayOnly: sample.isCalibration
            )
        }
        let doses = try container.decode([Dose].self, forKey: .doses)
        self.doses = try doses.map({ dose in
            let value: Double
            let unit: DoseUnit
            switch dose.type {
            case .basal, .tempBasal, .bolus:
                guard let decodedVolume = dose.volume else {
                    throw AlgorithmInputDecodingError.doseVolumeMissing
                }
                value = decodedVolume
                unit = .units
            default:
                value = 0
                unit = .units
                break
            }
            let insulinType: InsulinType?
            if let insulinTypeIdentifier = dose.insulinType {
                guard let decodedInsulinType = InsulinType(with: insulinTypeIdentifier) else {
                    throw AlgorithmInputDecodingError.invalidInsulinType
                }
                insulinType = decodedInsulinType
            } else {
                insulinType = nil
            }
            return DoseEntry(type: dose.type, startDate: dose.startDate, endDate: dose.endDate, value: value, unit: unit, insulinType: insulinType)
        })
        let carbEntries = try container.decode([CarbEntry].self, forKey: .carbEntries)
        self.carbEntries = carbEntries.map { entry in
            StoredCarbEntry(
                startDate: entry.date,
                quantity: HKQuantity(unit: .gram(), doubleValue: entry.grams),
                absorptionTime: entry.absorptionTime
            )
        }
        self.basal = try container.decode([AbsoluteScheduleValue<Double>].self, forKey: .basal)
        let sensitivityMgdl = try container.decode([AbsoluteScheduleValue<Double>].self, forKey: .sensitivity)
        self.sensitivity = sensitivityMgdl.map { AbsoluteScheduleValue(startDate: $0.startDate, endDate: $0.endDate, value: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: $0.value))}
        self.carbRatio = try container.decode([AbsoluteScheduleValue<Double>].self, forKey: .carbRatio)
        let targetMgdl = try container.decode([TargetEntry].self, forKey: .target)
        self.target = targetMgdl.map {
            let lower = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: $0.lowerBound)
            let upper = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: $0.upperBound)
            let range = ClosedRange(uncheckedBounds: (lower: lower, upper: upper))
            return AbsoluteScheduleValue(startDate: $0.startDate, endDate: $0.endDate, value: range)
        }
        if let suspendThresholdMgdl = try container.decodeIfPresent(Double.self, forKey: .suspendThreshold) {
            self.suspendThreshold = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: suspendThresholdMgdl)
        }
        self.maxBolus = try container.decode(Double.self, forKey: .maxBolus)
        self.maxBasalRate = try container.decode(Double.self, forKey: .maxBasalRate)
        self.useIntegralRetrospectiveCorrection = try container.decodeIfPresent(Bool.self, forKey: .useIntegralRetrospectiveCorrection) ?? false
        self.includePositiveVelocityAndRC = try container.decodeIfPresent(Bool.self, forKey: .includePositiveVelocityAndRC) ?? true

        if let rawRecommendationInsulinType = try container.decodeIfPresent(String.self, forKey: .recommendationInsulinType) {
            guard let decodedRecommendationInsulinType = InsulinType(with: rawRecommendationInsulinType) else {
                throw AlgorithmInputDecodingError.invalidDoseRecommendationType
            }
            self.recommendationInsulinType = decodedRecommendationInsulinType
        } else {
            self.recommendationInsulinType = .novolog
        }

        if let rawRecommendationType = try container.decodeIfPresent(String.self, forKey: .recommendationType) {
            guard let decodedRecommendationType = DoseRecommendationType(rawValue: rawRecommendationType) else {
                throw AlgorithmInputDecodingError.invalidDoseRecommendationType
            }
            self.recommendationType = decodedRecommendationType
        } else {
            self.recommendationType = .automaticBolus
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(predictionStart, forKey: .predictionStart)
        try container.encode(glucoseHistory, forKey: .glucoseHistory)
        let glucose = glucoseHistory.map { sample in
            return Glucose(
                value: sample.quantity.doubleValue(for: .milligramsPerDeciliter),
                isCalibration: sample.isDisplayOnly,
                date: sample.startDate)
        }
        try container.encode(glucose, forKey: .glucoseHistory)
        let doses = doses.map { dose in
            switch dose.type {
            case .basal, .tempBasal, .bolus:
                return Dose(
                    startDate: dose.startDate,
                    endDate: dose.endDate,
                    volume: dose.deliveredUnits ?? dose.programmedUnits,
                    type: dose.type,
                    insulinType: dose.insulinType?.identifierForAlgorithmInput)
            default:
                return Dose(startDate: dose.startDate, endDate: dose.endDate, type: dose.type, insulinType: dose.insulinType?.identifierForAlgorithmInput)
            }
        }
        try container.encode(doses, forKey: .doses)
        let carbEntries = carbEntries.map { entry in
            CarbEntry(
                grams: entry.quantity.doubleValue(for: .gram()),
                absorptionTime: entry.absorptionTime,
                date: entry.startDate)
        }
        try container.encode(carbEntries, forKey: .carbEntries)
        try container.encode(basal, forKey: .basal)
        let sensitivityMgdl = sensitivity.map { AbsoluteScheduleValue(startDate: $0.startDate, endDate: $0.endDate, value: $0.value.doubleValue(for: .milligramsPerDeciliter)) }
        try container.encode(sensitivityMgdl, forKey: .sensitivity)
        try container.encode(carbRatio, forKey: .carbRatio)
        let targetMgdl = target.map {
            let lower = $0.value.lowerBound.doubleValue(for: .milligramsPerDeciliter)
            let upper = $0.value.upperBound.doubleValue(for: .milligramsPerDeciliter)
            return TargetEntry(startDate: $0.startDate, endDate: $0.endDate, lowerBound: lower, upperBound: upper)
        }
        try container.encode(targetMgdl, forKey: .target)
        try container.encode(suspendThreshold?.doubleValue(for: .milligramsPerDeciliter), forKey: .suspendThreshold)
        try container.encode(maxBolus, forKey: .maxBolus)
        try container.encode(maxBasalRate, forKey: .maxBasalRate)
        if useIntegralRetrospectiveCorrection {
            try container.encode(useIntegralRetrospectiveCorrection, forKey: .useIntegralRetrospectiveCorrection)
        }
        if !includePositiveVelocityAndRC {
            try container.encode(includePositiveVelocityAndRC, forKey: .includePositiveVelocityAndRC)
        }
        try container.encode(recommendationInsulinType.identifierForAlgorithmInput, forKey: .recommendationInsulinType)
        try container.encode(recommendationType.rawValue, forKey: .recommendationType)

    }

    private enum CodingKeys: String, CodingKey {
        case predictionStart
        case glucoseHistory
        case doses
        case carbEntries
        case basal
        case sensitivity
        case carbRatio
        case target
        case suspendThreshold
        case maxBolus
        case maxBasalRate
        case useIntegralRetrospectiveCorrection
        case includePositiveVelocityAndRC
        case recommendationInsulinType
        case recommendationType
    }
}


// Default Codable implementation for insulin type is int, which is not very readable.  Add more readable identifier
extension InsulinType {
    var identifierForAlgorithmInput: String {
        switch self {
        case .afrezza:
            return "afrezza"
        case .novolog:
            return "novolog"
        case .humalog:
            return "humalog"
        case .apidra:
            return "apidra"
        case .fiasp:
            return "fiasp"
        case .lyumjev:
            return "lyumjev"
        }
    }

    init?(with algorithmInputIdentifier: String) {
        switch algorithmInputIdentifier {
        case "afrezza":
            self = .afrezza
        case "novolog":
            self = .novolog
        case "humalog":
            self = .humalog
        case "apidra":
            self = .apidra
        case "fiasp":
            self = .fiasp
        case "lyumjev":
            self = .lyumjev
        default:
            return nil
        }
    }
}


extension LoopAlgorithmInput {

    var simplifiedForFixture: LoopAlgorithmInput {
        return LoopAlgorithmInput(
            predictionStart: predictionStart,
            glucoseHistory: glucoseHistory,
            doses: doses,
            carbEntries: carbEntries.map {
                StoredCarbEntry(startDate: $0.startDate, quantity: $0.quantity, absorptionTime: $0.absorptionTime)
            },
            basal: basal,
            sensitivity: sensitivity,
            carbRatio: carbRatio,
            target: target,
            suspendThreshold: suspendThreshold,
            maxBolus: maxBolus,
            maxBasalRate: maxBasalRate,
            useIntegralRetrospectiveCorrection: useIntegralRetrospectiveCorrection,
            recommendationInsulinType: recommendationInsulinType,
            recommendationType: recommendationType
        )
    }

    public func printFixture() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(self.simplifiedForFixture),
           let json = String(data: data, encoding: .utf8)
        {
            print(json)
        }
    }
}
