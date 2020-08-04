//
//  StoredGlucoseSample.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit


public struct StoredGlucoseSample: GlucoseSampleValue {
    public let sampleUUID: UUID

    // MARK: - HealthKit Sync Support

    public let syncIdentifier: String
    public let syncVersion: Int

    // MARK: - SampleValue

    public let startDate: Date
    public let quantity: HKQuantity

    // MARK: - GlucoseSampleValue

    public let isDisplayOnly: Bool
    public let wasUserEntered: Bool
    public let provenanceIdentifier: String

    public init(sample: HKQuantitySample) {
        self.init(
            sampleUUID: sample.uuid,
            syncIdentifier: sample.metadata?[HKMetadataKeySyncIdentifier] as? String,
            syncVersion: sample.metadata?[HKMetadataKeySyncVersion] as? Int ?? 1,
            startDate: sample.startDate,
            quantity: sample.quantity,
            isDisplayOnly: sample.isDisplayOnly,
            wasUserEntered: sample.wasUserEntered,
            provenanceIdentifier: sample.provenanceIdentifier
        )
    }

    public init(
        sampleUUID: UUID,
        syncIdentifier: String?,
        syncVersion: Int,
        startDate: Date,
        quantity: HKQuantity,
        isDisplayOnly: Bool,
        wasUserEntered: Bool,
        provenanceIdentifier: String
    ) {
        self.sampleUUID = sampleUUID
        self.syncIdentifier = syncIdentifier ?? sampleUUID.uuidString
        self.syncVersion = syncVersion
        self.startDate = startDate
        self.quantity = quantity
        self.isDisplayOnly = isDisplayOnly
        self.wasUserEntered = wasUserEntered
        self.provenanceIdentifier = provenanceIdentifier
    }
}


extension StoredGlucoseSample: Equatable, Hashable, Comparable {
    public static func <(lhs: StoredGlucoseSample, rhs: StoredGlucoseSample) -> Bool {
        return lhs.startDate < rhs.startDate
    }

    public static func ==(lhs: StoredGlucoseSample, rhs: StoredGlucoseSample) -> Bool {
        return lhs.sampleUUID == rhs.sampleUUID
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(sampleUUID)
    }
}


extension StoredGlucoseSample {
    init(managedObject: CachedGlucoseObject) {
        self.init(
            sampleUUID: managedObject.uuid!,
            syncIdentifier: managedObject.syncIdentifier,
            syncVersion: Int(managedObject.syncVersion),
            startDate: managedObject.startDate,
            quantity: HKQuantity(unit: HKUnit(from: managedObject.unitString!), doubleValue: managedObject.value),
            isDisplayOnly: managedObject.isDisplayOnly,
            wasUserEntered: managedObject.wasUserEntered,
            provenanceIdentifier: managedObject.provenanceIdentifier!
        )
    }
}
