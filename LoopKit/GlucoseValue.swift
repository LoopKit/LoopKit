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


struct PredictedGlucoseValue: GlucoseValue {
    let startDate: NSDate
    let quantity: HKQuantity

    init(startDate: NSDate, quantity: HKQuantity) {
        self.startDate = startDate
        self.quantity = quantity
    }
}


extension HKQuantitySample: GlucoseValue { }
