//
//  HKUnit+LoopKitUI.swift
//  LoopKitUI
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit


extension HKUnit {
    /// A formatting helper for determining the preferred decimal style for a given unit
    var preferredFractionDigits: Int {
        if self == HKUnit.milligramsPerDeciliter {
            return 0
        } else {
            return 1
        }
    }

    /// A presentation helper for the localized unit string
    var glucoseUnitDisplayString: String {
        if self == HKUnit.millimolesPerLiter {
            return LocalizedString("mmol/L", comment: "The unit display string for millimoles of glucose per liter")
        } else {
            return String(describing: self)
        }
    }
}
