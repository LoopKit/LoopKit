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
    public let externalId: String?
    public let isUploaded: Bool

    public init(quantity: HKQuantity, startDate: Date, foodType: String?, absorptionTime: TimeInterval?, isUploaded: Bool = false, externalId: String? = nil) {
        self.quantity = quantity
        self.startDate = startDate
        self.foodType = foodType
        self.absorptionTime = absorptionTime
        self.isUploaded = isUploaded
        self.externalId = externalId
    }
}


extension NewCarbEntry: Equatable {
    public static func ==(lhs: NewCarbEntry, rhs: NewCarbEntry) -> Bool {
        return lhs.quantity.compare(rhs.quantity) == .orderedSame &&
        lhs.startDate == rhs.startDate &&
        lhs.foodType == rhs.foodType &&
        lhs.absorptionTime == rhs.absorptionTime &&
        lhs.createdByCurrentApp == rhs.createdByCurrentApp &&
        lhs.externalId == rhs.externalId &&
        lhs.isUploaded == rhs.isUploaded
    }
}
