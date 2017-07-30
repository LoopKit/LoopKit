//
//  GlucoseRangeSchedule+UI.swift
//  LoopKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import UIKit


extension GlucoseRangeSchedule.Override.Context {
    var image: UIImage? {
        switch self {
        case .workout:
            return UIImage(named: "workout")
        }
    }

    var title: String {
        switch self {
        case .workout:
            return NSLocalizedString("Workout", comment: "Title for the workout override range")
        }
    }
}
