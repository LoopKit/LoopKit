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
