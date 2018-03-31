//
//  NewGlucoseSample.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit


public struct NewGlucoseSample {
    public let date: Date
    public let quantity: HKQuantity
    public let isDisplayOnly: Bool
    public let syncIdentifier: String
    public var device: HKDevice?

    /// - Parameters:
    ///   - date: The date the sample was collected
    ///   - quantity: The glucose sample quantity
    ///   - isDisplayOnly: Whether the reading was shifted for visual consistency after calibration
    ///   - syncIdentifier: A unique identifier representing the sample, used for de-duplication
    ///   - device: The description of the device the collected the sample
    public init(date: Date, quantity: HKQuantity, isDisplayOnly: Bool, syncIdentifier: String, device: HKDevice? = nil) {
        self.date = date
        self.quantity = quantity
        self.isDisplayOnly = isDisplayOnly
        self.syncIdentifier = syncIdentifier
        self.device = device
    }
}
