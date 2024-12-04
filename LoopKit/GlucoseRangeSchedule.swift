//
//  GlucoseRangeSchedule.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/13/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit
import LoopAlgorithm

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

extension DoubleRange {
    public func quantityRange(for unit: LoopUnit) -> ClosedRange<LoopQuantity> {
        let lowerBound = LoopQuantity(unit: unit, doubleValue: minValue)
        let upperBound = LoopQuantity(unit: unit, doubleValue: maxValue)
        return lowerBound...upperBound
    }
}

extension DoubleRange: Hashable {}

extension DoubleRange: Codable {}

public typealias GlucoseRangeTimeline = [AbsoluteScheduleValue<ClosedRange<LoopQuantity>>]

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
        ///   - value: The value to return when active
        ///   - start: The date at which the override starts
        ///   - end: The date at which the override ends, or nil for an indefinite override
        public init(value: DoubleRange, start: Date, end: Date? = nil) {
            self.value = value
            self.start = start
            self.end = end ?? .distantFuture
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

    public init?(unit: LoopUnit, dailyItems: [RepeatingScheduleValue<DoubleRange>], timeZone: TimeZone? = nil) {
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

    public func truncatingBetween(start startDate: Date, end endDate: Date) -> [AbsoluteScheduleValue<DoubleRange>] {
        let values = between(start: startDate, end: endDate)
        return values.map { item in
            let start = max(item.startDate, startDate)
            let end = min(item.endDate, endDate)
            return AbsoluteScheduleValue<T>(startDate: start, endDate: end, value: item.value)
        }
    }

    public func quantityBetween(start: Date, end: Date) -> GlucoseRangeTimeline {
        var quantitySchedule = GlucoseRangeTimeline()

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

    public func quantityRange(at time: Date) -> ClosedRange<LoopQuantity> {
        return value(at: time).quantityRange(for: unit)
    }

    public var items: [RepeatingScheduleValue<DoubleRange>] {
        return rangeSchedule.items
    }

    public var quantityRanges: [RepeatingScheduleValue<ClosedRange<LoopQuantity>>] {
        return self.items.map {
            RepeatingScheduleValue<ClosedRange<LoopQuantity>>(startTime: $0.startTime,
                                                            value: $0.value.quantityRange(for: unit))
        }
    }

    public var timeZone: TimeZone {
        get {
            return rangeSchedule.timeZone
        }
        set {
            rangeSchedule.timeZone = newValue
        }
    }

    public var unit: LoopUnit {
        return rangeSchedule.unit
    }

    public var rawValue: RawValue {
        return rangeSchedule.rawValue
    }

    public func minLowerBound() -> LoopQuantity {
        let minDoubleValue = items.lazy.map { $0.value.minValue }.min()!
        return LoopQuantity(unit: unit, doubleValue: minDoubleValue)
    }

    public func scheduleRange() -> ClosedRange<LoopQuantity> {
        let minDoubleValue = items.lazy.map { $0.value.minValue }.min()!
        let lowerBound = LoopQuantity(unit: unit, doubleValue: minDoubleValue)

        let maxDoubleValue = items.lazy.map { $0.value.maxValue }.max()!
        let upperBound = LoopQuantity(unit: unit, doubleValue: maxDoubleValue)

        return lowerBound...upperBound
    }

    private func convertTo(unit: LoopUnit) -> GlucoseRangeSchedule? {
        guard unit != self.unit else {
            return self
        }

        let convertedDailyItems: [RepeatingScheduleValue<DoubleRange>] = rangeSchedule.items.map {
            RepeatingScheduleValue(startTime: $0.startTime,
                                   value: $0.value.quantityRange(for: self.unit).doubleRange(for: unit)
            )
        }

        return GlucoseRangeSchedule(unit: unit,
                                    dailyItems: convertedDailyItems,
                                    timeZone: timeZone)
    }

    public func schedule(for glucoseUnit: LoopUnit) -> GlucoseRangeSchedule? {
        precondition(glucoseUnit == .millimolesPerLiter || glucoseUnit == .milligramsPerDeciliter)
        return self.convertTo(unit: glucoseUnit)
    }
}

extension GlucoseRangeSchedule: Codable {}

extension GlucoseRangeSchedule.Override: Codable {}

extension ClosedRange where Bound == HKQuantity {
    public func averageValue(for unit: HKUnit) -> Double {
        let minValue = lowerBound.doubleValue(for: unit)
        let maxValue = upperBound.doubleValue(for: unit)
        return (maxValue + minValue) / 2
    }
}

extension ClosedRange where Bound == LoopQuantity {
    public func doubleRange(for unit: LoopUnit) -> DoubleRange {
        return DoubleRange(minValue: lowerBound.doubleValue(for: unit), maxValue: upperBound.doubleValue(for: unit))
    }

    public func glucoseRange(for unit: LoopUnit) -> GlucoseRange {
        GlucoseRange(range: self.doubleRange(for: unit), unit: unit)
    }
}

public extension DoubleRange {
    init(_ val: ClosedRange<Double>) {
        self.init(minValue: val.lowerBound, maxValue: val.upperBound)
    }
}
