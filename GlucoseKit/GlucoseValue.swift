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


public protocol GlucoseValue: SampleValue {
}


extension HKQuantitySample: GlucoseValue {
}
