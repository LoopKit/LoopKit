//
//  StoredCarbEntry.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/22/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import HealthKit
import CoreData

private let unit = HKUnit.gram()


public struct StoredCarbEntry: CarbEntry {

    public let sampleUUID: UUID

    // MARK: - HealthKit Sync Support

    public let syncIdentifier: String?
    public let syncVersion: Int

    // MARK: - SampleValue

    public let startDate: Date
    public let quantity: HKQuantity

    // MARK: - CarbEntry

    public let foodType: String?
    public let absorptionTime: TimeInterval?
    public let createdByCurrentApp: Bool

    // MARK: - Sync state

    public let externalID: String?

    init(sample: HKQuantitySample, createdByCurrentApp: Bool? = nil) {
        self.init(
            sampleUUID: sample.uuid,
            syncIdentifier: sample.metadata?[HKMetadataKeySyncIdentifier] as? String,
            syncVersion: sample.metadata?[HKMetadataKeySyncVersion] as? Int ?? 1,
            startDate: sample.startDate,
            unitString: unit.unitString,
            value: sample.quantity.doubleValue(for: unit),
            foodType: sample.foodType,
            absorptionTime: sample.absorptionTime,
            createdByCurrentApp: createdByCurrentApp ?? sample.createdByCurrentApp,
            externalID: sample.externalID
        )
    }

    public init(
        sampleUUID: UUID,
        syncIdentifier: String?,
        syncVersion: Int,
        startDate: Date,
        unitString: String,
        value: Double,
        foodType: String?,
        absorptionTime: TimeInterval?,
        createdByCurrentApp: Bool,
        externalID: String?
    ) {
        self.sampleUUID = sampleUUID
        self.syncIdentifier = syncIdentifier
        self.syncVersion = syncVersion
        self.startDate = startDate
        self.quantity = HKQuantity(unit: HKUnit(from: unitString), doubleValue: value)
        self.foodType = foodType
        self.absorptionTime = absorptionTime
        self.createdByCurrentApp = createdByCurrentApp
        self.externalID = externalID
    }
}


extension StoredCarbEntry: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(sampleUUID)
    }
}

extension StoredCarbEntry: Equatable {
    public static func ==(lhs: StoredCarbEntry, rhs: StoredCarbEntry) -> Bool {
        return lhs.sampleUUID == rhs.sampleUUID
    }
}

extension StoredCarbEntry: Comparable {
    public static func <(lhs: StoredCarbEntry, rhs: StoredCarbEntry) -> Bool {
        return lhs.startDate < rhs.startDate
    }
}

// Deprecated, used for migration only
extension StoredCarbEntry {
    typealias RawValue = [String: Any]

    init?(rawValue: RawValue) {
        guard let
            sampleUUIDString = rawValue["sampleUUID"] as? String,
            let sampleUUID = UUID(uuidString: sampleUUIDString),
            let startDate = rawValue["startDate"] as? Date,
            let unitString = rawValue["unitString"] as? String,
            let value = rawValue["value"] as? Double,
            let createdByCurrentApp = rawValue["createdByCurrentApp"] as? Bool else
        {
            return nil
        }

        let externalID = rawValue["externalId"] as? String

        self.init(
            sampleUUID: sampleUUID,
            syncIdentifier: nil,
            syncVersion: 1,
            startDate: startDate,
            unitString: unitString,
            value: value,
            foodType: rawValue["foodType"] as? String,
            absorptionTime: rawValue["absorptionTime"] as? TimeInterval,
            createdByCurrentApp: createdByCurrentApp,
            externalID: externalID
        )
    }
}


extension StoredCarbEntry {
    init(managedObject: CachedCarbObject) {
        self.init(
            sampleUUID: managedObject.uuid!,
            syncIdentifier: managedObject.syncIdentifier,
            syncVersion: Int(managedObject.syncVersion),
            startDate: managedObject.startDate,
            unitString: unit.unitString,
            value: managedObject.grams,
            foodType: managedObject.foodType,
            absorptionTime: managedObject.absorptionTime,
            createdByCurrentApp: managedObject.createdByCurrentApp,
            externalID: managedObject.externalID
        )
    }
}
