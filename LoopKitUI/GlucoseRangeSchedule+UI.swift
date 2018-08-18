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
            return LocalizedString("Workout", comment: "Title for the workout override range")
        case .preMeal:
            return LocalizedString("Pre-Meal", comment: "Title for the pre-meal override range")
        }
    }
}
