//
//  LoopAlgorithmOutput.swift
//
//
//  Created by Pete Schwamb on 10/13/23.
//

import Foundation
import HealthKit

public struct LoopAlgorithmOutput {
    public var recommendationResult: Result<LoopAlgorithmDoseRecommendation,Error>
    public var predictedGlucose: [PredictedGlucoseValue]
    public var effects: LoopAlgorithmEffects
    public var dosesRelativeToBasal: [DoseEntry]
    public var activeInsulin: Double?
    public var activeCarbs: Double?

    public init(
        recommendationResult: Result<LoopAlgorithmDoseRecommendation, Error>,
        predictedGlucose: [PredictedGlucoseValue],
        effects: LoopAlgorithmEffects,
        dosesRelativeToBasal: [DoseEntry],
        activeInsulin: Double? = nil,
        activeCarbs: Double? = nil
    ) {
        self.recommendationResult = recommendationResult
        self.predictedGlucose = predictedGlucose
        self.effects = effects
        self.dosesRelativeToBasal = dosesRelativeToBasal
        self.activeInsulin = activeInsulin
        self.activeCarbs = activeCarbs
    }

    public var recommendation: LoopAlgorithmDoseRecommendation? {
        switch recommendationResult {
        case .success(let rec):
            return rec
        case .failure:
            return nil
        }
    }
}
