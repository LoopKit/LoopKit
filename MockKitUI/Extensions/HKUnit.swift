//
//  HKUnit.swift
//  MockKitUI
//
//  Created by Nathaniel Hamming on 2023-05-18.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import HealthKit

extension HKUnit {
    static let milligramsPerDeciliter: HKUnit = {
        return HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
    }()

    static let millimolesPerLiter: HKUnit = {
        return HKUnit.moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: .liter())
    }()

    static let milligramsPerDeciliterPerMinute: HKUnit = {
        return HKUnit.milligramsPerDeciliter.unitDivided(by: .minute())
    }()

    static let millimolesPerLiterPerMinute: HKUnit = {
        return HKUnit.millimolesPerLiter.unitDivided(by: .minute())
    }()

    static let internationalUnitsPerHour: HKUnit = {
        return HKUnit.internationalUnit().unitDivided(by: .hour())
    }()

    static let gramsPerUnit: HKUnit = {
        return HKUnit.gram().unitDivided(by: .internationalUnit())
    }()
    
    var foundationUnit: Unit? {
        if self == HKUnit.milligramsPerDeciliter {
            return UnitConcentrationMass.milligramsPerDeciliter
        }

        if self == HKUnit.millimolesPerLiter {
            return UnitConcentrationMass.millimolesPerLiter(withGramsPerMole: HKUnitMolarMassBloodGlucose)
        }

        if self == HKUnit.gram() {
            return UnitMass.grams
        }

        return nil
    }
    
    /// The smallest value expected to be visible on a chart
    var chartableIncrement: Double {
        if self == .milligramsPerDeciliter {
            return 1
        } else {
            return 1 / 25
        }
    }
}
