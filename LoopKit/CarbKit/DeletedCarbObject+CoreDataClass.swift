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
        uploadState = cachedCarbObject.uploadState
        startDate = cachedCarbObject.startDate
        uuid = cachedCarbObject.uuid
        syncIdentifier = cachedCarbObject.syncIdentifier
        syncVersion = cachedCarbObject.syncVersion
    }

}
