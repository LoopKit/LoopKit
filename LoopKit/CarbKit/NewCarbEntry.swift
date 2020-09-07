//
//  NewCarbEntry.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/15/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit


public struct NewCarbEntry: CarbEntry, Equatable, RawRepresentable {
    public typealias RawValue = [String: Any]

    public let date: Date
    public let quantity: HKQuantity
    public let startDate: Date
    public let foodType: String?
    public let absorptionTime: TimeInterval?

    public init(date: Date = Date(), quantity: HKQuantity, startDate: Date, foodType: String?, absorptionTime: TimeInterval?) {
        self.date = date
        self.quantity = quantity
        self.startDate = startDate
        self.foodType = foodType
        self.absorptionTime = absorptionTime
    }

    public init?(rawValue: RawValue) {
        guard
            let date = rawValue["date"] as? Date,
            let grams = rawValue["grams"] as? Double,
            let startDate = rawValue["startDate"] as? Date
        else {
            return nil
        }

        self.init(
            date: date,
            quantity: HKQuantity(unit: .gram(), doubleValue: grams),
            startDate: startDate,
            foodType: rawValue["foodType"] as? String,
            absorptionTime: rawValue["absorptionTime"] as? TimeInterval
        )
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [
            "date": date,
            "grams": quantity.doubleValue(for: .gram()),
            "startDate": startDate
        ]

        rawValue["foodType"] = foodType
        rawValue["absorptionTime"] = absorptionTime

        return rawValue
    }
}
