//
//  CarbMath.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/16/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit
import LoopAlgorithm

public struct CarbModelSettings {
    var absorptionModel: CarbAbsorptionComputable
    var initialAbsorptionTimeOverrun: Double
    var adaptiveAbsorptionRateEnabled: Bool
    var adaptiveRateStandbyIntervalFraction: Double
    
    init(absorptionModel: CarbAbsorptionComputable, initialAbsorptionTimeOverrun: Double, adaptiveAbsorptionRateEnabled: Bool, adaptiveRateStandbyIntervalFraction: Double = 0.2) {
        self.absorptionModel = absorptionModel
        self.initialAbsorptionTimeOverrun = initialAbsorptionTimeOverrun
        self.adaptiveAbsorptionRateEnabled = adaptiveAbsorptionRateEnabled
        self.adaptiveRateStandbyIntervalFraction = adaptiveRateStandbyIntervalFraction
    }
}

// MARK: - Linear absorption as a factor of reported duration
struct LinearAbsorption: CarbAbsorptionComputable {
    func percentAbsorptionAtPercentTime(_ percentTime: Double) -> Double {
        switch percentTime {
        case let t where t <= 0.0:
            return 0.0
        case let t where t < 1.0:
            return t
        default:
            return 1.0
        }
    }

    func percentTimeAtPercentAbsorption(_ percentAbsorption: Double) -> Double {
        switch percentAbsorption {
        case let a where a <= 0.0:
            return 0.0
        case let a where a < 1.0:
            return a
        default:
            return 1.0
        }
    }
    
    func percentRateAtPercentTime(_ percentTime: Double) -> Double {
        switch percentTime {
        case let t where t > 0.0 && t <= 1.0:
            return 1.0
        default:
            return 0.0
        }
    }
}

extension Collection where Element: CarbEntry {

    var totalCarbs: CarbValue? {
        guard count > 0 else {
            return nil
        }

        let unit = HKUnit.gram()
        var startDate = Date.distantFuture
        var totalGrams: Double = 0

        for entry in self {
            totalGrams += entry.quantity.doubleValue(for: unit)

            if entry.startDate < startDate {
                startDate = entry.startDate
            }
        }

        return CarbValue(startDate: startDate, value: totalGrams)
    }
}


