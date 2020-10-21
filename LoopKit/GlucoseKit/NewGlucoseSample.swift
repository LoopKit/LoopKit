//
//  NewGlucoseSample.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit


public struct NewGlucoseSample: Equatable {
    public let date: Date
    public let quantity: HKQuantity
    public let isDisplayOnly: Bool
    public let wasUserEntered: Bool
    public let syncIdentifier: String
    public var syncVersion: Int
    public var device: HKDevice?

    /// - Parameters:
    ///   - date: The date the sample was collected
    ///   - quantity: The glucose sample quantity
    ///   - isDisplayOnly: Whether the reading was shifted for visual consistency after calibration
    ///   - wasUserEntered: Whether the reading was entered by the user (manual) or not (device)
    ///   - syncIdentifier: A unique identifier representing the sample, used for de-duplication
    ///   - syncVersion: A version number for determining resolution in de-duplication
    ///   - device: The description of the device the collected the sample
    public init(date: Date, quantity: HKQuantity, isDisplayOnly: Bool, wasUserEntered: Bool, syncIdentifier: String, syncVersion: Int = 1, device: HKDevice? = nil) {
        self.date = date
        self.quantity = quantity
        self.isDisplayOnly = isDisplayOnly
        self.wasUserEntered = wasUserEntered
        self.syncIdentifier = syncIdentifier
        self.syncVersion = syncVersion
        self.device = device
    }
}


extension NewGlucoseSample {
    public var quantitySample: HKQuantitySample {
        var metadata: [String: Any] = [
            HKMetadataKeySyncIdentifier: syncIdentifier,
            HKMetadataKeySyncVersion: syncVersion,
        ]

        if isDisplayOnly {
            metadata[MetadataKeyGlucoseIsDisplayOnly] = true
        }
        if wasUserEntered {
            metadata[HKMetadataKeyWasUserEntered] = true
        }

        return HKQuantitySample(
            type: HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!,
            quantity: quantity,
            start: date,
            end: date,
            device: device,
            metadata: metadata
        )
    }
}
