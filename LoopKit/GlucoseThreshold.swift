//
//  GlucoseThreshold.swift
//  Loop
//
//  Created by Pete Schwamb on 1/1/17.
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public struct GlucoseThreshold: Equatable, RawRepresentable {
    public typealias RawValue = [String: Any]

    public let value: Double
    public let unit: HKUnit

    public var quantity: HKQuantity {
        return HKQuantity(unit: unit, doubleValue: value)
    }

    public init(unit: HKUnit, value: Double) {
        self.value = value
        self.unit = unit
    }

    public init?(rawValue: RawValue) {
        guard let unitsStr = rawValue["units"] as? String, let value = rawValue["value"] as? Double else {
            return nil
        }
        self.unit = HKUnit(from: unitsStr)
        self.value = value
    }

    public var rawValue: RawValue {
        return [
            "value": value,
            "units": unit.unitString
        ]
    }

    public func convertTo(unit: HKUnit) -> GlucoseThreshold {
        guard unit != self.unit else {
            return self
        }

        let convertedValue = self.quantity.doubleValue(for: unit)

        return GlucoseThreshold(unit: unit,
                                value: convertedValue)
    }
}

extension GlucoseThreshold: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.value = try container.decode(Double.self, forKey: .value)
        self.unit = HKUnit(from: try container.decode(String.self, forKey: .unit))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(unit.unitString, forKey: .unit)
    }

    private enum CodingKeys: String, CodingKey {
        case value
        case unit
    }
}
