//
//  DeletedCarbObject+CoreDataClass.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//
//

import Foundation
import CoreData


class DeletedCarbObject: NSManagedObject {
    override func willSave() {
        if isInserted || isUpdated {
            setPrimitiveValue(managedObjectContext!.modificationCounter ?? 0, forKey: "modificationCounter")
        }
        super.willSave()
    }
}

extension DeletedCarbObject {

    func update(from cachedCarbObject: CachedCarbObject) {
        externalID = cachedCarbObject.externalID
        startDate = cachedCarbObject.startDate
        uuid = cachedCarbObject.uuid
        syncIdentifier = cachedCarbObject.syncIdentifier
        syncVersion = cachedCarbObject.syncVersion
    }

    func update(from entry: DeletedCarbEntry) {
        externalID = entry.externalID
        startDate = entry.startDate
        uuid = entry.uuid
        syncIdentifier = entry.syncIdentifier
        syncVersion = Int32(entry.syncVersion)
    }
}
