//
//  CorrectionRangeOverrides.swift
//  LoopKit
//
//  Created by Rick Pasetto on 7/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import Foundation
import LoopAlgorithm

public struct CorrectionRangeOverrides: Equatable {
    public enum Preset: Hashable, CaseIterable {
        case preMeal
    }

    public var ranges: [Preset: ClosedRange<LoopQuantity>]

    public init(preMeal: DoubleRange?, unit: LoopUnit) {
        ranges = [:]
        ranges[.preMeal] = preMeal?.quantityRange(for: unit)
    }

    public init(preMeal: GlucoseRange?) {
        ranges = [:]
        ranges[.preMeal] = preMeal?.quantityRange
    }

    public init(
        preMeal: ClosedRange<LoopQuantity>?
    ) {
        ranges = [:]
        ranges[.preMeal] = preMeal
    }


    public var preMeal: ClosedRange<LoopQuantity>? { ranges[.preMeal] }
}

extension CorrectionRangeOverrides: Codable {
    fileprivate var codingGlucoseUnit: LoopUnit {
        return .milligramsPerDeciliter
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let preMealGlucoseRange = try container.decodeIfPresent(GlucoseRange.self, forKey: .preMealRange)

        self.ranges = [:]
        self.ranges[.preMeal] = preMealGlucoseRange?.quantityRange
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let preMealGlucoseRange = preMeal?.glucoseRange(for: codingGlucoseUnit)
        try container.encodeIfPresent(preMealGlucoseRange, forKey: .preMealRange)
    }

    private enum CodingKeys: String, CodingKey {
        case preMealRange
        case bloodGlucoseUnit
    }
}

extension CorrectionRangeOverrides: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        ranges = [:]
        if let rawPreMealTargetRange = rawValue["preMealTargetRange"] as? GlucoseRange.RawValue {
            ranges[.preMeal] = GlucoseRange(rawValue: rawPreMealTargetRange)?.quantityRange
        }
    }

    public var rawValue: RawValue {
        var raw: RawValue = [:]
        let preMealTargetGlucoseRange = preMeal?.glucoseRange(for: codingGlucoseUnit)
        raw["preMealTargetRange"] = preMealTargetGlucoseRange?.rawValue

        return raw
    }
}

extension ClosedRange<LoopQuantity> {
    public func localizedDescription(unit: LoopUnit) -> String {
        String(format: NSLocalizedString("%.0f - %.0f %3$@", comment: ""), lowerBound.doubleValue(for: unit), upperBound.doubleValue(for: unit), unit.unitString)
    }

    public func selectableValues(unit: LoopUnit, stride: Double = 1.0) -> [Double] {
        let lower = lowerBound.doubleValue(for: unit)
        let upper = upperBound.doubleValue(for: unit)

        // Generate values that are aligned to stride from zero
        let minIndex = Int(floor(lower / stride))
        let maxIndex = Int(ceil(upper / stride))

        var selectableValues = (minIndex...maxIndex)
            .map { Double($0) * stride }
            .filter { $0 >= lower && $0 <= upper }

        // Ensure lower and upper bounds are included explicitly (in case they’re not exactly on stride)
        if !selectableValues.contains(where: { abs($0 - lower) < 0.0001 }) {
            selectableValues.insert(lower, at: 0)
        }
        if !selectableValues.contains(where: { abs($0 - upper) < 0.0001 }) {
            selectableValues.append(upper)
        }

        return selectableValues;
    }
}

