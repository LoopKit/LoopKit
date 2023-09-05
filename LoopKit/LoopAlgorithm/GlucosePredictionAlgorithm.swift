//
//  GlucosePredictionAlgorithm.swift
//  Learn
//
//  Created by Pete Schwamb on 7/22/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol GlucosePredictionInput {
    var glucoseHistory: [StoredGlucoseSample] { get }
    var doses: [DoseEntry] { get }
    var carbEntries: [StoredCarbEntry] { get }
}

public protocol GlucosePrediction {
    var glucose: [PredictedGlucoseValue] { get }
}

public protocol GlucosePredictionAlgorithm {
    associatedtype InputType: GlucosePredictionInput
    associatedtype OutputType: GlucosePrediction

    static func generatePrediction(input: InputType, startDate: Date?) throws -> OutputType
}


extension LoopAlgorithm: GlucosePredictionAlgorithm {}
