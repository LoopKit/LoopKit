//
//  BolusRecommendation.swift
//  LoopKit
//
//  Created by Pete Schwamb on 1/2/17.
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public enum BolusRecommendationNotice {
    case glucoseBelowSuspendThreshold(minGlucose: GlucoseValue)
    case currentGlucoseBelowTarget(glucose: GlucoseValue)
    case predictedGlucoseBelowTarget(minGlucose: GlucoseValue)
}

extension BolusRecommendationNotice: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodableKeys.self)
        if let glucoseBelowSuspendThreshold = try container.decodeIfPresent(GlucoseBelowSuspendThreshold.self, forKey: .glucoseBelowSuspendThreshold) {
            self = .glucoseBelowSuspendThreshold(minGlucose: glucoseBelowSuspendThreshold.minGlucose)
        } else if let currentGlucoseBelowTarget = try container.decodeIfPresent(CurrentGlucoseBelowTarget.self, forKey: .currentGlucoseBelowTarget) {
            self = .currentGlucoseBelowTarget(glucose: currentGlucoseBelowTarget.glucose)
        } else if let predictedGlucoseBelowTarget = try container.decodeIfPresent(PredictedGlucoseBelowTarget.self, forKey: .predictedGlucoseBelowTarget) {
            self = .predictedGlucoseBelowTarget(minGlucose: predictedGlucoseBelowTarget.minGlucose)
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "invalid enumeration"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .glucoseBelowSuspendThreshold(let minGlucose):
            var container = encoder.container(keyedBy: CodableKeys.self)
            try container.encode(GlucoseBelowSuspendThreshold(minGlucose: SimpleGlucoseValue(minGlucose)), forKey: .glucoseBelowSuspendThreshold)
        case .currentGlucoseBelowTarget(let glucose):
            var container = encoder.container(keyedBy: CodableKeys.self)
            try container.encode(CurrentGlucoseBelowTarget(glucose: SimpleGlucoseValue(glucose)), forKey: .currentGlucoseBelowTarget)
        case .predictedGlucoseBelowTarget(let minGlucose):
            var container = encoder.container(keyedBy: CodableKeys.self)
            try container.encode(PredictedGlucoseBelowTarget(minGlucose: SimpleGlucoseValue(minGlucose)), forKey: .predictedGlucoseBelowTarget)
        }
    }

    private struct GlucoseBelowSuspendThreshold: Codable {
        let minGlucose: SimpleGlucoseValue
    }

    private struct CurrentGlucoseBelowTarget: Codable {
        let glucose: SimpleGlucoseValue
    }

    private struct PredictedGlucoseBelowTarget: Codable {
        let minGlucose: SimpleGlucoseValue
    }

    private enum CodableKeys: String, CodingKey {
        case glucoseBelowSuspendThreshold
        case currentGlucoseBelowTarget
        case predictedGlucoseBelowTarget
    }
}

public struct BolusRecommendation {
    public let amount: Double
    public let pendingInsulin: Double
    public var notice: BolusRecommendationNotice?

    public init(amount: Double, pendingInsulin: Double, notice: BolusRecommendationNotice? = nil) {
        self.amount = amount
        self.pendingInsulin = pendingInsulin
        self.notice = notice
    }
}

extension BolusRecommendation: Codable {}
