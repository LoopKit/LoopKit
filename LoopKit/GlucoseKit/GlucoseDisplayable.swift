//
//  GlucoseDisplayable.swift
//  Loop
//
//  Created by Nate Racklyeft on 8/2/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit

public protocol GlucoseDisplayable {
    /// Returns whether the current state is valid
    var isStateValid: Bool { get }

    /// Describes the state of the sensor in the current localization
    var stateDescription: String { get }

    /// Enumerates the trend of the sensor values
    var trendType: GlucoseTrend? { get }

    /// The trend rate of the sensor values, if available
    var trendRate: HKQuantity? { get }

    /// Returns whether the data is from a locally-connected device
    var isLocal: Bool { get }
    
    /// enumerates the glucose value type (e.g., normal, low, high)
    var glucoseRangeCategory: GlucoseRangeCategory? { get }
}


extension GlucoseDisplayable {
    public var stateDescription: String {
        if isStateValid {
            return LocalizedString("OK", comment: "Sensor state description for the valid state")
        } else {
            return LocalizedString("Needs Attention", comment: "Sensor state description for the non-valid state")
        }
    }
}
