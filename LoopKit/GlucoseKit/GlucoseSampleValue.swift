//
//  GlucoseSampleValue.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 3/6/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import HealthKit

public protocol GlucoseSampleValue: GlucoseValue {
    /// Uniquely identifies the source of the sample.
    var provenanceIdentifier: String { get }

    /// Whether the glucose value was provided for visual consistency, rather than an actual, calibrated reading.
    var isDisplayOnly: Bool { get }

    /// Whether the glucose value was entered by the user.
    var wasUserEntered: Bool { get }

    /// Any condition applied to the sample.
    var condition: GlucoseCondition? { get }

    /// The trend rate of the sample.
    var trendRate: HKQuantity? { get }
}
