//
//  GlucoseValue.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 3/2/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//


import HealthKit


public protocol GlucoseValue: SampleValue {
}


public struct PredictedGlucoseValue: Equatable, GlucoseValue {
    public let startDate: Date
    public let quantity: HKQuantity

    public init(startDate: Date, quantity: HKQuantity) {
        self.startDate = startDate
        self.quantity = quantity
    }
}


extension HKQuantitySample: GlucoseValue { }
