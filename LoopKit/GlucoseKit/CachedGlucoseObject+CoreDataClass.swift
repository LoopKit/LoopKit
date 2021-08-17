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
            primitiveSyncVersion = newValue.map { NSNumber(value: $0) }
        }
    }
    
    var device: HKDevice? {
        get {
            willAccessValue(forKey: "device")
            defer { didAccessValue(forKey: "device") }
            return primitiveDevice.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKDevice.self, from: $0) }
        }
        set {
            willChangeValue(forKey: "device")
            defer { didChangeValue(forKey: "device") }
            primitiveDevice = newValue.flatMap { try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: false) }
        }
    }
    
    var trend: GlucoseTrend? {
        get {
            willAccessValue(forKey: "trend")
            defer { didAccessValue(forKey: "trend") }
            return primitiveTrend.flatMap { GlucoseTrend(rawValue: $0.intValue) }
        }
        set {
            willChangeValue(forKey: "trend")
            defer { didChangeValue(forKey: "trend") }
            primitiveTrend = newValue.map { NSNumber(value: $0.rawValue) }
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

    var quantitySample: HKQuantitySample {
        var metadata: [String: Any] = [
            HKMetadataKeySyncIdentifier: syncIdentifier as Any,
            HKMetadataKeySyncVersion: syncVersion as Any,
        ]
        
        if isDisplayOnly {
            metadata[MetadataKeyGlucoseIsDisplayOnly] = true
        }
        if wasUserEntered {
            metadata[HKMetadataKeyWasUserEntered] = true
        }
        if let trend = trend {
            metadata[MetadataKeyGlucoseTrend] = trend.rawValue
        }
        
        return HKQuantitySample(
            type: HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!,
            quantity: quantity,
            start: startDate,
            end: startDate,
            device: device,
            metadata: metadata
        )
    }
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
        self.device = sample.device
        self.trend = sample.trend
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
        self.device = sample.device
        self.trend = sample.trend
    }
}

// MARK: - Watch Synchronization

extension CachedGlucoseObject {
    func update(from sample: StoredGlucoseSample) {
        self.provenanceIdentifier = sample.provenanceIdentifier
        self.syncIdentifier = sample.syncIdentifier
        self.syncVersion = sample.syncVersion
        self.value = sample.quantity.doubleValue(for: .milligramsPerDeciliter)
        self.unitString = HKUnit.milligramsPerDeciliter.unitString
        self.startDate = sample.startDate
        self.isDisplayOnly = sample.isDisplayOnly
        self.wasUserEntered = sample.wasUserEntered
        self.device = sample.device
        self.trend = sample.trend
    }
}
