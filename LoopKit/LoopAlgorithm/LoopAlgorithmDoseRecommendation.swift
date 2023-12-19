//
//  LoopAlgorithmDoseRecommendation.swift
//  LoopKit
//
//  Created by Pete Schwamb on 10/11/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation

public struct LoopAlgorithmDoseRecommendation: Equatable {

    public var manual: ManualBolusRecommendation?
    public var automatic: AutomaticDoseRecommendation?

    public init(manual: ManualBolusRecommendation? = nil, automatic: AutomaticDoseRecommendation? = nil) {
        self.manual = manual
        self.automatic = automatic
    }
}

extension LoopAlgorithmDoseRecommendation: Codable {}

extension LoopAlgorithmDoseRecommendation {
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
