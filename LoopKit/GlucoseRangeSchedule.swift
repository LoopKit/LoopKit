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

    public var isZero: Bool {
        return abs(minValue) < .ulpOfOne && abs(maxValue) < .ulpOfOne
    }
}


extension DoubleRange: RawRepresentable {
    public typealias RawValue = [Double]

    public init?(rawValue: RawValue) {
        guard rawValue.count == 2 else {
            return nil
        }

        minValue = rawValue[0]
        maxValue = rawValue[1]
    }

    public var rawValue: RawValue {
        return [minValue, maxValue]
    }
}


extension DoubleRange: Equatable {
    public static func ==(lhs: DoubleRange, rhs: DoubleRange) -> Bool {
        return abs(lhs.minValue - rhs.minValue) < .ulpOfOne &&
               abs(lhs.maxValue - rhs.maxValue) < .ulpOfOne
    }
}


/// Defines a daily schedule of glucose ranges
public struct GlucoseRangeSchedule: DailySchedule, Equatable {
    public typealias RawValue = [String: Any]

    var rangeSchedule: DailyQuantitySchedule<DoubleRange>

    public init?(unit: HKUnit, dailyItems: [RepeatingScheduleValue<DoubleRange>], timeZone: TimeZone? = nil) {
        guard let rangeSchedule = DailyQuantitySchedule<DoubleRange>(unit: unit, dailyItems: dailyItems, timeZone: timeZone) else {
            return nil
        }

        self.rangeSchedule = rangeSchedule
    }

    public init?(rawValue: RawValue) {
        guard let rangeSchedule = DailyQuantitySchedule<DoubleRange>(rawValue: rawValue) else {
            return nil
        }

        self.rangeSchedule = rangeSchedule
    }

    public func between(start startDate: Date, end endDate: Date) -> [AbsoluteScheduleValue<DoubleRange>] {
        return rangeSchedule.between(start: startDate, end: endDate)
    }

    public func quantityBetween(start: Date, end: Date) -> [AbsoluteScheduleValue<Range<HKQuantity>>] {
        var quantitySchedule = [AbsoluteScheduleValue<Range<HKQuantity>>]()

        for schedule in between(start: start, end: end) {
            let lowerBound = HKQuantity(unit: unit, doubleValue: schedule.value.minValue)
            let upperBound = HKQuantity(unit: unit, doubleValue: schedule.value.maxValue)

            quantitySchedule.append(AbsoluteScheduleValue(
                startDate: schedule.startDate,
                endDate: schedule.endDate,
                value: lowerBound..<upperBound
            ))
        }

        return quantitySchedule
    }

    public func value(at time: Date) -> DoubleRange {
        return rangeSchedule.value(at: time)
    }

    public var items: [RepeatingScheduleValue<DoubleRange>] {
        return rangeSchedule.items
    }

    public var timeZone: TimeZone {
        get {
            return rangeSchedule.timeZone
        }
        set {
            rangeSchedule.timeZone = newValue
        }
    }

    public var unit: HKUnit {
        return rangeSchedule.unit
    }

    public var rawValue: RawValue {
        return rangeSchedule.rawValue
    }
}
