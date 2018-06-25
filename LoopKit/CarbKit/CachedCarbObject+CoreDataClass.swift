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
}


extension CachedCarbObject {
    func update(from entry: StoredCarbEntry) {
        uuid = entry.sampleUUID
        syncIdentifier = entry.syncIdentifier
        syncVersion = Int32(clamping: entry.syncVersion)
        startDate = entry.startDate
        grams = entry.quantity.doubleValue(for: .gram())
        foodType = entry.foodType
        absorptionTime = entry.absorptionTime
        createdByCurrentApp = entry.createdByCurrentApp

        if let id = entry.externalID {
            externalID = id
        }
    }
}
