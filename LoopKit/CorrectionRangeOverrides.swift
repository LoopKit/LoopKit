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
        case workout
    }

    public var ranges: [Preset: ClosedRange<LoopQuantity>]
    public var workoutDuration: TemporaryScheduleOverride.Duration?

    public init(preMeal: DoubleRange?, workout: DoubleRange?, unit: LoopUnit) {
        ranges = [:]
        ranges[.preMeal] = preMeal?.quantityRange(for: unit)
        ranges[.workout] = workout?.quantityRange(for: unit)
    }

    public init(preMeal: GlucoseRange?, workout: GlucoseRange?) {
        ranges = [:]
        ranges[.preMeal] = preMeal?.quantityRange
        ranges[.workout] = workout?.quantityRange
    }

    public init(
        preMeal: ClosedRange<LoopQuantity>?,
        workout: ClosedRange<LoopQuantity>?,
        workoutDuration: TemporaryScheduleOverride.Duration? = .indefinite
    ) {
        ranges = [:]
        ranges[.preMeal] = preMeal
        ranges[.workout] = workout
        self.workoutDuration = workoutDuration
    }


    public var preMeal: ClosedRange<LoopQuantity>? { ranges[.preMeal] }
    public var workout: ClosedRange<LoopQuantity>? { ranges[.workout] }
}

public extension CorrectionRangeOverrides.Preset {
    var title: String {
        switch self {
        case .preMeal:
            return LocalizedString("Pre-Meal", comment: "Title for pre-meal mode")
        case .workout:
            return LocalizedString("Workout", comment: "Title for workout mode")
        }
    }
    
    var therapySetting: TherapySetting {
        switch self {
        case .preMeal: return .preMealCorrectionRangeOverride
        case .workout: return .workoutCorrectionRangeOverride
        }
    }
}

extension CorrectionRangeOverrides: Codable {
    fileprivate var codingGlucoseUnit: LoopUnit {
        return .milligramsPerDeciliter
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let preMealGlucoseRange = try container.decodeIfPresent(GlucoseRange.self, forKey: .preMealRange)
        let workoutGlucoseRange = try container.decodeIfPresent(GlucoseRange.self, forKey: .workoutRange)

        self.ranges = [:]
        self.ranges[.preMeal] = preMealGlucoseRange?.quantityRange
        self.ranges[.workout] = workoutGlucoseRange?.quantityRange
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let preMealGlucoseRange = preMeal?.glucoseRange(for: codingGlucoseUnit)
        let workoutGlucoseRange = workout?.glucoseRange(for: codingGlucoseUnit)
        try container.encodeIfPresent(preMealGlucoseRange, forKey: .preMealRange)
        try container.encodeIfPresent(workoutGlucoseRange, forKey: .workoutRange)
    }

    private enum CodingKeys: String, CodingKey {
        case preMealRange
        case workoutRange
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

        if let rawWorkoutTargetRange = rawValue["workoutTargetRange"] as? GlucoseRange.RawValue {
            ranges[.workout] = GlucoseRange(rawValue: rawWorkoutTargetRange)?.quantityRange
        }
    }

    public var rawValue: RawValue {
        var raw: RawValue = [:]
        let preMealTargetGlucoseRange = preMeal?.glucoseRange(for: codingGlucoseUnit)
        let workoutTargetGlucoseRange = workout?.glucoseRange(for: codingGlucoseUnit)
        raw["preMealTargetRange"] = preMealTargetGlucoseRange?.rawValue
        raw["workoutTargetRange"] = workoutTargetGlucoseRange?.rawValue

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

