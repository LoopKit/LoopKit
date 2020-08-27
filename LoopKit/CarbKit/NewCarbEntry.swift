//
//  NewCarbEntry.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/15/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit


public struct NewCarbEntry: CarbEntry, Equatable, RawRepresentable {
    public typealias RawValue = [String: Any]

    public let quantity: HKQuantity
    public let startDate: Date
    public let foodType: String?
    public let absorptionTime: TimeInterval?

    public init(quantity: HKQuantity, startDate: Date, foodType: String?, absorptionTime: TimeInterval?) {
        self.quantity = quantity
        self.startDate = startDate
        self.foodType = foodType
        self.absorptionTime = absorptionTime
    }

    public init?(rawValue: RawValue) {
        guard
            let grams = rawValue["grams"] as? Double,
            let startDate = rawValue["startDate"] as? Date
        else {
            return nil
        }

        self.init(
            quantity: HKQuantity(unit: .gram(), doubleValue: grams),
            startDate: startDate,
            foodType: rawValue["foodType"] as? String,
            absorptionTime: rawValue["absorptionTime"] as? TimeInterval
        )
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [
            "grams": quantity.doubleValue(for: .gram()),
            "startDate": startDate
        ]

        rawValue["foodType"] = foodType
        rawValue["absorptionTime"] = absorptionTime

        return rawValue
    }
}


extension NewCarbEntry {
    func createSample(from oldEntry: StoredCarbEntry? = nil, syncVersion: Int = 1) -> HKQuantitySample {
        var metadata = [String: Any]()

        metadata[HKMetadataKeyFoodType] = foodType
        metadata[MetadataKeyAbsorptionTimeMinutes] = absorptionTime

        if let oldEntry = oldEntry, let syncIdentifier = oldEntry.syncIdentifier {
            metadata[HKMetadataKeySyncIdentifier] = syncIdentifier
            metadata[HKMetadataKeySyncVersion] = oldEntry.syncVersion + 1
        } else {
            // Add a sync identifier to allow for atomic modification if needed
            metadata[HKMetadataKeySyncIdentifier] = UUID().uuidString
            metadata[HKMetadataKeySyncVersion] = syncVersion
        }

        metadata[HKMetadataKeyExternalUUID] = oldEntry?.externalID

        return HKQuantitySample(
            type: HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
            quantity: quantity,
            start: startDate,
            end: endDate,
            metadata: metadata
        )
    }
}
