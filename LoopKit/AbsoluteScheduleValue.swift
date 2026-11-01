//
//  AbsoluteScheduleValue.swift
//  
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation

public struct AbsoluteScheduleValue<T: Sendable>: TimelineValue, Sendable {
    public var startDate: Date
    public var endDate: Date
    public var value: T

    public init(startDate: Date, endDate: Date, value: T) {
        self.startDate = startDate
        self.endDate = endDate
        self.value = value
    }

    public var duration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }
}

extension AbsoluteScheduleValue: Equatable where T: Equatable {}

extension AbsoluteScheduleValue: Codable where T: Codable {}
