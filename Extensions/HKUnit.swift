//
//  HKUnit.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/17/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import HealthKit


extension HKUnit {
    static func milligramsPerDeciliter() -> HKUnit {
        return HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
    }

    static func millimolesPerLiter() -> HKUnit {
        return HKUnit.moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: .liter())
    }

    /// A formatting helper for determining the preferred decimal style for a given unit
    var preferredFractionDigits: Int {
        if self == HKUnit.milligramsPerDeciliter() {
            return 0
        } else {
            return 1
        }
    }

    /// A presentation helper for the localized unit string
    var glucoseUnitDisplayString: String {
        if self == HKUnit.millimolesPerLiter() {
            return NSLocalizedString("mmol/L", comment: "The unit display string for millimoles of glucose per liter")
        } else {
            return String(describing: self)
        }
    }
}
