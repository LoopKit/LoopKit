//
//  GlucoseRangeSchedule+UI.swift
//  LoopKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import LoopKit


extension GlucoseRangeSchedule.Override.Context {
    var title: String {
        switch self {
        case .workout:
            return NSLocalizedString("Workout", comment: "Title for the workout override range")
        case .preMeal:
            return NSLocalizedString("Pre-Meal", comment: "Title for the pre-meal override range")
        }
    }
}
