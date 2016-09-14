//
//  HKUnit.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/17/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import HealthKit


public extension HKUnit {
    static func milligramsPerDeciliterUnit() -> HKUnit {
        return HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.literUnit(with: .deci))
    }

    static func millimolesPerLiterUnit() -> HKUnit {
        return HKUnit.moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: HKUnit.liter())
    }

    /// A formatting helper for determining the preferred decimal style for a given unit
    var preferredMinimumFractionDigits: Int {
        if self == HKUnit.milligramsPerDeciliterUnit() {
            return 0
        } else {
            return 1
        }
    }

    /// A presentation helper for the localized unit string
    var glucoseUnitDisplayString: String {
        if self == HKUnit.millimolesPerLiterUnit() {
            return NSLocalizedString("mmol/L", comment: "The unit display string for millimoles of glucose per liter")
        } else {
            return String(describing: self)
        }
    }
}
