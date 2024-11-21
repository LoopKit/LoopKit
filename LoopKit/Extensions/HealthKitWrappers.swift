//
//  HealthKitWrappers.swift
//  LoopKit
//
//  Created by Cameron Ingham on 11/8/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopAlgorithm

public extension LoopUnit {
    var hkUnit: HKUnit {
        switch self {
        case .gram:
            return .gram()
        case .gramsPerUnit:
            return .gramsPerUnit
        case .internationalUnit:
            return .internationalUnit()
        case .internationalUnitsPerHour:
            return .internationalUnitsPerHour
        case .milligramsPerDeciliter:
            return .milligramsPerDeciliter
        case .milligramsPerDeciliterPerSecond:
            return .milligramsPerDeciliterPerSecond
        case .milligramsPerDeciliterPerMinute:
            return .milligramsPerDeciliterPerMinute
        case .milligramsPerDeciliterPerInternationalUnit:
            return .milligramsPerDeciliter.unitDivided(by: .internationalUnit())
        case .millimolesPerLiter:
            return .millimolesPerLiter
        case .millimolesPerLiterPerSecond:
            return .millimolesPerLiter.unitDivided(by: .second())
        case .millimolesPerLiterPerMinute:
            return .millimolesPerLiter.unitDivided(by: .minute())
        case .millimolesPerLiterPerInternationalUnit:
            return .millimolesPerLiter.unitDivided(by: .internationalUnit())
        case .percent:
            return .percent()
        case .hour:
            return .hour()
        case .minute:
            return .minute()
        case .second:
            return .second()
        }
    }
}

public extension LoopQuantity {
    var hkQuantity: HKQuantity {
        HKQuantity(unit: unit.hkUnit, doubleValue: value)
    }
}

extension HKQuantity: @retroactive Comparable { }

public func <(lhs: HKQuantity, rhs: HKQuantity) -> Bool {
    return lhs.compare(rhs) == .orderedAscending
}

extension HKUnit {
    convenience init(_ loopUnit: LoopUnit) {
        self.init(from: loopUnit.unitString)
    }
}

extension LoopUnit {
    static func firstCompatible(with quantity: HKQuantity) -> LoopUnit? {
        LoopUnit.allCases.first(where: { quantity.is(compatibleWith: $0.hkUnit) })
    }
}
