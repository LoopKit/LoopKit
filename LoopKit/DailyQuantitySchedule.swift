//
//  DailyQuantitySchedule.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/12/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit


public class DailyQuantitySchedule<T: RawRepresentable>: DailyValueSchedule<T> where T.RawValue: Any {
    public let unit: HKUnit

    init?(unit: HKUnit, dailyItems: [RepeatingScheduleValue<T>], timeZone: TimeZone?) {
        self.unit = unit

        super.init(dailyItems: dailyItems, timeZone: timeZone)
    }

    public required convenience init?(rawValue: RawValue) {
        guard let
            rawUnit = rawValue["unit"] as? String,
            let rawItems = rawValue["items"] as? [RepeatingScheduleValue.RawValue] else
        {
            return nil
        }

        var timeZone: TimeZone?

        if let offset = rawValue["timeZone"] as? Int {
            timeZone = TimeZone(secondsFromGMT: offset)
        }

        self.init(unit: HKUnit(from: rawUnit), dailyItems: rawItems.flatMap { RepeatingScheduleValue(rawValue: $0) }, timeZone: timeZone)
    }

    public override var rawValue: RawValue {
        var rawValue = super.rawValue

        rawValue["unit"] = unit.unitString

        return rawValue
    }
}


public class SingleQuantitySchedule: DailyQuantitySchedule<Double> {
    public func quantity(at time: Date) -> HKQuantity {
        return HKQuantity(unit: unit, doubleValue: value(at: time))
    }

    override init?(unit: HKUnit, dailyItems: [RepeatingScheduleValue<Double>], timeZone: TimeZone?) {
        super.init(unit: unit, dailyItems: dailyItems, timeZone: timeZone)
    }

    func averageValue() -> Double {
        var total: Double = 0

        for (index, item) in items.enumerated() {
            var endTime = maxTimeInterval

            if index < items.endIndex - 1 {
                endTime = items[index + 1].startTime
            }

            total += (endTime - item.startTime) * item.value
        }

        return total / repeatInterval
    }

    public func averageQuantity() -> HKQuantity {
        return HKQuantity(unit: unit, doubleValue: averageValue())
    }
}
