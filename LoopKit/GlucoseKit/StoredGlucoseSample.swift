//
//  StoredGlucoseSample.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit

public struct StoredGlucoseSample: GlucoseSampleValue, Equatable {
    public let uuid: UUID?  // Note this is the UUID from HealthKit.  Nil if not (yet) stored in HealthKit.

    // MARK: - HealthKit Sync Support

    public let provenanceIdentifier: String
    public let syncIdentifier: String?
    public let syncVersion: Int?
    public let device: HKDevice?

    // MARK: - SampleValue

    public let startDate: Date
    public let quantity: HKQuantity

    // MARK: - GlucoseSampleValue

    public let isDisplayOnly: Bool
    public let wasUserEntered: Bool

    public init(sample: HKQuantitySample) {
        self.init(
            uuid: sample.uuid,
            provenanceIdentifier: sample.provenanceIdentifier,
            syncIdentifier: sample.syncIdentifier,
            syncVersion: sample.syncVersion,
            startDate: sample.startDate,
            quantity: sample.quantity,
            isDisplayOnly: sample.isDisplayOnly,
            wasUserEntered: sample.wasUserEntered,
            device: sample.device)
    }

    public init(
        uuid: UUID?,
        provenanceIdentifier: String,
        syncIdentifier: String?,
        syncVersion: Int?,
        startDate: Date,
        quantity: HKQuantity,
        isDisplayOnly: Bool,
        wasUserEntered: Bool,
        device: HKDevice?) {
        self.uuid = uuid
        self.provenanceIdentifier = provenanceIdentifier
        self.syncIdentifier = syncIdentifier
        self.syncVersion = syncVersion
        self.startDate = startDate
        self.quantity = quantity
        self.isDisplayOnly = isDisplayOnly
        self.wasUserEntered = wasUserEntered
        self.device = device
    }
}

extension StoredGlucoseSample {
    init(managedObject: CachedGlucoseObject) {
        self.init(
            uuid: managedObject.uuid,
            provenanceIdentifier: managedObject.provenanceIdentifier,
            syncIdentifier: managedObject.syncIdentifier,
            syncVersion: managedObject.syncVersion,
            startDate: managedObject.startDate,
            quantity: managedObject.quantity,
            isDisplayOnly: managedObject.isDisplayOnly,
            wasUserEntered: managedObject.wasUserEntered,
            device: managedObject.device)
    }
}
