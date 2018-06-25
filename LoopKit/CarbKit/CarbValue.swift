//
//  CarbValue.swift
//  LoopKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit


public struct CarbValue: SampleValue {
    public let startDate: Date
    public let endDate: Date
    public var quantity: HKQuantity

    init(startDate: Date, endDate: Date? = nil, quantity: HKQuantity) {
        self.startDate = startDate
        self.endDate = endDate ?? startDate
        self.quantity = quantity
    }
}
