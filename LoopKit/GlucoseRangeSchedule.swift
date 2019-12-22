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

extension DoubleRange: Hashable {}


/// Defines a daily schedule of glucose ranges
public struct GlucoseRangeSchedule: DailySchedule, Equatable {
    public typealias RawValue = [String: Any]

    /// A time-based value overriding the rangeSchedule
    public struct Override: Equatable {

        public let start: Date
        public let end: Date
        public let value: DoubleRange

        /// Initializes a new override
        ///
        /// - Parameters:
        ///   - start: The date at which the override starts
        ///   - end: The date at which the override ends, or nil for an indefinite override
        ///   - value: The value to return when active
        public init(start: Date, end: Date?, value: DoubleRange) {
            self.start = start
            self.end = end ?? .distantFuture
            self.value = value
        }

        public var activeDates: DateInterval {
            return DateInterval(start: start, end: end)
        }

        public func isActive(at date: Date = Date()) -> Bool {
            return activeDates.contains(date) && !value.isZero
        }
    }

    /// An enabled override of the range schedule; only "active" between start and end, but when
    /// active, it overrides the entire schedule. Not persisted
    public private(set) var override: Override?

    var rangeSchedule: DailyQuantitySchedule<DoubleRange>

    public init(rangeSchedule: DailyQuantitySchedule<DoubleRange>, override: Override? = nil) {
        self.rangeSchedule = rangeSchedule
        self.override = override
    }

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

    public func quantityBetween(start: Date, end: Date) -> [AbsoluteScheduleValue<ClosedRange<HKQuantity>>] {
        var quantitySchedule = [AbsoluteScheduleValue<ClosedRange<HKQuantity>>]()

        for schedule in between(start: start, end: end) {
            quantitySchedule.append(AbsoluteScheduleValue(
                startDate: schedule.startDate,
                endDate: schedule.endDate,
                value: schedule.value.quantityRange(for: unit)
            ))
        }

        return quantitySchedule
    }

    /// Returns the underlying values in `unit`
    /// Consider using quantity(at:) instead
    public func value(at time: Date) -> DoubleRange {
        if let override = override, time >= override.start && Date() < override.end {
            return override.value
        }

        return rangeSchedule.value(at: time)
    }

    public func quantityRange(at time: Date) -> ClosedRange<HKQuantity> {
        return value(at: time).quantityRange(for: unit)
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

extension DoubleRange {
    public func quantityRange(for unit: HKUnit) -> ClosedRange<HKQuantity> {
        let lowerBound = HKQuantity(unit: unit, doubleValue: minValue)
        let upperBound = HKQuantity(unit: unit, doubleValue: maxValue)
        return lowerBound...upperBound
    }
}

extension ClosedRange where Bound == HKQuantity {
    func doubleRange(for unit: HKUnit) -> DoubleRange {
        return DoubleRange(minValue: lowerBound.doubleValue(for: unit), maxValue: upperBound.doubleValue(for: unit))
    }
}
