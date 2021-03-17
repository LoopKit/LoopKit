//
//  GlucoseRange.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2021-03-16.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public struct GlucoseRange {
    public let range: DoubleRange
    public let unit: HKUnit

    public init(minValue: Double, maxValue: Double, unit: HKUnit) {
        self.init(range: DoubleRange(minValue: minValue, maxValue: maxValue), unit: unit)
    }

    public init(range: DoubleRange, unit: HKUnit) {
        precondition(unit == .milligramsPerDeciliter || unit == .millimolesPerLiter)
        self.range = range
        self.unit = unit
    }

    public var isZero: Bool {
        return abs(range.minValue) < .ulpOfOne && abs(range.maxValue) < .ulpOfOne
    }

    public var quantityRange: ClosedRange<HKQuantity> {
        range.quantityRange(for: unit)
    }
}

extension GlucoseRange: Hashable {}

extension GlucoseRange: Equatable {}

extension GlucoseRange: RawRepresentable {
    public typealias RawValue = [String:Any]

    public init?(rawValue: RawValue) {
        guard let rawRange = rawValue["range"] as? DoubleRange.RawValue,
              let range = DoubleRange(rawValue: rawRange),
              let bloodGlucoseUnit = rawValue["bloodGlucoseUnit"] as? String else
        {
            return nil
        }
        self.range = range
        self.unit = HKUnit(from: bloodGlucoseUnit)
    }

    public var rawValue: RawValue {
        return [
            "range": range.rawValue,
            "bloodGlucoseUnit": unit.unitString
        ]
    }
}

extension GlucoseRange: Codable  {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        unit = HKUnit(from: try container.decode(String.self, forKey: .bloodGlucoseUnit))
        range = try container.decode(DoubleRange.self, forKey: .range)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(range, forKey: .range)
        try container.encode(unit.unitString, forKey: .bloodGlucoseUnit)
    }

    private enum CodingKeys: String, CodingKey {
        case bloodGlucoseUnit
        case range
    }
}
