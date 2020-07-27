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
    
    var descriptiveText: String {
        switch self {
        case .preMeal:
            return LocalizedString("Temporarily lower your glucose target before a meal to impact post-meal glucose spikes. This range can be set anywhere from your suspend threshold on the low end to the top of your regular correction range on the high end.", comment: "Description of pre-meal mode")
        case .workout:
            return LocalizedString("Temporarily raise your glucose target before, during, or after physical activity to reduce the risk of low glucose events. This range can be set anywhere from your suspend threshold on the low end to the top of your regular correction range on the high end.", comment: "Description of workout mode")
        }
    }
}
