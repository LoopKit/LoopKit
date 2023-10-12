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
    public var suspendThreshold: GlucoseThreshold
    public var maxBolus: Double
    public var maxBasalRate: Double
    public var useIntegralRetrospectiveCorrection: Bool = false
    public var recommendationInsulinType: InsulinType = .novolog
    public var recommendationType: DoseRecommendationType = .automaticBolus
}

extension LoopAlgorithmInput: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.predictionStart = try container.decode(Date.self, forKey: .predictionStart)
        self.glucoseHistory = try container.decode([StoredGlucoseSample].self, forKey: .glucoseHistory)
        self.doses = try container.decode([DoseEntry].self, forKey: .doses)
        self.carbEntries = try container.decode([StoredCarbEntry].self, forKey: .carbEntries)
        self.basal = try container.decode([AbsoluteScheduleValue<Double>].self, forKey: .basal)
        let sensitivityMgdl = try container.decode([AbsoluteScheduleValue<Double>].self, forKey: .sensitivity)
        self.sensitivity = sensitivityMgdl.map { AbsoluteScheduleValue(startDate: $0.startDate, endDate: $0.endDate, value: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: $0.value))}
        self.carbRatio = try container.decode([AbsoluteScheduleValue<Double>].self, forKey: .carbRatio)
        let targetMgdl = try container.decode([AbsoluteScheduleValue<ClosedRange<Double>>].self, forKey: .target)
        self.target = targetMgdl.map {
            let lower = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: $0.value.lowerBound)
            let upper = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: $0.value.upperBound)
            let range = ClosedRange(uncheckedBounds: (lower: lower, upper: upper))
            return AbsoluteScheduleValue(startDate: $0.startDate, endDate: $0.endDate, value: range)
        }
        self.suspendThreshold = try container.decode(GlucoseThreshold.self, forKey: .suspendThreshold)
        self.maxBolus = try container.decode(Double.self, forKey: .maxBolus)
        self.maxBasalRate = try container.decode(Double.self, forKey: .maxBasalRate)
        self.useIntegralRetrospectiveCorrection = try container.decodeIfPresent(Bool.self, forKey: .useIntegralRetrospectiveCorrection) ?? false

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
        try container.encode(doses, forKey: .doses)
        try container.encode(carbEntries, forKey: .carbEntries)
        try container.encode(basal, forKey: .basal)
        let sensitivityMgdl = sensitivity.map { AbsoluteScheduleValue(startDate: $0.startDate, endDate: $0.endDate, value: $0.value.doubleValue(for: .milligramsPerDeciliter)) }
        try container.encode(sensitivityMgdl, forKey: .sensitivity)
        try container.encode(carbRatio, forKey: .carbRatio)
        let targetMgdl = target.map {
            let lower = $0.value.lowerBound.doubleValue(for: .milligramsPerDeciliter)
            let upper = $0.value.upperBound.doubleValue(for: .milligramsPerDeciliter)
            let range = ClosedRange(uncheckedBounds: (lower: lower, upper: upper) )
            return AbsoluteScheduleValue(startDate: $0.startDate, endDate: $0.endDate, value: range)
        }
        try container.encode(targetMgdl, forKey: .target)
        try container.encode(suspendThreshold, forKey: .suspendThreshold)
        try container.encode(maxBolus, forKey: .maxBolus)
        try container.encode(maxBasalRate, forKey: .maxBasalRate)
        if useIntegralRetrospectiveCorrection {
            try container.encode(useIntegralRetrospectiveCorrection, forKey: .useIntegralRetrospectiveCorrection)
        }
        try container.encode(recommendationInsulinType, forKey: .recommendationInsulinType)
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
