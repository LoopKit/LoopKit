//
//  GlucoseEffect.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit


public struct GlucoseEffect: GlucoseValue, Equatable {
    public let startDate: Date
    public let quantity: HKQuantity

    public init(startDate: Date, quantity: HKQuantity) {
        self.startDate = startDate
        self.quantity = quantity
    }
}


extension GlucoseEffect: Comparable {
    public static func <(lhs: GlucoseEffect, rhs: GlucoseEffect) -> Bool {
        return lhs.startDate < rhs.startDate
    }
}
