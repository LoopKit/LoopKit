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

extension Collection where Element: CarbEntry {

    var totalCarbs: CarbValue? {
        guard count > 0 else {
            return nil
        }

        let unit = LoopUnit.gram
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


