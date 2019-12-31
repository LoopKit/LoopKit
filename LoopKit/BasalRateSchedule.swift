//
//  BasalRateSchedule.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/12/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


public typealias BasalRateSchedule = DailyValueSchedule<Double>

public struct BasalScheduleValidationResult {
    let scheduleError: Error?
    let itemErrors: [(index: Int, error: Error)]
}


public extension DailyValueSchedule where T == Double {
    /**
     Calculates the total basal delivery for a day

     - returns: The total basal delivery
     */
    func total() -> Double {
        var total: Double = 0

        for (index, item) in items.enumerated() {
            var endTime = maxTimeInterval

            if index < items.endIndex - 1 {
                endTime = items[index + 1].startTime
            }

            total += (endTime - item.startTime).hours * item.value
        }
        
        return total
    }
}
