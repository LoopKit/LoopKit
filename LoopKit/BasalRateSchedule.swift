//
//  BasalRateSchedule.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/12/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


public class BasalRateSchedule: DailyValueSchedule<Double> {

    public override init?(dailyItems: [RepeatingScheduleValue<Double>], timeZone: TimeZone? = nil) {
        super.init(dailyItems: dailyItems, timeZone: timeZone)
    }

    /**
     Calculates the total basal delivery for a day

     - returns: The total basal delivery
     */
    public func total() -> Double {
        var total: Double = 0

        for (index, item) in items.enumerated() {
            var endTime = maxTimeInterval

            if index < items.endIndex - 1 {
                endTime = items[index + 1].startTime
            }

            total += (endTime - item.startTime) / TimeInterval(hours: 1) * item.value
        }
        
        return total
    }

    public override func value(at time: Date) -> Double {
        return super.value(at: time)
    }

}
