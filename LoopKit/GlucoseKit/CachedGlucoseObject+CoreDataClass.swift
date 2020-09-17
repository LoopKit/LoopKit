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
    var startDate: Date! {
        get {
            willAccessValue(forKey: "startDate")
            defer { didAccessValue(forKey: "startDate") }
            return primitiveStartDate! as Date
        }
        set {
            willChangeValue(forKey: "startDate")
            defer { didChangeValue(forKey: "startDate") }
            primitiveStartDate = newValue as NSDate
        }
    }

    var uploadState: UploadState {
        get {
            willAccessValue(forKey: "uploadState")
            defer { didAccessValue(forKey: "uploadState") }
            return UploadState(rawValue: primitiveUploadState!.intValue)!
        }
        set {
            willChangeValue(forKey: "uploadState")
            defer { didChangeValue(forKey: "uploadState") }
            primitiveUploadState = NSNumber(value: newValue.rawValue)
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


extension CachedGlucoseObject {
    func update(from sample: StoredGlucoseSample) {
        uuid = sample.sampleUUID
        syncIdentifier = sample.syncIdentifier
        syncVersion = Int32(sample.syncVersion)
        value = sample.quantity.doubleValue(for: .milligramsPerDeciliter)
        unitString = HKUnit.milligramsPerDeciliter.unitString
        startDate = sample.startDate
        provenanceIdentifier = sample.provenanceIdentifier
        isDisplayOnly = sample.isDisplayOnly
        wasUserEntered = sample.wasUserEntered
    }
}
