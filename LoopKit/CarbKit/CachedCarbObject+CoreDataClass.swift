//
//  CachedCarbObject+CoreDataClass.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//
//

import Foundation
import CoreData
import HealthKit

class CachedCarbObject: NSManagedObject {
    var absorptionTime: TimeInterval? {
        get {
            willAccessValue(forKey: "absorptionTime")
            defer { didAccessValue(forKey: "absorptionTime") }
            return primitiveAbsorptionTime?.doubleValue
        }
        set {
            willChangeValue(forKey: "absorptionTime")
            defer { didChangeValue(forKey: "absorptionTime") }
            primitiveAbsorptionTime = newValue != nil ? NSNumber(value: newValue!) : nil
        }
    }

    var syncVersion: Int? {
        get {
            willAccessValue(forKey: "syncVersion")
            defer { didAccessValue(forKey: "syncVersion") }
            return primitiveSyncVersion?.intValue
        }
        set {
            willChangeValue(forKey: "syncVersion")
            defer { didChangeValue(forKey: "syncVersion") }
            primitiveSyncVersion = newValue != nil ? NSNumber(value: newValue!) : nil
        }
    }

    var operation: Operation {
        get {
            willAccessValue(forKey: "operation")
            defer { didAccessValue(forKey: "operation") }
            return Operation(rawValue: primitiveOperation.intValue)!
        }
        set {
            willChangeValue(forKey: "operation")
            defer { didChangeValue(forKey: "operation") }
            primitiveOperation = NSNumber(value: newValue.rawValue)
        }
    }

    override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(managedObjectContext!.anchorKey!, forKey: "anchorKey")
    }
}

// MARK: - Helpers

extension CachedCarbObject {
    var quantity: HKQuantity { HKQuantity(unit: .gram(), doubleValue: grams) }
}

// MARK: - Operations

extension CachedCarbObject {

    // Loop
    func create(from entry: NewCarbEntry, provenanceIdentifier: String, syncIdentifier: String, syncVersion: Int = 1, on date: Date = Date()) {
        self.absorptionTime = entry.absorptionTime
        self.createdByCurrentApp = true
        self.foodType = entry.foodType
        self.grams = entry.quantity.doubleValue(for: .gram())
        self.startDate = entry.startDate
        self.uuid = nil

        self.provenanceIdentifier = provenanceIdentifier
        self.syncIdentifier = syncIdentifier
        self.syncVersion = syncVersion

        self.userCreatedDate = entry.date
        self.userUpdatedDate = nil
        self.userDeletedDate = nil

        self.operation = .create
        self.addedDate = date
        self.supercededDate = nil
    }

    // HealthKit
    func create(from sample: HKQuantitySample, on date: Date = Date()) {
        self.absorptionTime = sample.absorptionTime
        self.createdByCurrentApp = sample.createdByCurrentApp
        self.foodType = sample.foodType
        self.grams = sample.quantity.doubleValue(for: .gram())
        self.startDate = sample.startDate
        self.uuid = sample.uuid

        self.provenanceIdentifier = sample.provenanceIdentifier
        self.syncIdentifier = sample.syncIdentifier
        self.syncVersion = sample.syncVersion

        self.userCreatedDate = sample.userCreatedDate
        self.userUpdatedDate = nil
        self.userDeletedDate = nil

        self.operation = .create
        self.addedDate = date
        self.supercededDate = nil
    }

    // Loop
    func update(from entry: NewCarbEntry, replacing object: CachedCarbObject, on date: Date = Date()) {
        precondition(object.createdByCurrentApp)
        precondition(object.syncIdentifier != nil)
        precondition(object.syncVersion != nil)

        self.absorptionTime = entry.absorptionTime
        self.createdByCurrentApp = object.createdByCurrentApp
        self.foodType = entry.foodType
        self.grams = entry.quantity.doubleValue(for: .gram())
        self.startDate = entry.startDate
        self.uuid = nil

        self.provenanceIdentifier = object.provenanceIdentifier
        self.syncIdentifier = object.syncIdentifier
        self.syncVersion = object.syncVersion.map { $0 + 1 }

        self.userCreatedDate = object.userCreatedDate
        self.userUpdatedDate = entry.date
        self.userDeletedDate = nil

        self.operation = .update
        self.addedDate = date
        self.supercededDate = nil
    }

    // HealthKit
    func update(from sample: HKQuantitySample, replacing object: CachedCarbObject, on date: Date = Date()) {
//        precondition(!object.createdByCurrentApp)
//        precondition(sample.createdByCurrentApp == object.createdByCurrentApp)
//        precondition(sample.provenanceIdentifier == object.provenanceIdentifier)
//        precondition(object.syncIdentifier != nil)
//        precondition(sample.syncIdentifier == object.syncIdentifier)

        self.absorptionTime = sample.absorptionTime
        self.createdByCurrentApp = sample.createdByCurrentApp
        self.foodType = sample.foodType
        self.grams = sample.quantity.doubleValue(for: .gram())
        self.startDate = sample.startDate
        self.uuid = sample.uuid

        self.provenanceIdentifier = sample.provenanceIdentifier
        self.syncIdentifier = sample.syncIdentifier
        self.syncVersion = sample.syncVersion

        self.userCreatedDate = object.userCreatedDate
        self.userUpdatedDate = sample.userUpdatedDate
        self.userDeletedDate = nil

        self.operation = .update
        self.addedDate = date
        self.supercededDate = nil
    }

    // Either
    func delete(from object: CachedCarbObject, on date: Date = Date()) {
        self.absorptionTime = object.absorptionTime
        self.createdByCurrentApp = object.createdByCurrentApp
        self.foodType = object.foodType
        self.grams = object.grams
        self.startDate = object.startDate
        self.uuid = object.uuid

        self.provenanceIdentifier = object.provenanceIdentifier
        self.syncIdentifier = object.syncIdentifier
        self.syncVersion = object.syncVersion

        self.userCreatedDate = object.userCreatedDate
        self.userUpdatedDate = object.userUpdatedDate
        self.userDeletedDate = object.createdByCurrentApp ? date : nil  // Cannot know actual user deleted data from other app

        self.operation = .delete
        self.addedDate = date
        self.supercededDate = nil
    }
}

// MARK: - Watch Synchronization

extension CachedCarbObject {
    func update(from object: SyncCarbObject) {
        self.absorptionTime = object.absorptionTime
        self.createdByCurrentApp = object.createdByCurrentApp
        self.foodType = object.foodType
        self.grams = object.grams
        self.startDate = object.startDate
        self.uuid = object.uuid

        self.provenanceIdentifier = object.provenanceIdentifier
        self.syncIdentifier = object.syncIdentifier
        self.syncVersion = object.syncVersion

        self.userCreatedDate = object.userCreatedDate
        self.userUpdatedDate = object.userUpdatedDate
        self.userDeletedDate = object.userDeletedDate

        self.operation = object.operation
        self.addedDate = object.addedDate
        self.supercededDate = object.supercededDate
    }
}

// MARK: - HealthKit Synchronization

extension CachedCarbObject {
    var quantitySample: HKQuantitySample {
        var metadata = [String: Any]()

        metadata[HKMetadataKeyFoodType] = foodType
        metadata[MetadataKeyAbsorptionTime] = absorptionTime

        metadata[HKMetadataKeySyncIdentifier] = syncIdentifier
        metadata[HKMetadataKeySyncVersion] = syncVersion

        metadata[MetadataKeyUserCreatedDate] = userCreatedDate
        metadata[MetadataKeyUserUpdatedDate] = userUpdatedDate

        return HKQuantitySample(
            type: HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
            quantity: quantity,
            start: startDate,
            end: startDate,
            metadata: metadata
        )
    }
}

// MARK: - DEPRECATED - Used only for migration

extension CachedCarbObject {
    func create(from entry: StoredCarbEntry) {
        self.absorptionTime = entry.absorptionTime
        self.createdByCurrentApp = entry.createdByCurrentApp
        self.foodType = entry.foodType
        self.grams = entry.quantity.doubleValue(for: .gram())
        self.startDate = entry.startDate
        self.uuid = entry.uuid

        self.provenanceIdentifier = entry.provenanceIdentifier
        self.syncIdentifier = entry.syncIdentifier
        self.syncVersion = entry.syncVersion

        self.operation = .create
        self.addedDate = nil
        self.supercededDate = nil
    }
}
