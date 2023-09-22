//
//  CachedCgmEvent.swift
//  LoopKit
//
//  Created by Pete Schwamb on 9/9/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import CoreData

class CgmEvent: NSManagedObject {
    @NSManaged var date: Date!
    @NSManaged var storedAt: Date!
    @NSManaged var primitiveType: String!
    @NSManaged var deviceIdentifier: String!
    @NSManaged var primitiveExpectedLifetime: NSNumber?
    @NSManaged var primitiveWarmupPeriod: NSNumber?
    @NSManaged var failureMessage: String?
    @NSManaged var modificationCounter: Int64

    var type: CgmEventType? {
        get {
            willAccessValue(forKey: "type")
            defer { didAccessValue(forKey: "type") }
            return CgmEventType(rawValue: primitiveType)
        }
        set {
            willChangeValue(forKey: "type")
            defer { didChangeValue(forKey: "type") }
            primitiveType = newValue?.rawValue
        }
    }

    var expectedLifetime: TimeInterval? {
        get {
            willAccessValue(forKey: "expectedLifetime")
            defer { didAccessValue(forKey: "expectedLifetime") }
            return primitiveExpectedLifetime?.doubleValue
        }
        set {
            willChangeValue(forKey: "expectedLifetime")
            defer { didChangeValue(forKey: "expectedLifetime") }
            primitiveExpectedLifetime = newValue.flatMap { NSNumber(floatLiteral: $0) }
        }
    }

    var warmupPeriod: TimeInterval? {
        get {
            willAccessValue(forKey: "warmupPeriod")
            defer { didAccessValue(forKey: "warmupPeriod") }
            return primitiveWarmupPeriod?.doubleValue
        }
        set {
            willChangeValue(forKey: "warmupPeriod")
            defer { didChangeValue(forKey: "warmupPeriod") }
            primitiveWarmupPeriod = newValue.flatMap { NSNumber(floatLiteral: $0) }
        }
    }


    @nonobjc public class func fetchRequest() -> NSFetchRequest<CgmEvent> {
        return NSFetchRequest<CgmEvent>(entityName: "CgmEvent")
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


