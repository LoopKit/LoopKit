//
//  GlucoseSampleValue.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 3/6/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

public protocol GlucoseSampleValue: GlucoseValue {
    /// Uniquely identifies the source of the sample.
    var provenanceIdentifier: String { get }

    /// Whether the glucose value was provided for visual consistency, rather than an actual, calibrated reading.
    var isDisplayOnly: Bool { get }

    /// Whether the glucose value was entered by the user.
    var wasUserEntered: Bool { get }
}
