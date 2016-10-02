//
//  QuantitySchedule.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/18/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit


public struct RepeatingScheduleValue<T: RawRepresentable> where T.RawValue: Any {
    public let startTime: TimeInterval
    public let value: T

    public init(startTime: TimeInterval, value: T) {
        self.startTime = startTime
        self.value = value
    }
}

public struct AbsoluteScheduleValue<T>: TimelineValue {
    public let startDate: Date
    public let value: T
}

extension RepeatingScheduleValue: RawRepresentable {
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


public class DailyValueSchedule<T: RawRepresentable>: RawRepresentable, CustomDebugStringConvertible where T.RawValue: Any {
    public typealias RawValue = [String: Any]

    private let referenceTimeInterval: TimeInterval
    let repeatInterval = TimeInterval(hours: 24)

    public let items: [RepeatingScheduleValue<T>]
    public let timeZone: TimeZone

    init?(dailyItems: [RepeatingScheduleValue<T>], timeZone: TimeZone?) {
        self.items = dailyItems.sorted { $0.startTime < $1.startTime }
        self.timeZone = timeZone ?? TimeZone.currentFixed

        guard let firstItem = self.items.first else {
            return nil
        }

        referenceTimeInterval = firstItem.startTime
    }

    public required convenience init?(rawValue: RawValue) {
        guard let rawItems = rawValue["items"] as? [RepeatingScheduleValue.RawValue] else {
            return nil
        }

        var timeZone: TimeZone?

        if let offset = rawValue["timeZone"] as? Int {
            timeZone = TimeZone(secondsFromGMT: offset)
        }

        self.init(dailyItems: rawItems.flatMap { RepeatingScheduleValue(rawValue: $0) }, timeZone: timeZone)
    }

    public var rawValue: RawValue {
        let rawItems = items.map { $0.rawValue }

        return [
            "timeZone": timeZone.secondsFromGMT(),
            "items": rawItems
        ]
    }

    var maxTimeInterval: TimeInterval {
        return referenceTimeInterval + repeatInterval
    }

    /**
     Returns the time interval for a given date normalized to the span of the schedule items

     - parameter date: The date to convert
     */
    private func scheduleOffset(for date: Date) -> TimeInterval {
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

        return items[startIndex..<endIndex].map {
            return AbsoluteScheduleValue(startDate: referenceDate.addingTimeInterval($0.startTime), value: $0.value)
        }
    }

    func value(at time: Date) -> T {
        return between(start: time, end: time).first!.value
    }

    public var debugDescription: String {
        return rawValue.debugDescription
    }
}
