//
//  NewCarbEntry.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/15/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit


public struct NewCarbEntry: CarbEntry, Equatable {
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
}
