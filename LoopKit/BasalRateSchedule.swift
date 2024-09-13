//
//  BasalRateSchedule.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/12/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import LoopAlgorithm

public typealias BasalRateSchedule = DailyValueSchedule<Double>

public struct BasalScheduleValidationResult {
    let scheduleError: Error?
    let itemErrors: [(index: Int, error: Error)]
}

public extension BasalRateSchedule {
    /**
     Takes a history of BasalRateSchedules and generates a timeline of scheduled basal rates

     - returns: A timeline of scheduled basal rates.
     */


    static func generateTimeline(
        schedules: [(
            date: Date,
            schedule: BasalRateSchedule
        )],
        startDate: Date,
        endDate: Date
    ) -> [AbsoluteScheduleValue<Double>] {
        guard !schedules.isEmpty else {
            return []
        }

        var idx = schedules.startIndex
        var date = startDate
        var items = [AbsoluteScheduleValue<Double>]()
        while date < endDate {
            let scheduleActiveEnd: Date
            if idx+1 < schedules.endIndex {
                scheduleActiveEnd = schedules[idx+1].date
            } else {
                scheduleActiveEnd = endDate
            }

            let schedule = schedules[idx].schedule

            let absoluteScheduleValues = schedule.truncatingBetween(start: date, end: scheduleActiveEnd)

            items.append(contentsOf: absoluteScheduleValues)
            date = scheduleActiveEnd
            idx += 1
        }

        return items
    }
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
