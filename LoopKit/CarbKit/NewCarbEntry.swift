//
//  NewCarbEntry.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/15/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit


public struct NewCarbEntry: CarbEntry {
    public let quantity: HKQuantity
    public let startDate: Date
    public let foodType: String?
    public var absorptionTime: TimeInterval?
    public let createdByCurrentApp = true
    public let externalID: String?
    public let isUploaded: Bool

    public init(quantity: HKQuantity, startDate: Date, foodType: String?, absorptionTime: TimeInterval?, isUploaded: Bool = false, externalID: String? = nil) {
        self.quantity = quantity
        self.startDate = startDate
        self.foodType = foodType
        self.absorptionTime = absorptionTime
        self.isUploaded = isUploaded
        self.externalID = externalID
    }
}


extension NewCarbEntry: Equatable {
    public static func ==(lhs: NewCarbEntry, rhs: NewCarbEntry) -> Bool {
        return lhs.quantity.compare(rhs.quantity) == .orderedSame &&
        lhs.startDate == rhs.startDate &&
        lhs.foodType == rhs.foodType &&
        lhs.absorptionTime == rhs.absorptionTime &&
        lhs.createdByCurrentApp == rhs.createdByCurrentApp &&
        lhs.externalID == rhs.externalID &&
        lhs.isUploaded == rhs.isUploaded
    }
}


extension NewCarbEntry {
    func createSample(from oldEntry: StoredCarbEntry? = nil) -> HKQuantitySample {
        var metadata = [String: Any]()

        if let absorptionTime = absorptionTime {
            metadata[MetadataKeyAbsorptionTimeMinutes] = absorptionTime
        }

        if let foodType = foodType {
            metadata[HKMetadataKeyFoodType] = foodType
        }

        if let oldEntry = oldEntry, let syncIdentifier = oldEntry.syncIdentifier {
            metadata[HKMetadataKeySyncVersion] = oldEntry.syncVersion + 1
            metadata[HKMetadataKeySyncIdentifier] = syncIdentifier
        } else {
            // Add a sync identifier to allow for atomic modification if needed
            metadata[HKMetadataKeySyncVersion] = 1
            metadata[HKMetadataKeySyncIdentifier] = UUID().uuidString
        }

        metadata[HKMetadataKeyExternalUUID] = externalID

        return HKQuantitySample(
            type: HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
            quantity: quantity,
            start: startDate,
            end: endDate,
            metadata: metadata
        )
    }
}
