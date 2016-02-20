//
//  GlucoseValue.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 2/19/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import LoopKit
import HealthKit


public struct GlucoseValue: SampleValue {
    public let startDate: NSDate
    public let quantity: HKQuantity

    public init(startDate: NSDate, quantity: HKQuantity) {
        self.startDate = startDate
        self.quantity = quantity
    }
}
