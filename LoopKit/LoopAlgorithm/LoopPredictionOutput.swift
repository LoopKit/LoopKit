//
//  LoopPredictionOutput.swift
//  LoopKit
//
//  Created by Pete Schwamb on 9/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation


public struct LoopAlgorithmOutput {
    public var predictedGlucose: [PredictedGlucoseValue]
    public var doseRecommendation: AutomaticDoseRecommendation
}

extension LoopAlgorithmOutput: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.predictedGlucose = try container.decode([PredictedGlucoseValue].self, forKey: .predictedGlucose)
        self.doseRecommendation = try container.decode(AutomaticDoseRecommendation.self, forKey: .doseRecommendation)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(predictedGlucose, forKey: .doseRecommendation)
        try container.encode(doseRecommendation, forKey: .doseRecommendation)
    }

    private enum CodingKeys: String, CodingKey {
        case predictedGlucose
        case doseRecommendation
    }
}

extension LoopAlgorithmOutput {

    public func printFixture() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(self),
           let json = String(data: data, encoding: .utf8)
        {
            print(json)
        }
    }
}
