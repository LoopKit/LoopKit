//
//  CachedGlucoseObject+CoreDataClass.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//
//

import Foundation
import CoreData
import HealthKit


class CachedGlucoseObject: NSManagedObject {
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

    var hasUpdatedModificationCounter: Bool { changedValues().keys.contains("modificationCounter") }

    func updateModificationCounter() { setPrimitiveValue(managedObjectContext!.modificationCounter!, forKey: "modificationCounter") }

    override func awakeFromInsert() {
        super.awakeFromInsert()
        updateModificationCounter()
    }

    override func willSave() {
        if isUpdated && !hasUpdatedModificationCounter {
            updateModificationCounter()
        }
        super.willSave()
    }
}

// MARK: - Helpers

extension CachedGlucoseObject {
    var quantity: HKQuantity { HKQuantity(unit: HKUnit(from: unitString), doubleValue: value) }
}

// MARK: - Operations

extension CachedGlucoseObject {

    // Loop
    func create(from sample: NewGlucoseSample, provenanceIdentifier: String) {
        self.uuid = nil
        self.provenanceIdentifier = provenanceIdentifier
        self.syncIdentifier = sample.syncIdentifier
        self.syncVersion = sample.syncVersion
        self.value = sample.quantity.doubleValue(for: .milligramsPerDeciliter)
        self.unitString = HKUnit.milligramsPerDeciliter.unitString
        self.startDate = sample.date
        self.isDisplayOnly = sample.isDisplayOnly
        self.wasUserEntered = sample.wasUserEntered
    }

    // HealthKit
    func create(from sample: HKQuantitySample) {
        precondition(!sample.createdByCurrentApp)

        self.uuid = sample.uuid
        self.provenanceIdentifier = sample.provenanceIdentifier
        self.syncIdentifier = sample.syncIdentifier
        self.syncVersion = sample.syncVersion
        self.value = sample.quantity.doubleValue(for: .milligramsPerDeciliter)
        self.unitString = HKUnit.milligramsPerDeciliter.unitString
        self.startDate = sample.startDate
        self.isDisplayOnly = sample.isDisplayOnly
        self.wasUserEntered = sample.wasUserEntered
    }
}

// MARK: - Watch Synchronization

extension CachedGlucoseObject {
    func update(from sample: StoredGlucoseSample) {
        self.uuid = sample.uuid
        self.provenanceIdentifier = sample.provenanceIdentifier
        self.syncIdentifier = sample.syncIdentifier
        self.syncVersion = sample.syncVersion
        self.value = sample.quantity.doubleValue(for: .milligramsPerDeciliter)
        self.unitString = HKUnit.milligramsPerDeciliter.unitString
        self.startDate = sample.startDate
        self.isDisplayOnly = sample.isDisplayOnly
        self.wasUserEntered = sample.wasUserEntered
    }
}
