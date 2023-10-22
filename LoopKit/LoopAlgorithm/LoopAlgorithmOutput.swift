//
//  LoopAlgorithmOutput.swift
//
//
//  Created by Pete Schwamb on 10/13/23.
//

import Foundation

public struct LoopAlgorithmOutput {
    public var doseRecommendation: LoopAlgorithmDoseRecommendation
    public var predictedGlucose: [PredictedGlucoseValue]
    public var effects: LoopAlgorithmEffects
    public var activeInsulin: Double
}
