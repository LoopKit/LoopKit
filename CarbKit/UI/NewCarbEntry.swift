//
//  NewCarbEntry.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/15/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit


public struct NewCarbEntry: CarbEntry {
    public var quantity: HKQuantity
    public var startDate: Date
    public var foodType: String?
    public var absorptionTime: TimeInterval?
    public let createdByCurrentApp = true

    public init(quantity: HKQuantity, startDate: Date, foodType: String?, absorptionTime: TimeInterval?) {
        self.quantity = quantity
        self.startDate = startDate
        self.foodType = foodType
        self.absorptionTime = absorptionTime
    }
}
