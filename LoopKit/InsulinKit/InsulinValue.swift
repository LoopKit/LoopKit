//
//  InsulinValue.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 4/3/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit

public struct InsulinValue: TimelineValue, Equatable {
    public let startDate: Date
    public let value: Double

    public init(startDate: Date, value: Double) {
        self.startDate = startDate
        self.value = value
    }

    public var quantity: HKQuantity {
        HKQuantity(unit: .internationalUnit(), doubleValue: value)
    }
}

extension InsulinValue: Codable {}

public extension Array where Element == InsulinValue {
    func trimmed(from start: Date? = nil, to end: Date? = nil) -> [InsulinValue] {
        return self.compactMap { entry in
            if let start, entry.startDate < start {
                return nil
            }
            if let end, entry.startDate > end {
                return nil
            }
            return entry
        }
    }
}
