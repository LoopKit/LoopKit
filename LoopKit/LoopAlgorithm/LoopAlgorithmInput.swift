//
//  LoopAlgorithmInput.swift
//  LoopKit
//
//  Created by Pete Schwamb on 9/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public enum DoseRecommendationType: String {
    case manualBolus
    case automaticBolus
    case tempBasal
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
    public var algorithmEffectsOptions: AlgorithmEffectsOptions
    public var useIntegralRetrospectiveCorrection: Bool = false
    public var recommendedDoseInsulinType: InsulinType
    public var recommendationType: DoseRecommendationType = .automaticBolus
}
