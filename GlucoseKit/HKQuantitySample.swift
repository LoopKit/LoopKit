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


let MetadataKeyGlucoseIsDisplayOnly = "com.loudnate.GlucoseKit.HKMetadataKey.GlucoseIsDisplayOnly"


extension HKQuantitySample: GlucoseValue {
    /// Whether the glucose value was provided for visual consistency, rather than an actual, calibrated reading.
    public var displayOnly: Bool {
        return sourceRevision.source == HKSource.defaultSource()
    }
}
