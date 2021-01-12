//
//  QuantitySchedule.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/18/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit


public struct RepeatingScheduleValue<T> {
    public var startTime: TimeInterval
    public var value: T

    public init(startTime: TimeInterval, value: T) {
        self.startTime = startTime
        self.value = value
    }

    public func map<U>(_ transform: (T) -> U) -> RepeatingScheduleValue<U> {
        return RepeatingScheduleValue<U>(startTime: startTime, value: transform(value))
    }
}

extension RepeatingScheduleValue: Equatable where T: Equatable {
    public static func == (lhs: RepeatingScheduleValue, rhs: RepeatingScheduleValue) -> Bool {
        return abs(lhs.startTime - rhs.startTime) < .ulpOfOne && lhs.value == rhs.value
    }
}

extension RepeatingScheduleValue: Hashable where T: Hashable {}

public struct AbsoluteScheduleValue<T>: TimelineValue {
    public let startDate: Date
    public let endDate: Date
    public let value: T
}

extension AbsoluteScheduleValue: Equatable where T: Equatable {}

extension RepeatingScheduleValue: RawRepresentable where T: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard let startTime = rawValue["startTime"] as? Double,
            let rawValue = rawValue["value"] as? T.RawValue,
            let value = T(rawValue: rawValue) else
        {
            return nil
        }

        self.init(startTime: startTime, value: value)
    }

    public var rawValue: RawValue {
        return [
            "startTime": startTime,
            "value": value.rawValue
        ]
    }
}

extension RepeatingScheduleValue: Codable where T: Codable {}

public protocol DailySchedule {
    associatedtype T

    var items: [RepeatingScheduleValue<T>] { get }

    var timeZone: TimeZone { get set }

    func between(start startDate: Date, end endDate: Date) -> [AbsoluteScheduleValue<T>]

    func value(at time: Date) -> T
}


public extension DailySchedule {
    func value(at time: Date) -> T {
        return between(start: time, end: time).first!.value
    }
}

extension DailySchedule where T: Comparable {
    public func valueRange() -> ClosedRange<T> {
        items.range(of: { $0.value })!
    }
}

public struct DailyValueSchedule<T>: DailySchedule {
    let referenceTimeInterval: TimeInterval
    let repeatInterval: TimeInterval

    public let items: [RepeatingScheduleValue<T>]
    public var timeZone: TimeZone

    public init?(dailyItems: [RepeatingScheduleValue<T>], timeZone: TimeZone? = nil) {
        self.repeatInterval = TimeInterval(hours: 24)
        self.items = dailyItems.sorted { $0.startTime < $1.startTime }
        self.timeZone = timeZone ?? TimeZone.currentFixed

        guard let firstItem = self.items.first else {
            return nil
        }

        referenceTimeInterval = firstItem.startTime
    }

    var maxTimeInterval: TimeInterval {
        return referenceTimeInterval + repeatInterval
    }

    /**
     Returns the time interval for a given date normalized to the span of the schedule items

     - parameter date: The date to convert
     */
    func scheduleOffset(for date: Date) -> TimeInterval {
        // The time interval since a reference date in the specified time zone
        let interval = date.timeIntervalSinceReferenceDate + TimeInterval(timeZone.secondsFromGMT(for: date))

        // The offset of the time interval since the last occurence of the reference time + n * repeatIntervals.
        // If the repeat interval was 1 day, this is the fractional amount of time since the most recent repeat interval starting at the reference time
        return ((interval - referenceTimeInterval).truncatingRemainder(dividingBy: repeatInterval)) + referenceTimeInterval
    }

    /**
     Returns a slice of schedule items that occur between two dates

     - parameter startDate: The start date of the range
     - parameter endDate:   The end date of the range

     - returns: A slice of `ScheduleItem` values
     */
    public func between(start startDate: Date, end endDate: Date) -> [AbsoluteScheduleValue<T>] {
        guard startDate <= endDate else {
            return []
        }

        let startOffset = scheduleOffset(for: startDate)
        let endOffset = startOffset + endDate.timeIntervalSince(startDate)

        guard endOffset <= maxTimeInterval else {
            let boundaryDate = startDate.addingTimeInterval(maxTimeInterval - startOffset)

            return between(start: startDate, end: boundaryDate) + between(start: boundaryDate, end: endDate)
        }

        var startIndex = 0
        var endIndex = items.count

        for (index, item) in items.enumerated() {
            if startOffset >= item.startTime {
                startIndex = index
            }
            if endOffset < item.startTime {
                endIndex = index
                break
            }
        }

        let referenceDate = startDate.addingTimeInterval(-startOffset)

        return (startIndex..<endIndex).map { (index) in
            let item = items[index]
            let endTime = index + 1 < items.count ? items[index + 1].startTime : maxTimeInterval

            return AbsoluteScheduleValue(
                startDate: referenceDate.addingTimeInterval(item.startTime),
                endDate: referenceDate.addingTimeInterval(endTime),
                value: item.value
            )
        }
    }

    public func map<U>(_ transform: (T) -> U) -> DailyValueSchedule<U> {
        return DailyValueSchedule<U>(
            dailyItems: items.map { $0.map(transform) },
            timeZone: timeZone
        )!
    }

    public static func zip<L, R>(_ lhs: DailyValueSchedule<L>, _ rhs: DailyValueSchedule<R>) -> DailyValueSchedule where T == (L, R) {
        precondition(lhs.timeZone == rhs.timeZone)

        var (leftCursor, rightCursor) = (lhs.items.startIndex, rhs.items.startIndex)
        var alignedItems: [RepeatingScheduleValue<(L, R)>] = []
        repeat {
            let (leftItem, rightItem) = (lhs.items[leftCursor], rhs.items[rightCursor])
            let alignedItem = RepeatingScheduleValue(
                startTime: max(leftItem.startTime, rightItem.startTime),
                value: (leftItem.value, rightItem.value)
            )
            alignedItems.append(alignedItem)

            let nextLeftStartTime = leftCursor == lhs.items.endIndex - 1 ? nil : lhs.items[leftCursor + 1].startTime
            let nextRightStartTime = rightCursor == rhs.items.endIndex - 1 ? nil : rhs.items[rightCursor + 1].startTime
            switch (nextLeftStartTime, nextRightStartTime) {
            case (.some(let leftStart), .some(let rightStart)):
                if leftStart < rightStart {
                    leftCursor += 1
                } else if rightStart < leftStart {
                    rightCursor += 1
                } else {
                    leftCursor += 1
                    rightCursor += 1
                }
            case (.some, .none):
                leftCursor += 1
            case (.none, .some):
                rightCursor += 1
            case (.none, .none):
                leftCursor += 1
                rightCursor += 1
            }
        } while leftCursor < lhs.items.endIndex && rightCursor < rhs.items.endIndex

        return DailyValueSchedule(dailyItems: alignedItems, timeZone: lhs.timeZone)!
    }
}


extension DailyValueSchedule: RawRepresentable, CustomDebugStringConvertible where T: RawRepresentable {
    public typealias RawValue = [String: Any]
    public init?(rawValue: RawValue) {
        guard let rawItems = rawValue["items"] as? [RepeatingScheduleValue<T>.RawValue] else {
            return nil
        }

        var timeZone: TimeZone?

        if let offset = rawValue["timeZone"] as? Int {
            timeZone = TimeZone(secondsFromGMT: offset)
        }

        let validScheduleItems = rawItems.compactMap(RepeatingScheduleValue<T>.init(rawValue:))
        guard validScheduleItems.count == rawItems.count else {
            return nil
        }
        self.init(dailyItems: validScheduleItems, timeZone: timeZone)
    }

    public var rawValue: RawValue {
        let rawItems = items.map { $0.rawValue }

        return [
            "timeZone": timeZone.secondsFromGMT(),
            "items": rawItems
        ]
    }

    public var debugDescription: String {
        return String(reflecting: rawValue)
    }
}

extension DailyValueSchedule: Codable where T: Codable {}

extension DailyValueSchedule: Equatable where T: Equatable {}

extension RepeatingScheduleValue {
    public static func == <L: Equatable, R: Equatable> (lhs: RepeatingScheduleValue, rhs: RepeatingScheduleValue) -> Bool where T == (L, R) {
        return lhs.startTime == rhs.startTime && lhs.value == rhs.value
    }
}

extension DailyValueSchedule {
    public static func == <L: Equatable, R: Equatable> (lhs: DailyValueSchedule, rhs: DailyValueSchedule) -> Bool where T == (L, R) {
        return lhs.timeZone == rhs.timeZone
            && lhs.items.count == rhs.items.count
            && Swift.zip(lhs.items, rhs.items).allSatisfy(==)
    }
}
