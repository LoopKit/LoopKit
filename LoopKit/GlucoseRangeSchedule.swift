//
//  GlucoseRangeSchedule.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/13/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit


public struct DoubleRange {
    public let minValue: Double
    public let maxValue: Double

    public init(minValue: Double, maxValue: Double) {
        self.minValue = minValue
        self.maxValue = maxValue
    }
}


extension DoubleRange: RawRepresentable {
    public typealias RawValue = NSArray

    public init?(rawValue: RawValue) {
        guard rawValue.count == 2 else {
            return nil
        }

        minValue = rawValue[0].doubleValue
        maxValue = rawValue[1].doubleValue
    }

    public var rawValue: RawValue {
        let raw: NSArray = [
            NSNumber(double: minValue),
            NSNumber(double: maxValue)
        ]

        return raw
    }
}


/// Defines a daily schedule of glucose ranges
public class GlucoseRangeSchedule: DailyQuantitySchedule<DoubleRange> {
    /// A single override range and its end date (by the system clock)
    public private(set) var temporaryOverride: AbsoluteScheduleValue<DoubleRange>?

    public func setOverride(override: DoubleRange, untilDate: NSDate) {
        temporaryOverride = AbsoluteScheduleValue(startDate: untilDate, value: override)
    }

    public func clearOverride() {
        temporaryOverride = nil
    }

    public override init?(unit: HKUnit, dailyItems: [RepeatingScheduleValue<DoubleRange>], timeZone: NSTimeZone? = nil) {
        super.init(unit: unit, dailyItems: dailyItems, timeZone: timeZone)
    }

    public override func valueAt(time: NSDate) -> DoubleRange {
        if let override = temporaryOverride where override.endDate > NSDate() {
            return override.value
        }

        return super.valueAt(time)
    }
}
