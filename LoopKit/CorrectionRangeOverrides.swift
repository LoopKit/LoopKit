//
//  CorrectionRangeOverrides.swift
//  LoopKit
//
//  Created by Rick Pasetto on 7/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import Foundation

public struct CorrectionRangeOverrides: Equatable {
    public enum Preset: Hashable, CaseIterable {
        case preMeal
        case workout
    }

    public var ranges: [Preset: ClosedRange<HKQuantity>]

    public init(preMeal: DoubleRange?, workout: DoubleRange?, unit: HKUnit) {
        ranges = [:]
        ranges[.preMeal] = preMeal?.quantityRange(for: unit)
        ranges[.workout] = workout?.quantityRange(for: unit)
    }

    public init(preMeal: GlucoseRange?, workout: GlucoseRange?) {
        ranges = [:]
        ranges[.preMeal] = preMeal?.quantityRange
        ranges[.workout] = workout?.quantityRange
    }

    public init(preMeal: ClosedRange<HKQuantity>?, workout: ClosedRange<HKQuantity>?) {
        ranges = [:]
        ranges[.preMeal] = preMeal
        ranges[.workout] = workout
    }

    public var preMeal: ClosedRange<HKQuantity>? { ranges[.preMeal] }
    public var workout: ClosedRange<HKQuantity>? { ranges[.workout] }
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
    fileprivate var codingGlucoseUnit: HKUnit {
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
