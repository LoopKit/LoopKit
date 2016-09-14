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

        minValue = (rawValue[0] as! NSNumber).doubleValue
        maxValue = (rawValue[1] as! NSNumber).doubleValue
    }

    public var rawValue: RawValue {
        let raw: NSArray = [
            NSNumber(value: minValue),
            NSNumber(value: maxValue)
        ]

        return raw
    }
}


/// Defines a daily schedule of glucose ranges
public class GlucoseRangeSchedule: DailyQuantitySchedule<DoubleRange> {
    public let workoutRange: DoubleRange?

    /// A single override range and its end date (by the system clock)
    public private(set) var temporaryOverride: AbsoluteScheduleValue<DoubleRange>?

    /**
     Enables the predefined workout range until the given system date
     
     - parameter date: The system date before which the workout range is used
     
     - returns: True if a range was configured to set, false otherwise
     */
    public func setWorkoutOverride(until date: Date) -> Bool {
        guard let workoutRange = workoutRange else {
            return false
        }

        setOverride(workoutRange, until: date)
        return true
    }

    public func setOverride(_ override: DoubleRange, until date: Date) {
        temporaryOverride = AbsoluteScheduleValue(startDate: date, value: override)
    }

    /**
     Removes the current range override
     */
    public func clearOverride() {
        temporaryOverride = nil
    }

    public init?(unit: HKUnit, dailyItems: [RepeatingScheduleValue<DoubleRange>], workoutRange: DoubleRange? = nil, timeZone: TimeZone? = nil) {
        self.workoutRange = workoutRange

        super.init(unit: unit, dailyItems: dailyItems, timeZone: timeZone)
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

        var workout: DoubleRange?

        if let workoutRange = rawValue["workoutRange"] as? DoubleRange.RawValue {
            workout = DoubleRange(rawValue: workoutRange)
        }

        self.init(unit: HKUnit(from: rawUnit), dailyItems: rawItems.flatMap { RepeatingScheduleValue(rawValue: $0) }, workoutRange: workout, timeZone: timeZone)
    }

    public override func value(at time: Date) -> DoubleRange {
        if let override = temporaryOverride, override.endDate as Date > Date() {
            return override.value
        }

        return super.value(at: time)
    }

    public override var rawValue: RawValue {
        var rawValue = super.rawValue

        rawValue["workoutRange"] = workoutRange?.rawValue

        return rawValue
    }
}
